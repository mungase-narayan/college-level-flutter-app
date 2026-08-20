import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/usecases/announcement_usecases.dart';

/// The announcement feed, narrowed by a title search and a type.
class AnnouncementsCubit extends Cubit<RemoteState<Paginated<Announcement>>> {
  AnnouncementsCubit({required ListAnnouncementsUseCase listAnnouncements})
      : _listAnnouncements = listAnnouncements,
        super(const RemoteState());

  final ListAnnouncementsUseCase _listAnnouncements;

  AnnouncementQueryParams _query = const AnnouncementQueryParams();
  bool _isLoadingMore = false;

  /// Not part of the emitted state: the query is what the *next* request will
  /// ask for, and the state is what the last one returned.
  AnnouncementQueryParams get query => _query;

  bool get hasMore => state.data?.pagination.hasNextPage ?? false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Always page 1, so any filter change restarts the feed.
    final result = await _listAnnouncements(_query.copyWith(page: 1));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) => emit(RemoteState(status: RemoteStatus.success, data: page)),
    );
  }

  Future<void> loadMore() async {
    if (isClosed || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;

    final current = state.data!;
    final result = await _listAnnouncements(
      _query.copyWith(page: current.pagination.page + 1),
    );

    _isLoadingMore = false;
    if (isClosed) return;

    result.fold(
      // Keep what's already on screen; the footer just stops advancing.
      (failure) => emit(state.copyWith(failure: failure)),
      (next) => emit(state.copyWith(data: current.copyWithAppended(next))),
    );
  }

  /// The search box. Separate from [setType] rather than batched the way
  /// attendance batches its two, because these two controls live in different
  /// places — the toolbar and the sheet — and cannot change together.
  Future<void> setSearch(String value) {
    final trimmed = value.trim();
    final next = trimmed.isEmpty ? null : trimmed;
    // The field fires on every debounced keystroke, including ones that leave
    // the term unchanged after trimming.
    if (next == _query.query) return Future.value();

    _query = _query.copyWith(query: next, clearQuery: next == null);
    return load();
  }

  Future<void> setType(String? type) {
    if (type == _query.type) return Future.value();
    _query = _query.copyWith(type: type, clearType: type == null);
    return load();
  }

  /// The web's "Clear filters" — both filters dropped in one reload.
  Future<void> clearFilters() {
    if (!_query.hasFilters) return Future.value();
    _query = _query.copyWith(clearQuery: true, clearType: true);
    return load();
  }
}
