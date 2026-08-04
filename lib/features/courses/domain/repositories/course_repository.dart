import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/course.dart';
import '../entities/course_tree.dart';

abstract class CourseRepository {
  Future<Either<Failure, Paginated<CourseEnrollment>>> listEnrolledCourses({
    int page,
    int limit,
    String? semesterId,
    String? status,
    String? search,
  });

  Future<Either<Failure, Course>> getCourse(String courseId);

  Future<Either<Failure, CourseTree>> getCourseTree(String courseId);

  Future<Either<Failure, Unit>> setMaterialCompleted({
    required String materialId,
    required bool completed,
  });
}
