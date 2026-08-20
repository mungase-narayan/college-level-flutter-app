import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/repositories/teacher_course_repository.dart' show kAbsent;
import '../../../../shared/material_comments/data/models/material_comment_model.dart';
import '../models/teacher_course_model.dart';
import '../models/teacher_course_tree_model.dart';

/// Raw HTTP for the teacher's courses and the content authoring beneath them.
class TeacherCourseService {
  const TeacherCourseService(this._client);

  final DioClient _client;

  /// `GET /teacher/courses` — a **flat array**, one row per (course, division).
  Future<List<TeacherAssignedCourseModel>> listCourses({String? status}) async {
    final response = await _client.get(
      ApiUrls.teacherCourses,
      query: {'status': status},
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TeacherAssignedCourseModel.fromJson)
              .toList(growable: false) ??
          const <TeacherAssignedCourseModel>[],
    );
    return response.data;
  }

  /// `GET /teacher/courses/:id/divisions` — only the sections this teacher
  /// instructs, ordered by name.
  Future<List<CourseDivisionModel>> listDivisions(String courseId) async {
    final response = await _client.get(
      ApiUrls.teacherCourseDivisions(courseId),
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(CourseDivisionModel.fromJson)
              .toList(growable: false) ??
          const <CourseDivisionModel>[],
    );
    return response.data;
  }

  /// `GET /teacher/courses/:id/tree?divisionId=`.
  ///
  /// The server falls back to the teacher's first division when `divisionId`
  /// is omitted, but the client always sends one so the tree is unambiguous.
  Future<TeacherCourseTreeModel> getTree({
    required String courseId,
    String? divisionId,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherCourseTree(courseId),
      query: {'divisionId': divisionId},
      parse: (data) => TeacherCourseTreeModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  // ── Modules ───────────────────────────────────────────────────────────────

  /// `order` is deliberately never sent — the server assigns max+1, and there
  /// is no reordering UI.
  Future<void> createModule({
    required String courseId,
    required String divisionId,
    required String name,
    String? description,
  }) =>
      _client.post(
        ApiUrls.teacherCourseModules,
        body: {
          'courseId': courseId,
          'divisionId': divisionId,
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        parse: (_) => null,
      );

  Future<void> updateModule({
    required String id,
    required String name,
    String? description,
  }) =>
      _client.patch(
        ApiUrls.teacherCourseModule(id),
        // Null clears the field, so it is sent explicitly rather than omitted.
        body: {'name': name, 'description': description},
        parse: (_) => null,
      );

  Future<void> deleteModule(String id) =>
      _client.delete(ApiUrls.teacherCourseModule(id), parse: (_) => null);

  // ── Topics ────────────────────────────────────────────────────────────────

  Future<void> createTopic({
    required String courseId,
    required String divisionId,
    required String courseModuleId,
    required String name,
    String? description,
  }) =>
      _client.post(
        ApiUrls.teacherCourseTopics,
        body: {
          'courseId': courseId,
          'divisionId': divisionId,
          'courseModuleId': courseModuleId,
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        parse: (_) => null,
      );

  Future<void> updateTopic({
    required String id,
    required String name,
    String? description,
  }) =>
      _client.patch(
        ApiUrls.teacherCourseTopic(id),
        body: {'name': name, 'description': description},
        parse: (_) => null,
      );

  Future<void> deleteTopic(String id) =>
      _client.delete(ApiUrls.teacherCourseTopic(id), parse: (_) => null);

  // ── Materials ─────────────────────────────────────────────────────────────

  Future<void> createMaterial({
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
      _client.post(
        ApiUrls.teacherCourseMaterials,
        body: {
          'courseId': courseId,
          'divisionId': divisionId,
          'courseModuleId': courseModuleId,
          'courseTopicId': courseTopicId,
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (content != null && content.isNotEmpty) 'content': content,
          if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
          if (attachments.isNotEmpty) 'attachments': attachments,
        },
        parse: (_) => null,
      );

  /// Partial update — the inline Content/Video/Attachments panels each patch
  /// just their own field, so only the keys supplied are sent. A supplied null
  /// clears the field; an omitted key leaves it alone.
  Future<void> updateMaterial({
    required String id,
    String? name,
    Object? description = kAbsent,
    Object? content = kAbsent,
    Object? videoUrl = kAbsent,
    Object? attachments = kAbsent,
  }) =>
      _client.patch(
        ApiUrls.teacherCourseMaterial(id),
        body: {
          'name': ?name,
          if (!identical(description, kAbsent)) 'description': description,
          if (!identical(content, kAbsent)) 'content': content,
          if (!identical(videoUrl, kAbsent)) 'videoUrl': videoUrl,
          if (!identical(attachments, kAbsent)) 'attachments': attachments,
        },
        parse: (_) => null,
      );

  Future<void> deleteMaterial(String id) =>
      _client.delete(ApiUrls.teacherCourseMaterial(id), parse: (_) => null);

  // ── Material comments ─────────────────────────────────────────────────────

  /// `GET /teacher/course-materials/:id/comments?divisionId=` — the thread for
  /// one section. `divisionId` is **required**; the server answers 422 without it.
  Future<List<MaterialCommentModel>> listComments(
    String materialId, {
    required String divisionId,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherMaterialComments(materialId),
      query: {'divisionId': divisionId},
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MaterialCommentModel.fromJson)
              .toList(growable: false) ??
          const <MaterialCommentModel>[],
    );
    return response.data;
  }

  Future<MaterialCommentModel> createComment({
    required String materialId,
    required String content,
    required String divisionId,
  }) async {
    final response = await _client.post(
      ApiUrls.teacherMaterialComments(materialId),
      body: {'divisionId': divisionId, 'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// One level of threading only — the server rejects a reply to a reply.
  Future<MaterialCommentModel> replyToComment({
    required String commentId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiUrls.teacherMaterialCommentReplies(commentId),
      body: {'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<MaterialCommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    final response = await _client.patch(
      ApiUrls.teacherMaterialComment(commentId),
      body: {'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<void> deleteComment(String commentId) => _client.delete(
        ApiUrls.teacherMaterialComment(commentId),
        parse: (_) => null,
      );
}
