import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_service.dart';

class AttendanceRepositoryImpl
    with RepositoryGuard
    implements AttendanceRepository {
  const AttendanceRepositoryImpl(this._service);

  final AttendanceService _service;

  @override
  Future<Either<Failure, CourseAttendance>> getCourseAnalytics(String courseId) =>
      guard(() => _service.getCourseAnalytics(courseId));

  @override
  Future<Either<Failure, AttendanceOverview>> getOverallAnalytics() =>
      guard(_service.getOverallAnalytics);

  @override
  Future<Either<Failure, Paginated<AttendanceSession>>> listSessions({
    String? courseId,
    String? status,
    int page = 1,
    int limit = AttendanceMeta.pageSize,
  }) =>
      guard(() async {
        final result = await _service.listSessions(
          courseId: courseId,
          status: status,
          page: page,
          limit: limit,
        );
        return Paginated<AttendanceSession>(
          items: result.items,
          pagination: result.pagination,
        );
      });
}
