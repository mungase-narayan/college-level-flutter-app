import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/attendance_session.dart';
import '../../domain/repositories/teacher_attendance_repository.dart';
import '../datasources/teacher_attendance_service.dart';

class TeacherAttendanceRepositoryImpl
    with RepositoryGuard
    implements TeacherAttendanceRepository {
  const TeacherAttendanceRepositoryImpl(this._service);

  final TeacherAttendanceService _service;

  @override
  Future<Either<Failure, AttendanceSessionPage>> listSessions({
    String? courseId,
    String? divisionId,
    String? status,
    String? type,
    int page = 1,
    int limit = 10,
  }) =>
      guard(
        () => _service.listSessions(
          courseId: courseId,
          divisionId: divisionId,
          status: status,
          type: type,
          page: page,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, AttendanceSessionDetail>> getSession(String id) =>
      guard(() => _service.getSession(id));

  @override
  Future<Either<Failure, List<TodaySlot>>> todaySlots({
    String? courseId,
    String? divisionId,
  }) =>
      guard(
        () => _service.todaySlots(courseId: courseId, divisionId: divisionId),
      );

  @override
  Future<Either<Failure, AttendanceAnalytics>> analytics({
    required String courseId,
    required String divisionId,
  }) =>
      guard(
        () => _service.analytics(courseId: courseId, divisionId: divisionId),
      );

  @override
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
      guard(
        () => _service.createSession(
          courseId: courseId,
          divisionId: divisionId,
          type: type,
          sessionDate: sessionDate,
          startTime: startTime,
          endTime: endTime,
          topic: topic,
          timetableSlotId: timetableSlotId,
        ),
      );

  @override
  Future<Either<Failure, void>> deleteSession(String id) =>
      guard(() => _service.deleteSession(id));

  @override
  Future<Either<Failure, void>> mark({
    required String sessionId,
    required List<({String studentId, String status})> records,
  }) =>
      guard(() => _service.mark(sessionId: sessionId, records: records));

  @override
  Future<Either<Failure, void>> finalize(String sessionId) =>
      guard(() => _service.finalize(sessionId));
}
