import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/usecases/attendance_usecases.dart';

/// The marked-sessions list, newest first, narrowed by course and status.
class AttendanceSessionsCubit
    extends Cubit<RemoteState<Paginated<AttendanceSession>>> {
  AttendanceSessionsCubit({required ListAttendanceSessionsUseCase listSessions})
      : _listSessions = listSessions,
        super(const RemoteState());

  final ListAttendanceSessionsUseCase _listSessions;

  AttendanceSessionParams _query = const AttendanceSessionParams();
  bool _isLoadingMore = false;

  /// Not part of the emitted state: the query is what the *next* request will
  /// ask for, and the state is what the last one returned.
  AttendanceSessionParams get query => _query;

  bool get hasMore => state.data?.pagination.hasNextPage ?? false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Always page 1 — this is what implements the web's "changing either filter
    // resets the page".
    final result = await _listSessions(_query.copyWith(page: 1));
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
    final result = await _listSessions(
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

  /// Applies course and status together in one reload.
  ///
  /// The sheet stages both and commits on Apply; calling two setters in
  /// sequence would fire two requests and paint a throwaway result set on the
  /// way. Nulls mean "no filter" — the sheet always submits the complete set,
  /// so this cannot be mistaken for "leave unchanged".
  Future<void> setFilters({String? courseId, String? status}) {
    _query = _query.copyWith(
      courseId: courseId,
      status: status,
      clearCourseId: courseId == null,
      clearStatus: status == null,
    );
    return load();
  }
}
