import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_tree.dart';
import '../../../../shared/material_comments/domain/entities/material_comment.dart';
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

  @override
  Future<Either<Failure, List<MaterialComment>>> listComments(
    String materialId, {
    // Part of the shared contract; the student endpoint has no division
    // parameter and derives the section from the caller.
    String? divisionId,
  }) =>
      guard(() => _service.listComments(materialId));

  @override
  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
    String? divisionId,
  }) =>
      guard(
        () => _service.createComment(materialId: materialId, content: content),
      );

  @override
  Future<Either<Failure, MaterialComment>> replyToComment({
    required String commentId,
    required String content,
  }) =>
      guard(
        () => _service.replyToComment(commentId: commentId, content: content),
      );

  @override
  Future<Either<Failure, MaterialComment>> updateComment({
    required String commentId,
    required String content,
  }) =>
      guard(
        () => _service.updateComment(commentId: commentId, content: content),
      );

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) =>
      guard(() async {
        await _service.deleteComment(commentId);
        return unit;
      });
}
