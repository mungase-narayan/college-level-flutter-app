import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/teacher_course.dart';
import '../entities/teacher_course_tree.dart';
import '../repositories/teacher_course_repository.dart';

class ListTeacherCoursesUseCase
    implements UseCase<List<TeacherAssignedCourse>, TeacherCourseListParams> {
  const ListTeacherCoursesUseCase(this._repository);

  final TeacherCourseRepository _repository;

  @override
  Future<Either<Failure, List<TeacherAssignedCourse>>> call(
    TeacherCourseListParams params,
  ) =>
      _repository.listCourses(status: params.status);
}

class TeacherCourseListParams extends Equatable {
  const TeacherCourseListParams({this.status});

  /// The only filter the server applies; search and type are client-side.
  final String? status;

  @override
  List<Object?> get props => [status];
}

class ListCourseDivisionsUseCase
    implements UseCase<List<CourseDivision>, IdParams> {
  const ListCourseDivisionsUseCase(this._repository);

  final TeacherCourseRepository _repository;

  @override
  Future<Either<Failure, List<CourseDivision>>> call(IdParams params) =>
      _repository.listDivisions(params.id);
}

class GetTeacherCourseTreeUseCase
    implements UseCase<TeacherCourseTree, CourseTreeParams> {
  const GetTeacherCourseTreeUseCase(this._repository);

  final TeacherCourseRepository _repository;

  @override
  Future<Either<Failure, TeacherCourseTree>> call(CourseTreeParams params) =>
      _repository.getTree(
        courseId: params.courseId,
        divisionId: params.divisionId,
      );
}

class CourseTreeParams extends Equatable {
  const CourseTreeParams({required this.courseId, this.divisionId});

  final String courseId;
  final String? divisionId;

  @override
  List<Object?> get props => [courseId, divisionId];
}

// ── Content authoring ───────────────────────────────────────────────────────
//
// One use case per node type, each covering create/update/delete, since the
// three always travel together at the call site (a tree row's kebab menu).

class ModuleUseCases {
  const ModuleUseCases(this._repository);

  final TeacherCourseRepository _repository;

  Future<Either<Failure, void>> create({
    required String courseId,
    required String divisionId,
    required String name,
    String? description,
  }) =>
      _repository.createModule(
        courseId: courseId,
        divisionId: divisionId,
        name: name,
        description: description,
      );

  Future<Either<Failure, void>> update({
    required String id,
    required String name,
    String? description,
  }) =>
      _repository.updateModule(id: id, name: name, description: description);

  Future<Either<Failure, void>> delete(String id) =>
      _repository.deleteModule(id);
}

class TopicUseCases {
  const TopicUseCases(this._repository);

  final TeacherCourseRepository _repository;

  Future<Either<Failure, void>> create({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String name,
    String? description,
  }) =>
      _repository.createTopic(
        courseId: courseId,
        divisionId: divisionId,
        courseModuleId: courseModuleId,
        name: name,
        description: description,
      );

  Future<Either<Failure, void>> update({
    required String id,
    required String name,
    String? description,
  }) =>
      _repository.updateTopic(id: id, name: name, description: description);

  Future<Either<Failure, void>> delete(String id) => _repository.deleteTopic(id);
}

class MaterialUseCases {
  const MaterialUseCases(this._repository);

  final TeacherCourseRepository _repository;

  Future<Either<Failure, void>> create({
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
      _repository.createMaterial(
        courseId: courseId,
        divisionId: divisionId,
        courseModuleId: courseModuleId,
        courseTopicId: courseTopicId,
        name: name,
        description: description,
        content: content,
        videoUrl: videoUrl,
        attachments: attachments,
      );

  /// Partial update — pass only what changed. The inline Content, Video, and
  /// Attachments panels each call this with a single field.
  Future<Either<Failure, void>> update({
    required String id,
    String? name,
    Object? description = kAbsent,
    Object? content = kAbsent,
    Object? videoUrl = kAbsent,
    Object? attachments = kAbsent,
  }) =>
      _repository.updateMaterial(
        id: id,
        name: name,
        description: description,
        content: content,
        videoUrl: videoUrl,
        attachments: attachments,
      );

  Future<Either<Failure, void>> delete(String id) =>
      _repository.deleteMaterial(id);
}
