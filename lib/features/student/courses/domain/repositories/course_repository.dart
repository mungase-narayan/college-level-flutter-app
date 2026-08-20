import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/course.dart';
import '../entities/course_tree.dart';
import '../../../../shared/material_comments/domain/entities/material_comment.dart';
import '../../../../shared/material_comments/domain/repositories/material_comment_source.dart';

/// The student's view of a course, including its material comment thread.
abstract class CourseRepository implements MaterialCommentSource {
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

  /// [divisionId] is part of the shared [MaterialCommentSource] contract and is
  /// ignored here — the student endpoint derives the section from the caller.
  @override
  Future<Either<Failure, List<MaterialComment>>> listComments(
    String materialId, {
    String? divisionId,
  });

  @override
  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
    String? divisionId,
  });

  @override
  Future<Either<Failure, MaterialComment>> replyToComment({
    required String commentId,
    required String content,
  });

  @override
  Future<Either<Failure, MaterialComment>> updateComment({
    required String commentId,
    required String content,
  });

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId);
}
