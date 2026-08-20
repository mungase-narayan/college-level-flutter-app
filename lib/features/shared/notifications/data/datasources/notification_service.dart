import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/notification_model.dart';

/// Raw HTTP for the notification feed.
///
/// The endpoint is role-agnostic — the backend resolves the recipient profile
/// from the caller's roles — so the same service backs every area's feed.
class NotificationService {
  const NotificationService(this._client);

  final DioClient _client;

  /// `GET /notifications` — newest first. `limit` is capped at 50 server-side.
  Future<NotificationFeedModel> list({
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) async {
    final response = await _client.get(
      ApiUrls.notifications,
      query: {
        'page': page,
        'limit': limit,
        if (unreadOnly ?? false) 'unread': true,
      },
      parse: NotificationFeedModel.fromJson,
    );
    return response.data;
  }

  /// `PATCH /notifications/:id/read` → `{ id }`.
  Future<void> markRead(String id) async {
    await _client.patch(
      ApiUrls.notificationRead(id),
      parse: (_) => null,
    );
  }
}
