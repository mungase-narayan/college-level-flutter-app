import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/course_enrollment.dart';
import '../models/course_enrollment_model.dart';

/// Raw HTTP for course enrolments.
///
/// Every verb here is guarded `school_admin` + **`teacher`** — a class_teacher
/// or hod gets 403 even on the list. The picker endpoint is the exception and
/// is open to the whole teacher family.
class EnrollmentService {
  const EnrollmentService(this._client);

  final DioClient _client;

  /// `GET /course-enrollments?courseId=&limit=` — the web pulls 100 and filters
  /// and pages client-side, so this does too.
  Future<List<CourseEnrollmentRowModel>> list({
    required String courseId,
    int limit = 100,
  }) async {
    final response = await _client.get(
      ApiUrls.courseEnrollments,
      query: {'courseId': courseId, 'limit': limit},
      parse: (data) => Paginated<CourseEnrollmentRowModel>.fromJson(
        data,
        CourseEnrollmentRowModel.fromJson,
      ).items,
    );
    return response.data;
  }

  /// `GET /courses/:id/unenrolled-students`.
  Future<Paginated<UnenrolledStudent>> unenrolled({
    required String courseId,
    String? search,
    int page = 1,
    int limit = 8,
  }) async {
    final response = await _client.get(
      ApiUrls.unenrolledStudents(courseId),
      query: {'search': search, 'page': page, 'limit': limit},
      parse: (data) => Paginated<UnenrolledStudent>.fromJson(
        data,
        UnenrolledStudentModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `POST /course-enrollments` — one student.
  Future<void> enroll({
    required String courseId,
    required String studentId,
    required String userId,
  }) =>
      _client.post(
        ApiUrls.courseEnrollments,
        body: {
          'courseId': courseId,
          'studentId': studentId,
          'userId': userId,
          'status': 'active',
        },
        parse: (_) => null,
      );

  /// `PATCH /course-enrollments/:id/status`.
  Future<void> setStatus({required String id, required String status}) =>
      _client.patch(
        ApiUrls.courseEnrollmentStatus(id),
        body: {'status': status},
        parse: (_) => null,
      );

  Future<void> remove(String id) =>
      _client.delete(ApiUrls.courseEnrollment(id), parse: (_) => null);
}
