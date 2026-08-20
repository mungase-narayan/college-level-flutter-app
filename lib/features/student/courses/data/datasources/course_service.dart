import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/course_model.dart';
import '../models/course_tree_model.dart';
import '../../../../shared/material_comments/data/models/material_comment_model.dart';

/// Raw HTTP for the student course endpoints — the port of
/// `src/api/student-course`.
class CourseService {
  const CourseService(this._client);

  final DioClient _client;

  /// `GET /student/courses`.
  ///
  /// The web app fetches everything with `limit: 100` and filters by semester
  /// and free text on the client, so the same defaults are used here.
  Future<Paginated<CourseEnrollmentModel>> listEnrolledCourses({
    int page = 1,
    int limit = 100,
    String? semesterId,
    String? status,
    String? search,
  }) async {
    final response = await _client.get(
      ApiUrls.studentCourses,
      query: {
        'page': page,
        'limit': limit,
        'semesterId': semesterId,
        'status': status,
        'search': search,
      },
      parse: (data) => Paginated<CourseEnrollmentModel>.fromJson(
        data,
        CourseEnrollmentModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `GET /student/courses/:id` — course metadata without the content tree.
  Future<CourseModel> getCourse(String courseId) async {
    final response = await _client.get(
      ApiUrls.studentCourse(courseId),
      parse: (data) {
        final json = (data as Map<String, dynamic>?) ?? const {};
        // The detail endpoint may nest the course or return it flat.
        final course = json['course'];
        return CourseModel.fromJson(
          course is Map<String, dynamic> ? course : json,
        );
      },
    );
    return response.data;
  }

  /// `GET /student/courses/:id/tree` — modules → topics → materials, scoped to
  /// the student's division, with completion folded in.
  Future<CourseTreeModel> getCourseTree(String courseId) async {
    final response = await _client.get(
      ApiUrls.studentCourseTree(courseId),
      parse: (data) =>
          CourseTreeModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST|DELETE /student/course-materials/:id/complete`.
  ///
  /// The POST is idempotent server-side, so a double tap is harmless.
  Future<void> setMaterialCompleted({
    required String materialId,
    required bool completed,
  }) async {
    final path = ApiUrls.studentMaterialComplete(materialId);
    if (completed) {
      await _client.post(path, parse: (_) => null);
    } else {
      await _client.delete(path, parse: (_) => null);
    }
  }

  // ── Material comments ──────────────────────────────────────────────────────
  //
  // The student surface of `src/api/course-material-comments`. A student never
  // sends `divisionId`: the backend resolves it from their own enrolment, and
  // returns 403 `COURSE_COMMENT_NO_DIVISION` when they have none.

  /// `GET /student/course-materials/:id/comments` — top-level comments, each
  /// with its replies nested one level deep.
  Future<List<MaterialCommentModel>> listComments(String materialId) async {
    final response = await _client.get(
      ApiUrls.studentMaterialComments(materialId),
      parse: (data) =>
          (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MaterialCommentModel.fromJson)
              .toList(growable: false) ??
          const <MaterialCommentModel>[],
    );
    return response.data;
  }

  /// `POST /student/course-materials/:id/comments`.
  Future<MaterialCommentModel> createComment({
    required String materialId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiUrls.studentMaterialComments(materialId),
      body: {'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /student/course-material-comments/:id/replies`.
  Future<MaterialCommentModel> replyToComment({
    required String commentId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiUrls.studentCommentReplies(commentId),
      body: {'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `PATCH /student/course-material-comments/:id`.
  Future<MaterialCommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    final response = await _client.patch(
      ApiUrls.studentComment(commentId),
      body: {'content': content},
      parse: (data) => MaterialCommentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `DELETE /student/course-material-comments/:id`.
  Future<void> deleteComment(String commentId) =>
      _client.delete(ApiUrls.studentComment(commentId), parse: (_) => null);
}
