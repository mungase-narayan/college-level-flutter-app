import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../shared/material_comments/domain/repositories/material_comment_source.dart';
import '../entities/teacher_course.dart';
import '../entities/teacher_course_tree.dart';

/// The teacher's view of a course, including its material comment thread.
///
/// Implements [MaterialCommentSource] so the comment use cases, cubit and
/// widget built for the student area serve the teacher unchanged — the two
/// endpoints differ, the thread does not.
abstract class TeacherCourseRepository implements MaterialCommentSource {
  Future<Either<Failure, List<TeacherAssignedCourse>>> listCourses({
    String? status,
  });

  Future<Either<Failure, List<CourseDivision>>> listDivisions(String courseId);

  Future<Either<Failure, TeacherCourseTree>> getTree({
    required String courseId,
    String? divisionId,
  });

  // ── Content authoring ─────────────────────────────────────────────────────

  Future<Either<Failure, void>> createModule({
    required String courseId,
    required String divisionId,
    required String name,
    String? description,
  });

  Future<Either<Failure, void>> updateModule({
    required String id,
    required String name,
    String? description,
  });

  Future<Either<Failure, void>> deleteModule(String id);

  Future<Either<Failure, void>> createTopic({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String name,
    String? description,
  });

  Future<Either<Failure, void>> updateTopic({
    required String id,
    required String name,
    String? description,
  });

  Future<Either<Failure, void>> deleteTopic(String id);

  Future<Either<Failure, void>> createMaterial({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String courseTopicId,
    required String name,
    String? description,
    String? content,
    String? videoUrl,
    List<String> attachments,
  });

  /// Partial update. Omitted arguments are left untouched; an explicit null
  /// clears the column.
  Future<Either<Failure, void>> updateMaterial({
    required String id,
    String? name,
    Object? description,
    Object? content,
    Object? videoUrl,
    Object? attachments,
  });

  Future<Either<Failure, void>> deleteMaterial(String id);
}

/// Shared sentinel for the partial-update arguments above.
const Object kAbsent = Object();
