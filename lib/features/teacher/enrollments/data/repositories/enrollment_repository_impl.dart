import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';
import '../datasources/enrollment_service.dart';

class EnrollmentRepositoryImpl
    with RepositoryGuard
    implements EnrollmentRepository {
  const EnrollmentRepositoryImpl(this._service);

  final EnrollmentService _service;

  @override
  Future<Either<Failure, List<CourseEnrollmentRow>>> list({
    required String courseId,
    int limit = 100,
  }) =>
      guard(() => _service.list(courseId: courseId, limit: limit));

  @override
  Future<Either<Failure, Paginated<UnenrolledStudent>>> unenrolled({
    required String courseId,
    String? search,
    int page = 1,
    int limit = 8,
  }) =>
      guard(
        () => _service.unenrolled(
          courseId: courseId,
          search: search,
          page: page,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, void>> enroll({
    required String courseId,
    required String studentId,
    required String userId,
  }) =>
      guard(
        () => _service.enroll(
          courseId: courseId,
          studentId: studentId,
          userId: userId,
        ),
      );

  @override
  Future<Either<Failure, void>> setStatus({
    required String id,
    required String status,
  }) =>
      guard(() => _service.setStatus(id: id, status: status));

  @override
  Future<Either<Failure, void>> remove(String id) =>
      guard(() => _service.remove(id));
}
