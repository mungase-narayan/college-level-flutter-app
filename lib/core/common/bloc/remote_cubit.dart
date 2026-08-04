import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../error/failures.dart';
import '../../network/api_response.dart';

enum RemoteStatus { initial, loading, success, failure }

/// The state every "fetch and display" screen needs: the data, whether a load
/// is in flight, and the last failure.
///
/// This is the Flutter stand-in for what `@tanstack/react-query` gave the web
/// app for free (`{ data, isLoading, error }`), so individual features don't
/// each re-implement it.
class RemoteState<T> extends Equatable {
  const RemoteState({
    this.status = RemoteStatus.initial,
    this.data,
    this.failure,
    this.isRefreshing = false,
  });

  final RemoteStatus status;
  final T? data;
  final Failure? failure;

  /// A background refresh (pull-to-refresh, or a reload after a mutation) —
  /// the existing [data] stays on screen while it runs.
  final bool isRefreshing;

  bool get isLoading => status == RemoteStatus.loading;
  bool get isSuccess => status == RemoteStatus.success;
  bool get hasData => data != null;

  /// True only for the very first load, when there's nothing to show yet.
  bool get isInitialLoading => isLoading && !hasData;

  RemoteState<T> copyWith({
    RemoteStatus? status,
    T? data,
    Failure? failure,
    bool? isRefreshing,
    bool clearFailure = false,
  }) =>
      RemoteState<T>(
        status: status ?? this.status,
        data: data ?? this.data,
        failure: clearFailure ? null : (failure ?? this.failure),
        isRefreshing: isRefreshing ?? this.isRefreshing,
      );

  @override
  List<Object?> get props => [status, data, failure, isRefreshing];
}

/// Runs a single loader and publishes it as a [RemoteState].
///
/// Features subclass this (or use it directly) and pass a closure that calls
/// their use case, so the domain boundary is preserved — the cubit still never
/// touches a repository or Dio.
class RemoteCubit<T> extends Cubit<RemoteState<T>> {
  RemoteCubit(this._loader) : super(RemoteState<T>());

  final Future<Either<Failure, T>> Function() _loader;

  /// Loads for the first time, or reloads from scratch.
  ///
  /// Pass `refresh: true` for pull-to-refresh so the current data stays visible
  /// instead of flashing a spinner.
  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: RemoteStatus.loading,
        isRefreshing: refresh,
        clearFailure: true,
      ),
    );

    final result = await _loader();
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: RemoteStatus.failure,
          failure: failure,
          isRefreshing: false,
        ),
      ),
      (data) => emit(
        RemoteState<T>(status: RemoteStatus.success, data: data),
      ),
    );
  }

  /// Replaces the held data without a round trip — for optimistic updates such
  /// as toggling a bookmark or a like.
  void setData(T data) {
    if (isClosed) return;
    emit(state.copyWith(status: RemoteStatus.success, data: data));
  }
}

/// A paged list that accumulates pages as the user scrolls.
///
/// The loader takes a 1-based page number and returns that page.
class PaginatedCubit<T> extends Cubit<RemoteState<Paginated<T>>> {
  PaginatedCubit(this._loader) : super(RemoteState<Paginated<T>>());

  final Future<Either<Failure, Paginated<T>>> Function(int page) _loader;

  bool _isLoadingMore = false;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => state.data?.pagination.hasNextPage ?? false;

  /// Loads (or reloads) page 1, discarding anything already accumulated.
  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: RemoteStatus.loading,
        isRefreshing: refresh,
        clearFailure: true,
      ),
    );

    final result = await _loader(1);
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: RemoteStatus.failure,
          failure: failure,
          isRefreshing: false,
        ),
      ),
      (page) => emit(
        RemoteState<Paginated<T>>(status: RemoteStatus.success, data: page),
      ),
    );
  }

  /// Appends the next page. A no-op when a load is already running or the last
  /// page has been reached, so it's safe to call from a scroll listener.
  Future<void> loadMore() async {
    if (isClosed || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;

    final current = state.data!;
    final result = await _loader(current.pagination.page + 1);

    _isLoadingMore = false;
    if (isClosed) return;

    result.fold(
      // A failed "load more" keeps the pages already on screen; the footer
      // simply stops advancing rather than blowing the list away.
      (failure) => emit(state.copyWith(failure: failure)),
      (next) => emit(
        state.copyWith(
          status: RemoteStatus.success,
          data: current.copyWithAppended(next),
        ),
      ),
    );
  }

  /// Swaps one item in place — used after a mutation on a row.
  void replaceItem(bool Function(T item) test, T replacement) {
    final current = state.data;
    if (current == null || isClosed) return;
    emit(
      state.copyWith(
        data: Paginated<T>(
          items: [
            for (final item in current.items) test(item) ? replacement : item,
          ],
          pagination: current.pagination,
        ),
      ),
    );
  }
}
