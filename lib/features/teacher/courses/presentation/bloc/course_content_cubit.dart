import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../domain/repositories/teacher_course_repository.dart';
import '../../domain/usecases/teacher_course_usecases.dart';

/// Runs the learning-plan mutations.
///
/// Every method returns the [Failure] on the way out, or null on success, so a
/// form sheet can close itself and toast without subscribing to state. The only
/// state published is [isBusy], which drives the submit buttons' spinners.
///
/// Reloading the tree afterwards is the caller's job — it belongs to
/// `TeacherCourseDetailCubit`, which owns it.
class CourseContentCubit extends Cubit<bool> {
  CourseContentCubit({
    required ModuleUseCases modules,
    required TopicUseCases topics,
    required MaterialUseCases materials,
  })  : _modules = modules,
        _topics = topics,
        _materials = materials,
        super(false);

  final ModuleUseCases _modules;
  final TopicUseCases _topics;
  final MaterialUseCases _materials;

  bool get isBusy => state;

  // ── Modules ───────────────────────────────────────────────────────────────

  Future<Failure?> createModule({
    required String courseId,
    required String divisionId,
    required String name,
    String? description,
  }) =>
      _run(
        () => _modules.create(
          courseId: courseId,
          divisionId: divisionId,
          name: name,
          description: description,
        ),
      );

  Future<Failure?> updateModule({
    required String id,
    required String name,
    String? description,
  }) =>
      _run(() => _modules.update(id: id, name: name, description: description));

  Future<Failure?> deleteModule(String id) => _run(() => _modules.delete(id));

  // ── Topics ────────────────────────────────────────────────────────────────

  Future<Failure?> createTopic({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String name,
    String? description,
  }) =>
      _run(
        () => _topics.create(
          courseId: courseId,
          divisionId: divisionId,
          courseModuleId: courseModuleId,
          name: name,
          description: description,
        ),
      );

  Future<Failure?> updateTopic({
    required String id,
    required String name,
    String? description,
  }) =>
      _run(() => _topics.update(id: id, name: name, description: description));

  Future<Failure?> deleteTopic(String id) => _run(() => _topics.delete(id));

  // ── Materials ─────────────────────────────────────────────────────────────

  Future<Failure?> createMaterial({
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
      _run(
        () => _materials.create(
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

  /// Partial update. Omitted arguments are left untouched; an explicit null
  /// clears that column — which is how "Remove video" works.
  Future<Failure?> updateMaterial({
    required String id,
    String? name,
    Object? description = kAbsent,
    Object? content = kAbsent,
    Object? videoUrl = kAbsent,
    Object? attachments = kAbsent,
  }) =>
      _run(
        () => _materials.update(
          id: id,
          name: name,
          description: description,
          content: content,
          videoUrl: videoUrl,
          attachments: attachments,
        ),
      );

  Future<Failure?> deleteMaterial(String id) =>
      _run(() => _materials.delete(id));

  Future<Failure?> _run(Future<Either<Failure, void>> Function() action) async {
    if (isClosed) return null;
    emit(true);
    final result = await action();
    if (isClosed) return null;
    emit(false);
    return result.fold((failure) => failure, (_) => null);
  }
}
