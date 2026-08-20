import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/material_comment.dart';

/// The comment thread on a course material, from whichever side is reading it.
///
/// Students and teachers get the same thread through different endpoints —
/// `/student/course-materials/:id/comments` and
/// `/teacher/course-materials/:id/comments` — returning the same shape. Naming
/// that contract lets one set of use cases, one cubit, and one widget serve
/// both areas instead of the teacher growing a parallel copy of all three.
///
/// [divisionId] is the one asymmetry: the teacher endpoint **requires** it
/// (a teacher reads one section's thread), while the student endpoint derives
/// the section from the caller and rejects the parameter. Student
/// implementations therefore accept it and ignore it.
abstract class MaterialCommentSource {
  Future<Either<Failure, List<MaterialComment>>> listComments(
    String materialId, {
    String? divisionId,
  });

  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
    String? divisionId,
  });

  /// Replies to a **top-level** comment. The backend rejects a deeper thread
  /// with `COURSE_COMMENT_REPLY_DEPTH`.
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
