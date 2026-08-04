import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/student_analytics_model.dart';

/// Raw HTTP for the student analytics endpoints — the port of
/// `src/api/student-analytics`.
class AnalyticsService {
  const AnalyticsService(this._client);

  final DioClient _client;

  /// `GET /student/analytics/overview`.
  Future<AnalyticsOverviewModel> getOverview() async {
    final response = await _client.get(
      ApiUrls.studentAnalyticsOverview,
      parse: (data) => AnalyticsOverviewModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `GET /student/analytics/semester/:semesterId`.
  ///
  /// Returns null when the semester isn't in the student's scope — the backend
  /// signals that with a 200 carrying `{ error: "not_found" }` rather than a
  /// 404, so it must be detected from the body.
  Future<SemesterAnalyticsModel?> getSemester(String semesterId) async {
    final response = await _client.get(
      ApiUrls.studentAnalyticsSemester(semesterId),
      parse: (data) {
        if (data == null || SemesterAnalyticsModel.isNotFound(data)) return null;
        return SemesterAnalyticsModel.fromJson(
          (data as Map<String, dynamic>?) ?? const {},
        );
      },
    );
    return response.data;
  }
}
