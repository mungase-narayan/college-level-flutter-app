import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/teacher_dashboard_model.dart';

/// Raw HTTP for the teacher area.
class TeacherService {
  const TeacherService(this._client);

  final DioClient _client;

  /// `GET /teacher/dashboard` — no parameters.
  ///
  /// A teacher with no course assignments gets zeroed stats and empty lists,
  /// not a 404, so an empty dashboard is a success case.
  Future<TeacherDashboardModel> getDashboard() async {
    final response = await _client.get(
      ApiUrls.teacherDashboard,
      parse: (data) => TeacherDashboardModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }
}
