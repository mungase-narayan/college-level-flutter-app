import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/attendance.dart';

abstract class AttendanceRepository {
  Future<Either<Failure, CourseAttendance>> getCourseAnalytics(String courseId);

  Future<Either<Failure, AttendanceOverview>> getOverallAnalytics();

  Future<Either<Failure, Paginated<AttendanceSession>>> listSessions({
    String? courseId,
    String? status,
    int page,
    int limit,
  });
}
