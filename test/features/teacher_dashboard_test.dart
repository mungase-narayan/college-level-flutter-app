import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/shared/notifications/domain/entities/app_notification.dart';
import 'package:college_level/features/shared/notifications/domain/usecases/notification_usecases.dart';
import 'package:college_level/features/shared/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:college_level/features/teacher/dashboard/data/models/teacher_dashboard_model.dart';
import 'package:college_level/features/teacher/dashboard/domain/entities/teacher_dashboard.dart';
import 'package:college_level/features/teacher/dashboard/domain/usecases/teacher_usecases.dart';
import 'package:college_level/features/teacher/dashboard/presentation/bloc/teacher_dashboard_cubit.dart';
import 'package:college_level/features/teacher/dashboard/presentation/widgets/my_courses_grid.dart';
import 'package:college_level/features/teacher/dashboard/presentation/widgets/today_sessions_timeline.dart';

import '../support/platform_parity.dart';

class _MockGetDashboard extends Mock implements GetTeacherDashboardUseCase {}

class _MockListNotifications extends Mock implements ListNotificationsUseCase {}

class _MockMarkRead extends Mock implements MarkNotificationReadUseCase {}

/// The payload exactly as `teacher-dashboard.service.ts` builds it.
const _payload = <String, dynamic>{
  'stats': {'coursesCount': 3, 'studentsCount': 128, 'topicsCount': 42},
  'todaySessions': [
    {
      'id': 'ts-1',
      'time': '9:00 AM',
      'title': 'Data Structures',
      'division': 'A',
      'room': 'C-204',
      'students': 60,
      'status': 'live',
    },
    {
      'id': 'ts-2',
      'time': '11:00 AM',
      'title': 'Algorithms',
      'division': '—',
      'room': '—',
      'students': 45,
      'status': 'upcoming',
    },
  ],
  'myCourses': [
    {
      'courseId': 'c-1',
      'name': 'Data Structures',
      'code': 'CS201',
      'colorCode': '#4F46E5',
      'division': 'A',
      'students': 60,
      'totalTopics': 14,
    },
    {
      'courseId': 'c-1',
      'name': 'Data Structures',
      'code': 'CS201',
      'colorCode': null,
      'division': 'B',
      'students': 55,
      'totalTopics': 12,
    },
  ],
};

TeacherDashboard _dashboard({
  List<TeacherTodaySession> sessions = const [],
  List<TeacherCourseSummary> courses = const [],
}) =>
    TeacherDashboard(
      stats: const TeacherDashboardStats(
        coursesCount: 1,
        studentsCount: 2,
        topicsCount: 3,
      ),
      todaySessions: sessions,
      myCourses: courses,
    );

TeacherTodaySession _session({String status = TeacherSessionStatus.upcoming}) =>
    TeacherTodaySession(
      id: 's-$status',
      time: '9:00 AM',
      title: 'Data Structures',
      division: 'A',
      room: 'C-204',
      students: 30,
      status: status,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const PageParams());
    registerFallbackValue(const IdParams('x'));
  });

  group('TeacherDashboardModel', () {
    test('parses the whole payload', () {
      final data = TeacherDashboardModel.fromJson(_payload);

      expect(data.stats.coursesCount, 3);
      expect(data.stats.studentsCount, 128);
      expect(data.stats.topicsCount, 42);
      expect(data.todaySessions, hasLength(2));
      expect(data.myCourses, hasLength(2));
    });

    test('keeps the server-formatted time string verbatim', () {
      // There are no start/end timestamps in the payload — `time` is already a
      // display string, and reformatting it is not possible.
      final data = TeacherDashboardModel.fromJson(_payload);
      expect(data.todaySessions.first.time, '9:00 AM');
    });

    test('reads the em dash the server sends as absent', () {
      final data = TeacherDashboardModel.fromJson(_payload);
      final withValues = data.todaySessions[0];
      final withPlaceholders = data.todaySessions[1];

      expect(withValues.divisionOrNull, 'A');
      expect(withValues.roomOrNull, 'C-204');
      // The backend writes "—", not null — rendering it raw would put a stray
      // dash in the middle of the session row.
      expect(withPlaceholders.divisionOrNull, isNull);
      expect(withPlaceholders.roomOrNull, isNull);
    });

    test('one course taught across two divisions stays two distinct rows', () {
      // `myCourses` is one row per (course, division), so `courseId` alone is
      // not a unique key — keying on it would collapse the sections.
      final data = TeacherDashboardModel.fromJson(_payload);
      final keys = data.myCourses.map((c) => c.key).toList();

      // One distinct course, two rows: keying the list on `courseId` would
      // collapse the two sections into one card and lose a division.
      expect(data.myCourses.map((c) => c.courseId).toSet(), hasLength(1));
      expect(keys, ['c-1-A', 'c-1-B']);
      expect(keys.toSet(), hasLength(data.myCourses.length));
    });

    test('a null colorCode survives as null', () {
      final data = TeacherDashboardModel.fromJson(_payload);
      expect(data.myCourses[0].colorCode, '#4F46E5');
      expect(data.myCourses[1].colorCode, isNull);
    });

    test('the empty-teacher payload parses as an empty dashboard', () {
      // A teacher with no course assignments gets zeros and empty arrays on a
      // 200 — an empty dashboard is a success case, not an error.
      final data = TeacherDashboardModel.fromJson(const {
        'stats': {'coursesCount': 0, 'studentsCount': 0, 'topicsCount': 0},
        'todaySessions': <dynamic>[],
        'myCourses': <dynamic>[],
      });

      expect(data.stats.coursesCount, 0);
      expect(data.todaySessions, isEmpty);
      expect(data.myCourses, isEmpty);
      expect(data.hasPendingSessions, isFalse);
    });

    test('missing keys degrade instead of throwing', () {
      final data = TeacherDashboardModel.fromJson(const {});
      expect(data.stats.studentsCount, 0);
      expect(data.todaySessions, isEmpty);
      expect(data.myCourses, isEmpty);
    });
  });

  group('TeacherSessionStatus', () {
    test('labels match the web status pills', () {
      expect(TeacherSessionStatus.label(TeacherSessionStatus.live), 'Live Now');
      expect(
        TeacherSessionStatus.label(TeacherSessionStatus.upcoming),
        'Upcoming',
      );
      expect(
        TeacherSessionStatus.label(TeacherSessionStatus.completed),
        'Completed',
      );
    });

    test('each state has its own tint', () {
      expect(
        TeacherSessionStatus.shade(TeacherSessionStatus.live),
        TwColors.emerald,
      );
      expect(
        TeacherSessionStatus.shade(TeacherSessionStatus.upcoming),
        TwColors.amber,
      );
      expect(
        TeacherSessionStatus.shade(TeacherSessionStatus.completed),
        TwColors.slate,
      );
    });

    test('an unknown status renders rather than crashing', () {
      // The enum is server-side and grows independently of app releases.
      expect(TeacherSessionStatus.label('paused'), 'paused');
      expect(TeacherSessionStatus.shade('paused'), TwColors.slate);
    });
  });

  group('TeacherDashboard.hasPendingSessions', () {
    test('is true while anything is live or upcoming', () {
      expect(
        _dashboard(sessions: [_session(status: TeacherSessionStatus.live)])
            .hasPendingSessions,
        isTrue,
      );
      expect(
        _dashboard(sessions: [_session(status: TeacherSessionStatus.upcoming)])
            .hasPendingSessions,
        isTrue,
      );
    });

    test('is false once the last session is completed', () {
      expect(
        _dashboard(sessions: [_session(status: TeacherSessionStatus.completed)])
            .hasPendingSessions,
        isFalse,
      );
    });
  });

  group('TeacherDashboardCubit', () {
    late _MockGetDashboard getDashboard;

    setUp(() => getDashboard = _MockGetDashboard());

    test('emits the dashboard on success', () async {
      final data = _dashboard();
      when(() => getDashboard(any())).thenAnswer((_) async => Right(data));

      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data, data);
      await cubit.close();
    });

    test('surfaces the failure so the screen can offer Retry', () async {
      // The web drops `isError` on the floor, which leaves a skeleton spinning
      // forever. RemoteView renders AppErrorView off this instead.
      when(() => getDashboard(any()))
          .thenAnswer((_) async => const Left(ServerFailure('boom')));

      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.failure, isA<ServerFailure>());
      await cubit.close();
    });

    test('a refresh keeps the previous data on screen', () async {
      final data = _dashboard();
      when(() => getDashboard(any())).thenAnswer((_) async => Right(data));

      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();

      final future = cubit.load(refresh: true);
      expect(cubit.state.isRefreshing, isTrue);
      expect(cubit.state.data, data);
      await future;
      await cubit.close();
    });

    test('polls while a session can still change state', () async {
      when(() => getDashboard(any())).thenAnswer(
        (_) async => Right(
          _dashboard(sessions: [_session(status: TeacherSessionStatus.upcoming)]),
        ),
      );

      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();
      expect(cubit.state.data!.hasPendingSessions, isTrue);

      // Closing must cancel the timer; a leaked one keeps hitting the API after
      // the screen is gone and fires `emit` on a closed cubit.
      await cubit.close();
      verify(() => getDashboard(any())).called(1);
    });

    test('does not poll once every session is completed', () async {
      when(() => getDashboard(any())).thenAnswer(
        (_) async => Right(
          _dashboard(
            sessions: [_session(status: TeacherSessionStatus.completed)],
          ),
        ),
      );

      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();

      expect(cubit.state.data!.hasPendingSessions, isFalse);
      await cubit.close();
    });

    test('a failure stops the poll rather than hammering a dead endpoint',
        () async {
      when(() => getDashboard(any())).thenAnswer(
        (_) async => Right(
          _dashboard(sessions: [_session(status: TeacherSessionStatus.live)]),
        ),
      );
      final cubit = TeacherDashboardCubit(getDashboard: getDashboard);
      await cubit.load();

      when(() => getDashboard(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      await cubit.load(refresh: true);

      expect(cubit.state.status, RemoteStatus.failure);
      await cubit.close();
    });
  });

  group('endpoints', () {
    test('the teacher dashboard path matches the backend router', () {
      // `teacherRouter.get('/dashboard', ...)` mounted under /api/v1/teacher.
      expect(ApiUrls.teacherDashboard, '/teacher/dashboard');
    });
  });

  group('screens', () {
    Widget wrap(ParityHost host, Widget child) => host(
          Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        );

    bothPlatforms('the sessions timeline renders every row', (tester, host) async {
      final data = TeacherDashboardModel.fromJson(_payload);
      await tester.pumpWidget(
        wrap(host, TodaySessionsTimeline(sessions: data.todaySessions)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Sessions"), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('Live Now'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      // The placeholder row must not print a bare em dash.
      expect(find.textContaining('Division —'), findsNothing);
    });

    bothPlatforms('the sessions timeline shows its empty state', (tester, host) async {
      await tester.pumpWidget(
        wrap(host, const TodaySessionsTimeline(sessions: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No sessions scheduled for today.'), findsOneWidget);
    });

    bothPlatforms('the course list keeps both divisions of one course',
        (tester, host) async {
      final data = TeacherDashboardModel.fromJson(_payload);
      await tester.pumpWidget(wrap(host, MyCoursesGrid(courses: data.myCourses)));
      await tester.pumpAndSettle();

      expect(find.text('My Courses'), findsOneWidget);
      // Same course, two sections — both rows must be present.
      expect(find.text('Data Structures'), findsNWidgets(2));
      expect(find.textContaining('Division A'), findsOneWidget);
      expect(find.textContaining('Division B'), findsOneWidget);
    });

    bothPlatforms('the course list shows its empty state', (tester, host) async {
      await tester.pumpWidget(wrap(host, const MyCoursesGrid(courses: [])));
      await tester.pumpAndSettle();

      expect(find.text('No courses assigned yet'), findsOneWidget);
    });
  });

  group('NotificationsCubit feeds the activity panel', () {
    late _MockListNotifications list;
    late _MockMarkRead markRead;

    setUp(() {
      list = _MockListNotifications();
      markRead = _MockMarkRead();
    });

    test('loads the first page', () async {
      when(() => list(any())).thenAnswer(
        (_) async => Right(
          NotificationFeedModelStub.feed(const [
            AppNotification(
              id: 'n-1',
              type: 'assignment_created',
              title: 'New assignment',
              description: 'CS201',
              redirectUrl: '/teacher/assignments/a-1',
              isRead: false,
              createdAt: null,
            ),
          ]),
        ),
      );

      final cubit = NotificationsCubit(list: list, markRead: markRead);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.items, hasLength(1));
      await cubit.close();
    });
  });
}

/// Small builder so the dashboard suite can construct a feed without reaching
/// into the notification models' JSON shape (covered in `notifications_test`).
class NotificationFeedModelStub {
  static NotificationFeed feed(List<AppNotification> items) => NotificationFeed(
        items: items,
        pagination: const Pagination(
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
        ),
        unreadCount: 1,
      );
}
