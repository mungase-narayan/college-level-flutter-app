import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/course_enrollment.dart';

abstract class EnrollmentRepository {
  Future<Either<Failure, List<CourseEnrollmentRow>>> list({
    required String courseId,
    int limit,
  });

  Future<Either<Failure, Paginated<UnenrolledStudent>>> unenrolled({
    required String courseId,
    String? search,
    int page,
    int limit,
  });

  Future<Either<Failure, void>> enroll({
    required String courseId,
    required String studentId,
    required String userId,
  });

  Future<Either<Failure, void>> setStatus({
    required String id,
    required String status,
  });

  Future<Either<Failure, void>> remove(String id);
}
