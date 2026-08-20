import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/attendance_session.dart';
import '../repositories/teacher_attendance_repository.dart';

/// The attendance surface, grouped rather than one class per verb: the tab
/// needs three reads together and the marking screen needs three writes
/// together, so splitting them into eight singletons would only add wiring.
class AttendanceUseCases {
  const AttendanceUseCases(this._repository);

  final TeacherAttendanceRepository _repository;

  Future<Either<Failure, AttendanceSessionPage>> listSessions({
    String? courseId,
    String? divisionId,
    String? status,
    int page = 1,
    int limit = 10,
  }) =>
      _repository.listSessions(
        courseId: courseId,
        divisionId: divisionId,
        status: status,
        page: page,
        limit: limit,
      );

  Future<Either<Failure, AttendanceSessionDetail>> getSession(String id) =>
      _repository.getSession(id);

  Future<Either<Failure, List<TodaySlot>>> todaySlots({
    String? courseId,
    String? divisionId,
  }) =>
      _repository.todaySlots(courseId: courseId, divisionId: divisionId);

  Future<Either<Failure, AttendanceAnalytics>> analytics({
    required String courseId,
    required String divisionId,
  }) =>
      _repository.analytics(courseId: courseId, divisionId: divisionId);

  Future<Either<Failure, AttendanceSession>> createSession({
    required String courseId,
    required String divisionId,
    required String type,
    required String sessionDate,
    required String startTime,
    String? endTime,
    String? topic,
    String? timetableSlotId,
  }) =>
      _repository.createSession(
        courseId: courseId,
        divisionId: divisionId,
        type: type,
        sessionDate: sessionDate,
        startTime: startTime,
        endTime: endTime,
        topic: topic,
        timetableSlotId: timetableSlotId,
      );

  Future<Either<Failure, void>> deleteSession(String id) =>
      _repository.deleteSession(id);

  Future<Either<Failure, void>> mark({
    required String sessionId,
    required List<({String studentId, String status})> records,
  }) =>
      _repository.mark(sessionId: sessionId, records: records);

  Future<Either<Failure, void>> finalize(String sessionId) =>
      _repository.finalize(sessionId);
}
