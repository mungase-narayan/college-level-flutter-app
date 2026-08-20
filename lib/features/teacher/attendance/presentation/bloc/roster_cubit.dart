import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/attendance_session.dart';
import '../../domain/usecases/attendance_usecases.dart';

/// The session, and the marks the teacher has made but not yet saved.
///
/// The marks live **in the state**, not beside it: `RemoteState` is `Equatable`,
/// so re-emitting with an unchanged payload is dropped by bloc and the toggles
/// would never repaint. Each change therefore produces a new map.
class RosterData extends Equatable {
  const RosterData({
    required this.detail,
    required this.marks,
    this.isBusy = false,
  });

  final AttendanceSessionDetail detail;

  /// studentId → mark, covering every student on the roster.
  final Map<String, String> marks;

  /// A save or finalize is in flight.
  final bool isBusy;

  AttendanceSession get session => detail.session;
  List<AttendanceRecord> get records => detail.records;

  /// Once finalized the API refuses further marks, so the screen drops every
  /// control rather than offering ones that would 409.
  bool get isReadOnly => session.status == AttendanceStatus.finalized;

  int countOf(String status) =>
      marks.values.where((value) => value == status).length;

  RosterData copyWith({
    AttendanceSessionDetail? detail,
    Map<String, String>? marks,
    bool? isBusy,
  }) =>
      RosterData(
        detail: detail ?? this.detail,
        marks: marks ?? this.marks,
        isBusy: isBusy ?? this.isBusy,
      );

  @override
  List<Object?> get props => [detail, marks, isBusy];
}

/// The roster marking screen.
///
/// Marks are held locally until saved, so the counts update as the teacher
/// toggles rather than after a round trip.
class RosterCubit extends Cubit<RemoteState<RosterData>> {
  RosterCubit({
    required AttendanceUseCases attendance,
    required this.sessionId,
  })  : _attendance = attendance,
        super(const RemoteState());

  final AttendanceUseCases _attendance;
  final String sessionId;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _attendance.getSession(sessionId);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (detail) => emit(
        RemoteState(
          status: RemoteStatus.success,
          data: RosterData(detail: detail, marks: _seed(detail)),
        ),
      ),
    );
  }

  /// Seeds every student's mark, **defaulting an unmarked student to present**.
  ///
  /// This is the web's behaviour and it is load-bearing: a teacher opens the
  /// screen, flips the few who are absent, and saves. Defaulting to unmarked
  /// would instead make them tap every present student individually.
  Map<String, String> _seed(AttendanceSessionDetail detail) => {
        for (final record in detail.records)
          record.studentId: record.status ?? MarkStatus.present,
      };

  void setMark(String studentId, String status) {
    final data = state.data;
    if (data == null || data.isReadOnly) return;
    emit(
      state.copyWith(
        data: data.copyWith(marks: {...data.marks, studentId: status}),
      ),
    );
  }

  /// Applies to the **whole** roster, not just the visible page — the web's
  /// button does the same, and a per-page version would quietly miss students.
  void markAllPresent() {
    final data = state.data;
    if (data == null || data.isReadOnly) return;
    emit(
      state.copyWith(
        data: data.copyWith(
          marks: {
            for (final record in data.records)
              record.studentId: MarkStatus.present,
          },
        ),
      ),
    );
  }

  /// Posts the entire roster, never a delta.
  Future<Failure?> save() async {
    final data = state.data;
    if (data == null || data.records.isEmpty) return null;

    _setBusy(true);
    final result = await _attendance.mark(
      sessionId: sessionId,
      records: [
        for (final record in data.records)
          (
            studentId: record.studentId,
            status: data.marks[record.studentId] ?? MarkStatus.present,
          ),
      ],
    );
    if (isClosed) return null;
    _setBusy(false);
    return result.fold((failure) => failure, (_) => null);
  }

  /// Saves, then finalizes — in that order, always.
  ///
  /// The backend rejects `mark` once the status is `finalized`, so finalizing
  /// first would silently discard whatever the teacher had just toggled.
  Future<Failure?> saveAndFinalize() async {
    final saveFailure = await save();
    if (saveFailure != null || isClosed) return saveFailure;

    _setBusy(true);
    final result = await _attendance.finalize(sessionId);
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure == null) {
      // Reload so the screen picks up `finalized` and locks itself.
      await load(refresh: true);
    } else {
      _setBusy(false);
    }
    return failure;
  }

  void _setBusy(bool value) {
    final data = state.data;
    if (isClosed || data == null) return;
    emit(state.copyWith(data: data.copyWith(isBusy: value)));
  }
}
