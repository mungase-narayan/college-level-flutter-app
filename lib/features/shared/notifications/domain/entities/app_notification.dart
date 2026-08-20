import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/network/api_response.dart';

/// One row of `GET /notifications`.
///
/// The recipient is resolved server-side from the caller's roles, so the same
/// endpoint serves the student feed and the teacher feed.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.redirectUrl,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.createdBy,
  });

  final String id;

  /// One of [NotificationType]'s wire strings. Kept as a raw string rather than
  /// an enum: the backend adds values faster than the client ships, and an
  /// unrecognised type must render with a fallback icon, not crash the feed.
  final String type;
  final String title;
  final String description;

  /// In-app path the row navigates to. May be empty when the server has no
  /// destination for this event.
  final String redirectUrl;
  final bool isRead;

  /// Kept as the raw ISO string the API sends, which is what `Fmt.relative`
  /// takes — the same convention the discussion entity uses.
  final String? createdAt;
  final String? readAt;
  final NotificationAuthor? createdBy;

  AppNotification copyWith({bool? isRead, String? readAt}) => AppNotification(
        id: id,
        type: type,
        title: title,
        description: description,
        redirectUrl: redirectUrl,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        createdBy: createdBy,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        description,
        redirectUrl,
        isRead,
        createdAt,
        readAt,
        createdBy,
      ];
}

class NotificationAuthor extends Equatable {
  const NotificationAuthor({required this.id, this.fullName, this.avatar});

  final String id;
  final String? fullName;
  final String? avatar;

  @override
  List<Object?> get props => [id, fullName, avatar];
}

/// A page of the feed plus the unread badge count.
///
/// `unreadCount` sits alongside `pagination` inside `data` rather than in the
/// envelope, and the server omits it on some queries — hence the default.
class NotificationFeed extends Equatable {
  const NotificationFeed({
    required this.items,
    required this.pagination,
    this.unreadCount = 0,
  });

  final List<AppNotification> items;
  final Pagination pagination;
  final int unreadCount;

  NotificationFeed copyWith({
    List<AppNotification>? items,
    int? unreadCount,
  }) =>
      NotificationFeed(
        items: items ?? this.items,
        pagination: pagination,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  @override
  List<Object?> get props => [items, pagination, unreadCount];
}

/// The wire values of the backend's notification type enum.
class NotificationType {
  const NotificationType._();

  static const courseEnrolled = 'course_enrolled';
  static const courseAssigned = 'course_assigned';
  static const assignmentCreated = 'assignment_created';
  static const quizCreated = 'quiz_created';
  static const attendanceMarked = 'attendance_marked';
  static const calendarEvent = 'calendar_event';
  static const materialAdded = 'material_added';
  static const practiceReviewed = 'practice_reviewed';
  static const assignmentEvaluated = 'assignment_evaluated';
  static const quizEvaluated = 'quiz_evaluated';
  static const noteLiked = 'note_liked';
  static const noteCommented = 'note_commented';
  static const noteShared = 'note_shared';
  static const announcement = 'announcement';
  static const pointsEarned = 'points_earned';
  static const rewardPurchased = 'reward_purchased';
  static const orderMessage = 'order_message';
  static const contestPublished = 'contest_published';
  static const contestResults = 'contest_results';
}

/// The icon and tint a feed row is drawn with — a port of `NOTIFICATION_META`
/// in `src/components/notifications/notification-meta.tsx`.
class NotificationMeta {
  const NotificationMeta({required this.icon, required this.shade});

  final IconData icon;
  final TwShade shade;

  /// Anything the client doesn't recognise still renders, as a neutral bell.
  /// The backend's enum grows independently of app releases.
  static const fallback = NotificationMeta(
    icon: Icons.notifications_none_rounded,
    shade: TwColors.slate,
  );

  static NotificationMeta of(String type) => switch (type) {
        NotificationType.courseEnrolled ||
        NotificationType.courseAssigned =>
          const NotificationMeta(
            icon: Icons.menu_book_rounded,
            shade: TwColors.blue,
          ),
        NotificationType.assignmentCreated => const NotificationMeta(
            icon: Icons.assignment_rounded,
            shade: TwColors.violet,
          ),
        NotificationType.quizCreated => const NotificationMeta(
            icon: Icons.checklist_rounded,
            shade: TwColors.indigo,
          ),
        NotificationType.attendanceMarked => const NotificationMeta(
            icon: Icons.event_available_rounded,
            shade: TwColors.teal,
          ),
        NotificationType.calendarEvent => const NotificationMeta(
            icon: Icons.calendar_month_rounded,
            shade: TwColors.cyan,
          ),
        NotificationType.materialAdded => const NotificationMeta(
            icon: Icons.description_rounded,
            shade: TwColors.purple,
          ),
        NotificationType.practiceReviewed ||
        NotificationType.assignmentEvaluated ||
        NotificationType.quizEvaluated =>
          const NotificationMeta(
            icon: Icons.fact_check_rounded,
            shade: TwColors.emerald,
          ),
        NotificationType.noteLiked => const NotificationMeta(
            icon: Icons.favorite_rounded,
            shade: TwColors.rose,
          ),
        NotificationType.noteCommented => const NotificationMeta(
            icon: Icons.mode_comment_rounded,
            shade: TwColors.blue,
          ),
        NotificationType.noteShared => const NotificationMeta(
            icon: Icons.share_rounded,
            shade: TwColors.cyan,
          ),
        NotificationType.announcement => const NotificationMeta(
            icon: Icons.campaign_rounded,
            shade: TwColors.orange,
          ),
        NotificationType.pointsEarned => const NotificationMeta(
            icon: Icons.stars_rounded,
            shade: TwColors.amber,
          ),
        NotificationType.rewardPurchased => const NotificationMeta(
            icon: Icons.redeem_rounded,
            shade: TwColors.pink,
          ),
        NotificationType.orderMessage => const NotificationMeta(
            icon: Icons.chat_bubble_rounded,
            shade: TwColors.fuchsia,
          ),
        NotificationType.contestPublished ||
        NotificationType.contestResults =>
          const NotificationMeta(
            icon: Icons.emoji_events_rounded,
            shade: TwColors.amber,
          ),
        _ => fallback,
      };
}
