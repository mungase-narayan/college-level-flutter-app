import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/course.dart';
import '../entities/course_tree.dart';
import '../entities/material_comment.dart';

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

  Future<Either<Failure, List<MaterialComment>>> listComments(String materialId);

  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
  });

  Future<Either<Failure, MaterialComment>> replyToComment({
    required String commentId,
    required String content,
  });

  Future<Either<Failure, MaterialComment>> updateComment({
    required String commentId,
    required String content,
  });

  Future<Either<Failure, Unit>> deleteComment(String commentId);
}
