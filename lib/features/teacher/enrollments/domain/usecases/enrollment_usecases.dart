import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/course_enrollment.dart';
import '../repositories/enrollment_repository.dart';

/// The enrolment surface, grouped: the tab needs the list plus three mutations
/// that all reload it, so one object keeps the wiring honest.
class EnrollmentUseCases {
  const EnrollmentUseCases(this._repository);

  final EnrollmentRepository _repository;

  Future<Either<Failure, List<CourseEnrollmentRow>>> list(String courseId) =>
      _repository.list(courseId: courseId);

  Future<Either<Failure, Paginated<UnenrolledStudent>>> unenrolled({
    required String courseId,
    String? search,
    int page = 1,
  }) =>
      _repository.unenrolled(courseId: courseId, search: search, page: page);

  Future<Either<Failure, void>> enroll({
    required String courseId,
    required String studentId,
    required String userId,
  }) =>
      _repository.enroll(
        courseId: courseId,
        studentId: studentId,
        userId: userId,
      );

  Future<Either<Failure, void>> setStatus({
    required String id,
    required String status,
  }) =>
      _repository.setStatus(id: id, status: status);

  Future<Either<Failure, void>> remove(String id) => _repository.remove(id);
}
