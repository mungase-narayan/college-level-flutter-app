import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/usecases/accept_invitation_usecase.dart';
import '../../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../features/auth/presentation/pages/role_placeholder_page.dart';
import '../../../features/assessments/presentation/bloc/assessment_detail_cubit.dart';
import '../../../features/assessments/presentation/pages/assessment_detail_page.dart';
import '../../../features/auth/presentation/pages/set_password_page.dart';
import '../../../features/courses/presentation/bloc/courses_cubit.dart';
import '../../../features/courses/presentation/pages/course_detail_page.dart';
import '../../../features/courses/presentation/pages/courses_page.dart';
import '../../../features/dashboard/presentation/bloc/dashboard_cubit.dart';
import '../../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../../features/practice/presentation/bloc/practice_list_cubit.dart';
import '../../../features/practice/presentation/pages/practice_page.dart';
import '../../../features/profile/presentation/pages/profile_page.dart';
import '../../../features/settings/presentation/pages/licenses_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/shell/presentation/pages/student_shell.dart';
import '../../../features/shell/presentation/widgets/student_nav.dart';
import '../../common/pages/feature_pending_page.dart';
import '../../common/pages/not_found_page.dart';
import '../../common/pages/splash_page.dart';
import '../../constants/user_constants.dart';
import '../injection_modules/service_locator.dart';

/// Non-student route paths. Student paths live in [StudentRoutes], next to the
/// sidebar definition they mirror.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const login = '/auth/login';
  static const setPassword = '/invite/set-password';
}

/// Builds the app router.
///
/// Guarding lives in [GoRouter.redirect] and — matching the React area layouts
/// — checks the **roles array**, not the active role, so a multi-role user can
/// reach any of their own areas.
GoRouter createRouter(AuthBloc authBloc) {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: _BlocRefresh(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final location = state.matchedLocation;

      final isSplash = location == Routes.splash;
      final isPublic = location == Routes.login ||
          location.startsWith(Routes.setPassword) ||
          location.startsWith('/@');

      // Storage hasn't been read yet — hold everything on the splash screen.
      if (auth.status == AuthStatus.unknown) {
        return isSplash ? null : Routes.splash;
      }

      if (!auth.isAuthenticated) {
        return isPublic ? null : Routes.login;
      }

      // Signed in: bounce off the splash and the login screen to the role home.
      if (isSplash || location == Routes.login) return auth.homePath;

      // A student area demands the student role — the same check the React
      // `StudentLayout` performs before rendering.
      if (location.startsWith(StudentRoutes.root) &&
          !auth.hasRole(UserRole.student)) {
        return auth.homePath;
      }

      return null;
    },
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: Routes.setPassword,
        builder: (context, state) => SetPasswordPage(
          acceptInvitation: sl<AcceptInvitationUseCase>(),
          token: state.uri.queryParameters['token'],
        ),
      ),

      // ── Student ───────────────────────────────────────────────────────────
      // One shell over all nineteen sidebar destinations. Drill-downs (course,
      // contest, note details) render on the root navigator so they cover the
      // chrome, exactly as a drill-down should.
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => StudentShell(
          recordDailyVisit: sl(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: StudentRoutes.root,
            redirect: (_, _) => StudentRoutes.dashboard,
          ),

          // ── Overview ──────────────────────────────────────────────────────
          GoRoute(
            path: StudentRoutes.dashboard,
            builder: (_, _) => BlocProvider(
              create: (_) => DashboardCubit(
                getDailyChallenge: sl(),
                getSummary: sl(),
                getAnalytics: sl(),
                getOverview: sl(),
                getSemester: sl(),
                getRating: sl(),
                getLeaderboard: sl(),
                getBadges: sl(),
              ),
              child: const DashboardPage(),
            ),
          ),
          _pending(StudentRoutes.analytics, 'Analytics', Icons.bar_chart_rounded),
          _pending(
            StudentRoutes.weeklyReport,
            'Weekly Report',
            Icons.auto_awesome_rounded,
          ),

          // ── Learning ──────────────────────────────────────────────────────
          GoRoute(
            path: StudentRoutes.courses,
            builder: (_, _) => BlocProvider(
              create: (_) => CoursesCubit(sl()),
              child: const CoursesPage(),
            ),
          ),
          _pending(StudentRoutes.quiz, 'Quizzes', Icons.checklist_rounded),
          _pending(
            StudentRoutes.assignments,
            'Assignments',
            Icons.assignment_rounded,
          ),
          GoRoute(
            path: StudentRoutes.practice,
            builder: (_, _) => BlocProvider(
              create: (_) => PracticeListCubit(
                listQuestions: sl(),
                setBookmarked: sl(),
              ),
              child: const PracticePage(),
            ),
          ),
          _pending(
            StudentRoutes.dailyChallenge,
            'Daily Challenge',
            Icons.local_fire_department_rounded,
          ),
          _pending(StudentRoutes.notes, 'Notes', Icons.sticky_note_2_rounded),

          // ── Compete ───────────────────────────────────────────────────────
          _pending(StudentRoutes.contests, 'Contests', Icons.emoji_events_rounded),
          _pending(StudentRoutes.rating, 'Rating', Icons.trending_up_rounded),
          _pending(
            StudentRoutes.leaderboard,
            'Leaderboard',
            Icons.leaderboard_rounded,
          ),
          _pending(StudentRoutes.badges, 'Badges', Icons.military_tech_rounded),
          _pending(
            StudentRoutes.wallet,
            'Wallet',
            Icons.account_balance_wallet_rounded,
          ),

          // ── Campus ────────────────────────────────────────────────────────
          _pending(
            StudentRoutes.announcements,
            'Announcements',
            Icons.campaign_rounded,
          ),
          _pending(StudentRoutes.calendar, 'Calendar', Icons.calendar_month_rounded),
          _pending(
            StudentRoutes.attendance,
            'Attendance',
            Icons.event_available_rounded,
          ),
          _pending(
            StudentRoutes.academicCalendar,
            'Academic Calendar',
            Icons.date_range_rounded,
          ),
          GoRoute(
            path: StudentRoutes.settings,
            builder: (_, _) => const SettingsPage(),
          ),

          // Reached from the app bar avatar and the menu sheet rather than from
          // the sidebar, so it is not one of the nineteen sidebar destinations.
          GoRoute(
            path: StudentRoutes.profile,
            builder: (_, _) => const ProfilePage(),
          ),
        ],
      ),

      // Student drill-downs — full-screen, above the shell chrome.
      // Assignments and quizzes share one screen; only the copy differs.
      GoRoute(
        path: '${StudentRoutes.assignments}/:assessmentId',
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            _assessmentDetail(state.pathParameters['assessmentId']!, 'Assignment'),
      ),
      GoRoute(
        path: '${StudentRoutes.quiz}/:assessmentId',
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            _assessmentDetail(state.pathParameters['assessmentId']!, 'Quiz'),
      ),
      // Full-screen above the shell: it is a long read, and the floating capsule
      // would otherwise sit on top of the licence text.
      GoRoute(
        path: StudentRoutes.licenses,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const LicensesPage(),
      ),
      GoRoute(
        path: '${StudentRoutes.courses}/:courseId',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return BlocProvider(
            create: (_) => CourseTreeCubit(
              getTree: sl(),
              setCompleted: sl(),
              courseId: courseId,
            ),
            child: CourseDetailPage(courseId: courseId),
          );
        },
      ),

      // ── Other roles ───────────────────────────────────────────────────────
      // These land correctly and can switch roles or log out; their feature
      // sets are later passes.
      GoRoute(
        path: '/teacher/dashboard',
        builder: (_, _) => const RolePlaceholderPage(role: UserRole.teacher),
      ),
      GoRoute(
        path: '/school-admin/dashboard',
        builder: (_, _) => const RolePlaceholderPage(role: UserRole.schoolAdmin),
      ),
      GoRoute(
        path: '/super-admin/school',
        builder: (_, _) => const RolePlaceholderPage(role: UserRole.superAdmin),
      ),
      GoRoute(
        path: '/accountant/dashboard',
        builder: (_, _) => const RolePlaceholderPage(role: UserRole.accountant),
      ),
    ],
  );
}

/// The assignment/quiz detail screen, with its own cubit.
Widget _assessmentDetail(String assessmentId, String kind) => BlocProvider(
      create: (_) => AssessmentDetailCubit(
        getDetail: sl(),
        startAttempt: sl(),
        saveAttempt: sl(),
        submitAttempt: sl(),
        assessmentId: assessmentId,
      ),
      child: AssessmentDetailPage(kind: kind),
    );

/// A sidebar destination that is routed and guarded but whose screen is still
/// being built. Each is replaced as its tab lands.
GoRoute _pending(String path, String title, IconData icon) => GoRoute(
      path: path,
      builder: (_, _) => FeaturePendingPage(
        title: title,
        showAppBar: false,
        icon: icon,
        description: '$title is routed and reachable; its screen is next up '
            'in the tab-by-tab build.',
      ),
    );

/// Bridges a bloc's stream to [Listenable] so GoRouter re-evaluates `redirect`
/// whenever the auth state changes.
class _BlocRefresh extends ChangeNotifier {
  _BlocRefresh(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
