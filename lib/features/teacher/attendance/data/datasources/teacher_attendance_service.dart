import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/attendance_model.dart';

/// Raw HTTP for teacher attendance.
class TeacherAttendanceService {
  const TeacherAttendanceService(this._client);

  final DioClient _client;

  /// `GET /teacher/attendance/sessions` — `{data, pagination}`.
  Future<AttendanceSessionPageModel> listSessions({
    String? courseId,
    String? divisionId,
    String? status,
    String? type,
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherAttendanceSessions,
      query: {
        'courseId': courseId,
        'divisionId': divisionId,
        'status': status,
        'type': type,
        'page': page,
        'limit': limit,
      },
      parse: AttendanceSessionPageModel.fromJson,
    );
    return response.data;
  }

  /// `GET /teacher/attendance/sessions/:id` — session plus the full roster.
  Future<AttendanceSessionDetailModel> getSession(String id) async {
    final response = await _client.get(
      ApiUrls.teacherAttendanceSession(id),
      parse: (data) => AttendanceSessionDetailModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `GET /teacher/attendance/today`.
  Future<List<TodaySlotModel>> todaySlots({
    String? courseId,
    String? divisionId,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherAttendanceToday,
      query: {'courseId': courseId, 'divisionId': divisionId},
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TodaySlotModel.fromJson)
              .toList(growable: false) ??
          const <TodaySlotModel>[],
    );
    return response.data;
  }

  /// `GET /teacher/attendance/analytics` — both params required by the server.
  Future<AttendanceAnalyticsModel> analytics({
    required String courseId,
    required String divisionId,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherAttendanceAnalytics,
      query: {'courseId': courseId, 'divisionId': divisionId},
      parse: (data) => AttendanceAnalyticsModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /teacher/attendance/sessions` → 201, returning the new session.
  ///
  /// Times go up as ISO instants; `sessionDate` stays a bare `YYYY-MM-DD`,
  /// which is what the column is.
  Future<AttendanceSessionModel> createSession({
    required String courseId,
    required String divisionId,
    required String type,
    required String sessionDate,
    required String startTime,
    String? endTime,
    String? topic,
    String? timetableSlotId,
  }) async {
    final response = await _client.post(
      ApiUrls.teacherAttendanceSessions,
      body: {
        'courseId': courseId,
        'divisionId': divisionId,
        'type': type,
        'sessionDate': sessionDate,
        'startTime': startTime,
        'endTime': endTime,
        'topic': topic,
        'timetableSlotId': timetableSlotId,
      },
      parse: (data) => AttendanceSessionModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<void> deleteSession(String id) => _client.delete(
        ApiUrls.teacherAttendanceSession(id),
        parse: (_) => null,
      );

  /// `POST /teacher/attendance/sessions/:id/mark`.
  ///
  /// An upsert keyed on (session, student), so a partial list is legal — but
  /// the screen always sends the whole roster, matching the web.
  Future<void> mark({
    required String sessionId,
    required List<({String studentId, String status})> records,
  }) =>
      _client.post(
        ApiUrls.teacherAttendanceMark(sessionId),
        body: {
          'records': [
            for (final r in records)
              {'studentId': r.studentId, 'status': r.status},
          ],
        },
        parse: (_) => null,
      );

  /// `POST /teacher/attendance/sessions/:id/finalize` — no body. Rejected with
  /// 409 if already finalized.
  Future<void> finalize(String sessionId) => _client.post(
        ApiUrls.teacherAttendanceFinalize(sessionId),
        parse: (_) => null,
      );
}
