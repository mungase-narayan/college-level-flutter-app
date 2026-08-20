import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/attendance_session.dart';

abstract class TeacherAttendanceRepository {
  Future<Either<Failure, AttendanceSessionPage>> listSessions({
    String? courseId,
    String? divisionId,
    String? status,
    String? type,
    int page,
    int limit,
  });

  Future<Either<Failure, AttendanceSessionDetail>> getSession(String id);

  Future<Either<Failure, List<TodaySlot>>> todaySlots({
    String? courseId,
    String? divisionId,
  });

  Future<Either<Failure, AttendanceAnalytics>> analytics({
    required String courseId,
    required String divisionId,
  });

  Future<Either<Failure, AttendanceSession>> createSession({
    required String courseId,
    required String divisionId,
    required String type,
    required String sessionDate,
    required String startTime,
    String? endTime,
    String? topic,
    String? timetableSlotId,
  });

  Future<Either<Failure, void>> deleteSession(String id);

  Future<Either<Failure, void>> mark({
    required String sessionId,
    required List<({String studentId, String status})> records,
  });

  Future<Either<Failure, void>> finalize(String sessionId);
}
