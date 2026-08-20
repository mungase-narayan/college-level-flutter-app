import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/attendance_session.dart';
import '../../domain/usecases/attendance_usecases.dart';

/// Everything the attendance tab shows at once.
class AttendanceTabData extends Equatable {
  const AttendanceTabData({
    required this.page,
    required this.pendingSlots,
    this.analytics,
  });

  final AttendanceSessionPage page;

  /// Today's timetable slots with no session yet, offered as one-tap creates.
  final List<TodaySlot> pendingSlots;

  /// Null when the rollup failed — the sessions list is still worth showing.
  final AttendanceAnalytics? analytics;

  bool get isEmpty => page.items.isEmpty && pendingSlots.isEmpty;

  @override
  List<Object?> get props => [page, pendingSlots, analytics];
}

/// The attendance tab: sessions, the rollup, and today's pending slots.
class AttendanceTabCubit extends Cubit<RemoteState<AttendanceTabData>> {
  AttendanceTabCubit({
    required AttendanceUseCases attendance,
    required this.courseId,
    required this.divisionId,
  })  : _attendance = attendance,
        super(const RemoteState());

  final AttendanceUseCases _attendance;
  final String courseId;
  final String divisionId;

  static const pageSize = 10;

  String? _status;
  int _page = 1;

  String? get status => _status;
  int get page => _page;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Three independent reads, started together.
    final sessionsFuture = _attendance.listSessions(
      courseId: courseId,
      divisionId: divisionId,
      status: _status,
      page: _page,
      limit: pageSize,
    );
    final analyticsFuture = _attendance.analytics(
      courseId: courseId,
      divisionId: divisionId,
    );
    // Pending slots only make sense on an unfiltered first page — a slot is
    // not a session, so it has no place in a filtered or paged view.
    final slotsFuture = _page == 1 && _status == null
        ? _attendance.todaySlots(courseId: courseId, divisionId: divisionId)
        : null;

    final sessions = await sessionsFuture;
    final analytics = await analyticsFuture;
    final slots = await slotsFuture;
    if (isClosed) return;

    // The sessions list is the screen; the other two degrade to null/empty
    // rather than taking it down.
    sessions.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) => emit(
        RemoteState(
          status: RemoteStatus.success,
          data: AttendanceTabData(
            page: page,
            analytics: analytics.fold((_) => null, (value) => value),
            pendingSlots: slots?.fold(
                  (_) => const <TodaySlot>[],
                  (value) => [for (final s in value) if (s.isPending) s],
                ) ??
                const [],
          ),
        ),
      ),
    );
  }

  Future<void> setStatus(String? value) {
    _status = value;
    // A filter change always restarts at page 1.
    _page = 1;
    return load();
  }

  Future<void> setPage(int value) {
    _page = value;
    return load();
  }

  /// Creates a session. Returns the created row so the caller can navigate
  /// straight into marking it.
  Future<Either<Failure, AttendanceSession>> createSession({
    required String courseId,
    required String divisionId,
    required String type,
    required String sessionDate,
    required String startTime,
    String? endTime,
    String? topic,
    String? timetableSlotId,
  }) async {
    final result = await _attendance.createSession(
      courseId: courseId,
      divisionId: divisionId,
      type: type,
      sessionDate: sessionDate,
      startTime: startTime,
      endTime: endTime,
      topic: topic,
      timetableSlotId: timetableSlotId,
    );
    if (!isClosed && result.isRight()) await load(refresh: true);
    return result;
  }

  /// Deletes a draft session and reloads. Returns the failure, or null on
  /// success, so the caller can toast without subscribing to state.
  Future<Failure?> deleteSession(String id) async {
    final result = await _attendance.deleteSession(id);
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
