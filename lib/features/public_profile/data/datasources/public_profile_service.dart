import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/public_profile_model.dart';

/// Raw HTTP for the public student showcase.
class PublicProfileService {
  const PublicProfileService(this._client);

  final DioClient _client;

  /// `GET /public/students/:username`.
  ///
  /// Needs no auth. Signed-in callers still send their token — harmless, and it
  /// keeps this on the one configured client rather than a second bare Dio.
  Future<PublicProfileModel> getPublicProfile(String username) async {
    final response = await _client.get(
      ApiUrls.publicStudentProfile(username),
      parse: (data) =>
          PublicProfileModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }
}
