import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/attendance.dart';
import '../models/attendance_model.dart';

/// Raw HTTP for the student attendance endpoints — the port of
/// `src/api/student-attendance`. Attendance is read-only for students.
class AttendanceService {
  const AttendanceService(this._client);

  final DioClient _client;

  /// `GET /student/attendance/courses/:courseId/analytics`.
  Future<CourseAttendanceModel> getCourseAnalytics(String courseId) async {
    final response = await _client.get(
      ApiUrls.studentCourseAttendance(courseId),
      parse: (data) =>
          CourseAttendanceModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/attendance/sessions?courseId&status&page&limit`.
  Future<Paginated<AttendanceSessionModel>> listSessions({
    String? courseId,
    String? status,
    int page = 1,
    int limit = AttendanceMeta.pageSize,
  }) async {
    final response = await _client.get(
      ApiUrls.studentAttendanceSessions,
      query: {
        'courseId': courseId,
        'status': status,
        'page': page,
        'limit': limit,
      },
      parse: (data) => Paginated<AttendanceSessionModel>.fromJson(
        data,
        AttendanceSessionModel.fromJson,
      ),
    );
    return response.data;
  }
}
