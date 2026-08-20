import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../shared/material_comments/domain/entities/material_comment.dart';
import '../../domain/entities/teacher_course.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../../domain/repositories/teacher_course_repository.dart';
import '../datasources/teacher_course_service.dart';

class TeacherCourseRepositoryImpl
    with RepositoryGuard
    implements TeacherCourseRepository {
  const TeacherCourseRepositoryImpl(this._service);

  final TeacherCourseService _service;

  @override
  Future<Either<Failure, List<TeacherAssignedCourse>>> listCourses({
    String? status,
  }) =>
      guard(() => _service.listCourses(status: status));

  @override
  Future<Either<Failure, List<CourseDivision>>> listDivisions(String courseId) =>
      guard(() => _service.listDivisions(courseId));

  @override
  Future<Either<Failure, TeacherCourseTree>> getTree({
    required String courseId,
    String? divisionId,
  }) =>
      guard(() => _service.getTree(courseId: courseId, divisionId: divisionId));

  @override
  Future<Either<Failure, void>> createModule({
    required String courseId,
    required String divisionId,
    required String name,
    String? description,
  }) =>
      guard(
        () => _service.createModule(
          courseId: courseId,
          divisionId: divisionId,
          name: name,
          description: description,
        ),
      );

  @override
  Future<Either<Failure, void>> updateModule({
    required String id,
    required String name,
    String? description,
  }) =>
      guard(
        () => _service.updateModule(id: id, name: name, description: description),
      );

  @override
  Future<Either<Failure, void>> deleteModule(String id) =>
      guard(() => _service.deleteModule(id));

  @override
  Future<Either<Failure, void>> createTopic({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String name,
    String? description,
  }) =>
      guard(
        () => _service.createTopic(
          courseId: courseId,
          divisionId: divisionId,
          courseModuleId: courseModuleId,
          name: name,
          description: description,
        ),
      );

  @override
  Future<Either<Failure, void>> updateTopic({
    required String id,
    required String name,
    String? description,
  }) =>
      guard(
        () => _service.updateTopic(id: id, name: name, description: description),
      );

  @override
  Future<Either<Failure, void>> deleteTopic(String id) =>
      guard(() => _service.deleteTopic(id));

  @override
  Future<Either<Failure, void>> createMaterial({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String courseTopicId,
    required String name,
    String? description,
    String? content,
    String? videoUrl,
    List<String> attachments = const [],
  }) =>
      guard(
        () => _service.createMaterial(
          courseId: courseId,
          divisionId: divisionId,
          courseModuleId: courseModuleId,
          courseTopicId: courseTopicId,
          name: name,
          description: description,
          content: content,
          videoUrl: videoUrl,
          attachments: attachments,
        ),
      );

  @override
  Future<Either<Failure, void>> updateMaterial({
    required String id,
    String? name,
    Object? description = kAbsent,
    Object? content = kAbsent,
    Object? videoUrl = kAbsent,
    Object? attachments = kAbsent,
  }) =>
      guard(
        () => _service.updateMaterial(
          id: id,
          name: name,
          description: description,
          content: content,
          videoUrl: videoUrl,
          attachments: attachments,
        ),
      );

  @override
  Future<Either<Failure, void>> deleteMaterial(String id) =>
      guard(() => _service.deleteMaterial(id));

  // ── Material comments ─────────────────────────────────────────────────────
  //
  // `divisionId` is required by these endpoints, so an absent one is a
  // programming error rather than something to paper over with a default —
  // the teacher screen always has a resolved section by the time it can reach
  // a material.

  @override
  Future<Either<Failure, List<MaterialComment>>> listComments(
    String materialId, {
    String? divisionId,
  }) =>
      guard(
        () => _service.listComments(materialId, divisionId: divisionId!),
      );

  @override
  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
    String? divisionId,
  }) =>
      guard(
        () => _service.createComment(
          materialId: materialId,
          content: content,
          divisionId: divisionId!,
        ),
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
