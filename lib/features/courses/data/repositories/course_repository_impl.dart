import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_tree.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/course_service.dart';

class CourseRepositoryImpl with RepositoryGuard implements CourseRepository {
  const CourseRepositoryImpl(this._service);

  final CourseService _service;

  @override
  Future<Either<Failure, Paginated<CourseEnrollment>>> listEnrolledCourses({
    int page = 1,
    int limit = 100,
    String? semesterId,
    String? status,
    String? search,
  }) =>
      guard(() async {
        final result = await _service.listEnrolledCourses(
          page: page,
          limit: limit,
          semesterId: semesterId,
          status: status,
          search: search,
        );
        return Paginated<CourseEnrollment>(
          items: result.items,
          pagination: result.pagination,
        );
      });

  @override
  Future<Either<Failure, Course>> getCourse(String courseId) =>
      guard(() => _service.getCourse(courseId));

  @override
  Future<Either<Failure, CourseTree>> getCourseTree(String courseId) =>
      guard(() => _service.getCourseTree(courseId));

  @override
  Future<Either<Failure, Unit>> setMaterialCompleted({
    required String materialId,
    required bool completed,
  }) =>
      guard(() async {
        await _service.setMaterialCompleted(
          materialId: materialId,
          completed: completed,
        );
        return unit;
      });
}
