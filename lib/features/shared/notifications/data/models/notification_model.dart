import '../../../../../core/network/api_response.dart';
import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.description,
    required super.redirectUrl,
    required super.isRead,
    required super.createdAt,
    super.readAt,
    super.createdBy,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        redirectUrl: json['redirectUrl'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: json['createdAt'] as String?,
        readAt: json['readAt'] as String?,
        createdBy: json['createdBy'] == null
            ? null
            : NotificationAuthorModel.fromJson(
                json['createdBy'] as Map<String, dynamic>,
              ),
      );
}

class NotificationAuthorModel extends NotificationAuthor {
  const NotificationAuthorModel({
    required super.id,
    super.fullName,
    super.avatar,
  });

  factory NotificationAuthorModel.fromJson(Map<String, dynamic> json) =>
      NotificationAuthorModel(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String?,
        avatar: json['avatar'] as String?,
      );
}

class NotificationFeedModel extends NotificationFeed {
  const NotificationFeedModel({
    required super.items,
    required super.pagination,
    super.unreadCount,
  });

  factory NotificationFeedModel.fromJson(Object? data) {
    final page = Paginated<AppNotification>.fromJson(
      data,
      AppNotificationModel.fromJson,
    );
    // `unreadCount` rides inside `data` next to `pagination`, and the server
    // omits it on some queries — absent means "nothing to badge", not zero rows.
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return NotificationFeedModel(
      items: page.items,
      pagination: page.pagination,
      unreadCount: _int(map['unreadCount']),
    );
  }
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
