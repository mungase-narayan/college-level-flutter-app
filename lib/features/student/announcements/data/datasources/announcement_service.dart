import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/announcement.dart';
import '../models/announcement_model.dart';

/// Raw HTTP for the student announcement endpoints — the port of
/// `src/api/announcement`.
///
/// Students read the feed and one detail, and may register for events. Every
/// managing endpoint on the same router is behind a role guard they do not have,
/// which is also why the detail must be fetched from `/student/:id` rather than
/// `/:id`.
class AnnouncementService {
  const AnnouncementService(this._client);

  final DioClient _client;

  /// `GET /announcements/student/feed?page&limit&type&q`.
  ///
  /// `q` matches the **title** only, server-side.
  Future<Paginated<AnnouncementModel>> listFeed({
    String? query,
    String? type,
    int page = 1,
    int limit = AnnouncementMeta.pageSize,
  }) async {
    final response = await _client.get(
      ApiUrls.announcementsFeed,
      query: {'q': query, 'type': type, 'page': page, 'limit': limit},
      parse: (data) => Paginated<AnnouncementModel>.fromJson(
        data,
        AnnouncementModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `GET /announcements/student/:id`.
  Future<AnnouncementDetailModel> getDetail(String id) async {
    final response = await _client.get(
      ApiUrls.studentAnnouncement(id),
      parse: (data) => AnnouncementDetailModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /announcements/:id/register` — idempotent server-side, and events
  /// only.
  Future<AnnouncementRegistrationModel> register(String id) async {
    final response = await _client.post(
      ApiUrls.announcementRegister(id),
      parse: AnnouncementRegistrationModel.fromJson,
    );
    return response.data;
  }

  /// `POST /announcements/:id/cancel-registration` — 404s when there is no row.
  Future<AnnouncementRegistrationModel> cancelRegistration(String id) async {
    final response = await _client.post(
      ApiUrls.announcementCancelRegistration(id),
      parse: AnnouncementRegistrationModel.fromJson,
    );
    return response.data;
  }
}
