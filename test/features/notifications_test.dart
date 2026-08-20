import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/shared/notifications/data/models/notification_model.dart';
import 'package:college_level/features/shared/notifications/domain/entities/app_notification.dart';
import 'package:college_level/features/shared/notifications/domain/usecases/notification_usecases.dart';
import 'package:college_level/features/shared/notifications/presentation/bloc/notifications_cubit.dart';

class _MockList extends Mock implements ListNotificationsUseCase {}

class _MockMarkRead extends Mock implements MarkNotificationReadUseCase {}

/// `GET /notifications` — the envelope's `data`, as the controller builds it.
const _payload = <String, dynamic>{
  'data': [
    {
      'id': 'n-1',
      'type': 'assignment_created',
      'title': 'New assignment',
      'description': 'CS201 · Unit Test 1',
      'redirectUrl': '/teacher/assignments/a-1',
      'isRead': false,
      'readAt': null,
      'createdAt': '2026-08-19T04:30:00.000Z',
      'createdBy': {
        'id': 'u-9',
        'fullName': 'Asha Rao',
        'avatar': null,
      },
    },
    {
      'id': 'n-2',
      'type': 'attendance_marked',
      'title': 'Attendance finalized',
      'description': 'Division A',
      'redirectUrl': '/teacher/attendance/s-1',
      'isRead': true,
      'readAt': '2026-08-19T05:00:00.000Z',
      'createdAt': '2026-08-19T04:00:00.000Z',
      'createdBy': null,
    },
  ],
  'pagination': {'page': 1, 'limit': 20, 'total': 2, 'totalPages': 1},
  'unreadCount': 1,
};

NotificationFeed _feed({bool firstIsRead = false, int unreadCount = 1}) =>
    NotificationFeed(
      items: [
        AppNotification(
          id: 'n-1',
          type: 'assignment_created',
          title: 'New assignment',
          description: 'CS201',
          redirectUrl: '/teacher/assignments/a-1',
          isRead: firstIsRead,
          createdAt: null,
        ),
        const AppNotification(
          id: 'n-2',
          type: 'announcement',
          title: 'Holiday',
          description: '',
          redirectUrl: '',
          isRead: true,
          createdAt: null,
        ),
      ],
      pagination: NotificationFeedModel.fromJson(_payload).pagination,
      unreadCount: unreadCount,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const PageParams());
    registerFallbackValue(const IdParams('x'));
  });

  group('NotificationFeedModel', () {
    test('parses rows, pagination, and the unread badge', () {
      final feed = NotificationFeedModel.fromJson(_payload);

      expect(feed.items, hasLength(2));
      expect(feed.pagination.total, 2);
      expect(feed.unreadCount, 1);
    });

    test('reads every field of a row', () {
      final row = NotificationFeedModel.fromJson(_payload).items.first;

      expect(row.id, 'n-1');
      expect(row.type, 'assignment_created');
      expect(row.title, 'New assignment');
      expect(row.description, 'CS201 · Unit Test 1');
      expect(row.redirectUrl, '/teacher/assignments/a-1');
      expect(row.isRead, isFalse);
      // Kept as the raw ISO string, which is what Fmt.relative consumes.
      expect(row.createdAt, '2026-08-19T04:30:00.000Z');
      expect(row.createdBy?.fullName, 'Asha Rao');
    });

    test('a null author is absent, not an empty author', () {
      final row = NotificationFeedModel.fromJson(_payload).items[1];
      expect(row.createdBy, isNull);
    });

    test('an absent unreadCount means nothing to badge', () {
      // The server omits the key on some queries; it must not throw or leave
      // the badge undefined.
      final feed = NotificationFeedModel.fromJson(const {
        'data': <dynamic>[],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1},
      });

      expect(feed.unreadCount, 0);
      expect(feed.items, isEmpty);
    });

    test('tolerates a bare array with no envelope', () {
      final feed = NotificationFeedModel.fromJson(const [
        {'id': 'n-9', 'type': 'announcement', 'title': 'Hi'},
      ]);

      expect(feed.items, hasLength(1));
      expect(feed.items.first.id, 'n-9');
      expect(feed.unreadCount, 0);
    });

    test('missing keys degrade to empty strings rather than throwing', () {
      final feed = NotificationFeedModel.fromJson(const {
        'data': [<String, dynamic>{}],
      });

      expect(feed.items.first.id, '');
      expect(feed.items.first.title, '');
      expect(feed.items.first.isRead, isFalse);
    });
  });

  group('NotificationMeta', () {
    test('maps the types the teacher feed actually sees', () {
      expect(
        NotificationMeta.of(NotificationType.assignmentCreated).shade,
        TwColors.violet,
      );
      expect(
        NotificationMeta.of(NotificationType.attendanceMarked).shade,
        TwColors.teal,
      );
      expect(
        NotificationMeta.of(NotificationType.announcement).icon,
        Icons.campaign_rounded,
      );
    });

    test('an unknown type falls back to a neutral bell', () {
      // The backend enum grows independently of app releases, so an unmapped
      // value must render rather than crash the feed.
      final meta = NotificationMeta.of('some_future_event');

      expect(meta, NotificationMeta.fallback);
      expect(meta.icon, Icons.notifications_none_rounded);
      expect(meta.shade, TwColors.slate);
    });

    test('every declared type has a mapping of its own', () {
      const declared = [
        NotificationType.courseEnrolled,
        NotificationType.courseAssigned,
        NotificationType.assignmentCreated,
        NotificationType.quizCreated,
        NotificationType.attendanceMarked,
        NotificationType.calendarEvent,
        NotificationType.materialAdded,
        NotificationType.practiceReviewed,
        NotificationType.assignmentEvaluated,
        NotificationType.quizEvaluated,
        NotificationType.noteLiked,
        NotificationType.noteCommented,
        NotificationType.noteShared,
        NotificationType.announcement,
        NotificationType.pointsEarned,
        NotificationType.rewardPurchased,
        NotificationType.orderMessage,
        NotificationType.contestPublished,
        NotificationType.contestResults,
      ];

      for (final type in declared) {
        expect(
          NotificationMeta.of(type).icon,
          isNot(NotificationMeta.fallback.icon),
          reason: '$type should have its own icon',
        );
      }
    });
  });

  group('NotificationsCubit', () {
    late _MockList list;
    late _MockMarkRead markRead;

    setUp(() {
      list = _MockList();
      markRead = _MockMarkRead();
    });

    test('loads page one', () async {
      when(() => list(any())).thenAnswer((_) async => Right(_feed()));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.items, hasLength(2));
      final captured = verify(() => list(captureAny())).captured.single;
      expect((captured as PageParams).page, 1);
      await cubit.close();
    });

    test('surfaces a failure so the panel can offer Retry', () async {
      when(() => list(any()))
          .thenAnswer((_) async => const Left(ServerFailure('nope')));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      await cubit.close();
    });

    test('markRead flips the row and decrements the badge', () async {
      when(() => list(any())).thenAnswer((_) async => Right(_feed()));
      when(() => markRead(any())).thenAnswer((_) async => const Right(null));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();
      await cubit.markRead('n-1');

      expect(cubit.state.data!.items.first.isRead, isTrue);
      expect(cubit.state.data!.items.first.readAt, isNotNull);
      expect(cubit.state.data!.unreadCount, 0);
      await cubit.close();
    });

    test('markRead reverts the row when the request fails', () async {
      when(() => list(any())).thenAnswer((_) async => Right(_feed()));
      when(() => markRead(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();
      await cubit.markRead('n-1');

      // The optimistic flip must not survive a failure — leaving it would show
      // the row as read while the server still has it unread.
      expect(cubit.state.data!.items.first.isRead, isFalse);
      expect(cubit.state.data!.unreadCount, 1);
      await cubit.close();
    });

    test('markRead is a no-op on an already-read row', () async {
      when(() => list(any()))
          .thenAnswer((_) async => Right(_feed(firstIsRead: true)));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();
      await cubit.markRead('n-1');

      verifyNever(() => markRead(any()));
      await cubit.close();
    });

    test('markRead ignores an id that is not in the feed', () async {
      when(() => list(any())).thenAnswer((_) async => Right(_feed()));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();
      await cubit.markRead('does-not-exist');

      verifyNever(() => markRead(any()));
      await cubit.close();
    });

    test('the badge never goes negative', () async {
      // The server omits `unreadCount` on some queries, so the local count can
      // legitimately start at 0 with unread rows on screen.
      when(() => list(any()))
          .thenAnswer((_) async => Right(_feed(unreadCount: 0)));
      when(() => markRead(any())).thenAnswer((_) async => const Right(null));

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();
      await cubit.markRead('n-1');

      expect(cubit.state.data!.unreadCount, 0);
      await cubit.close();
    });

    test('markRead before any load does nothing', () async {
      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.markRead('n-1');

      verifyNever(() => markRead(any()));
      await cubit.close();
    });
  });

  group('endpoints', () {
    test('the notification paths match the backend router', () {
      expect(ApiUrls.notifications, '/notifications');
      expect(ApiUrls.notificationRead('n-1'), '/notifications/n-1/read');
      expect(ApiUrls.notificationsUnreadCount, '/notifications/unread-count');
      expect(ApiUrls.notificationsReadAll, '/notifications/read-all');
    });
  });
}
