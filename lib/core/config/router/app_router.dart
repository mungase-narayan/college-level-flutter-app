import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/usecases/accept_invitation_usecase.dart';
import '../../../features/auth/domain/usecases/password_reset_usecases.dart';
import '../../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../features/auth/presentation/pages/role_placeholder_page.dart';
import '../../../features/assessments/presentation/bloc/assessment_detail_cubit.dart';
import '../../../features/assessments/presentation/bloc/assignments_cubit.dart';
import '../../../features/assessments/presentation/bloc/quizzes_cubit.dart';
import '../../../features/assessments/presentation/pages/assessment_detail_page.dart';
import '../../../features/calendar/presentation/bloc/calendar_cubit.dart';
import '../../../features/calendar/presentation/bloc/today_sessions_cubit.dart';
import '../../../features/calendar/presentation/pages/calendar_page.dart';
import '../../../features/assessments/presentation/pages/assignments_page.dart';
import '../../../features/assessments/presentation/pages/quizzes_page.dart';
import '../../../features/academic_calendar/presentation/bloc/academic_calendar_cubit.dart';
import '../../../features/academic_calendar/presentation/pages/academic_calendar_page.dart';
import '../../../features/announcements/presentation/bloc/announcement_detail_cubit.dart';
import '../../../features/announcements/presentation/bloc/announcements_cubit.dart';
import '../../../features/announcements/presentation/pages/announcement_detail_page.dart';
import '../../../features/announcements/presentation/pages/announcements_page.dart';
import '../../../features/attendance/presentation/bloc/attendance_overview_cubit.dart';
import '../../../features/attendance/presentation/bloc/attendance_sessions_cubit.dart';
import '../../../features/attendance/presentation/pages/attendance_page.dart';
import '../../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../../features/auth/presentation/pages/reset_password_page.dart';
import '../../../features/auth/presentation/pages/set_password_page.dart';
import '../../../features/courses/presentation/bloc/courses_cubit.dart';
import '../../../features/courses/presentation/pages/course_detail_page.dart';
import '../../../features/courses/presentation/pages/courses_page.dart';
import '../../../features/dashboard/presentation/bloc/dashboard_cubit.dart';
import '../../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../../features/discussions/presentation/bloc/discussion_cubit.dart';
import '../../../features/notes/domain/entities/note.dart';
import '../../../features/notes/presentation/bloc/material_notes_cubit.dart';
import '../../../features/notes/presentation/bloc/my_notes_stats_cubit.dart';
import '../../../features/notes/presentation/bloc/note_detail_cubit.dart';
import '../../../features/notes/presentation/bloc/notes_hub_cubit.dart';
import '../../../features/notes/presentation/pages/note_detail_page.dart';
import '../../../features/notes/presentation/pages/notes_page.dart';
import '../../../features/practice/presentation/bloc/daily_challenge_cubit.dart';
import '../../../features/practice/presentation/bloc/daily_solve_cubit.dart';
import '../../../features/practice/presentation/bloc/practice_list_cubit.dart';
import '../../../features/practice/presentation/bloc/practice_question_cubit.dart';
import '../../../features/practice/presentation/pages/daily_challenge_page.dart';
import '../../../features/practice/presentation/pages/daily_solve_page.dart';
import '../../../features/practice/presentation/pages/practice_question_page.dart';
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
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

  /// The reset screen with the address already filled in, so the student does
  /// not retype the email they just entered.
  static String resetPasswordFor(String email) =>
      '$resetPassword?email=${Uri.encodeQueryComponent(email)}';
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
          location.startsWith(Routes.forgotPassword) ||
          location.startsWith(Routes.resetPassword) ||
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
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => ForgotPasswordPage(
          requestPasswordReset: sl<RequestPasswordResetUseCase>(),
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) => ResetPasswordPage(
          resetPassword: sl<ResetPasswordUseCase>(),
          requestPasswordReset: sl<RequestPasswordResetUseCase>(),
          email: state.uri.queryParameters['email'],
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
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(
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
                ),
                // Today's sessions reads the calendar, so it is its own cubit —
                // a failure there must not take the dashboard down with it.
                BlocProvider(
                  create: (_) => TodaySessionsCubit(getCalendar: sl()),
                ),
              ],
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
          GoRoute(
            path: StudentRoutes.quiz,
            builder: (_, _) => BlocProvider(
              create: (_) => QuizzesCubit(listAll: sl(), listCourses: sl()),
              child: const QuizzesPage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.assignments,
            builder: (_, _) => BlocProvider(
              create: (_) => AssignmentsCubit(listAll: sl(), listCourses: sl()),
              child: const AssignmentsPage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.practice,
            builder: (_, _) => BlocProvider(
              create: (_) => PracticeListCubit(
                listQuestions: sl(),
                setBookmarked: sl(),
                getFilters: sl(),
              ),
              child: const PracticePage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.dailyChallenge,
            builder: (_, _) => BlocProvider(
              create: (_) => DailyChallengeCubit(
                getToday: sl(),
                getCalendar: sl(),
                getHistory: sl(),
              ),
              child: const DailyChallengePage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.notes,
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => NotesHubCubit(
                    list: sl(),
                    create: sl(),
                    toggleLikeUseCase: sl(),
                    deleteUseCase: sl(),
                  ),
                ),
                // Its own endpoint, so a failing stats call cannot blank the
                // feed beside it.
                BlocProvider(
                  create: (_) => MyNotesStatsCubit(getStats: sl()),
                ),
              ],
              child: const NotesPage(),
            ),
          ),

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
          GoRoute(
            path: StudentRoutes.announcements,
            builder: (_, _) => BlocProvider(
              create: (_) => AnnouncementsCubit(listAnnouncements: sl()),
              child: const AnnouncementsPage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.calendar,
            builder: (_, state) => BlocProvider(
              // `?date=YYYY-MM-DD` anchors the calendar on a given day — what a
              // tapped session on the dashboard opens.
              create: (_) => CalendarCubit(
                getCalendar: sl(),
                today: DateTime.tryParse(
                  state.uri.queryParameters['date'] ?? '',
                ),
              ),
              child: const CalendarPage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.attendance,
            builder: (_, _) => MultiBlocProvider(
              providers: [
                // Two cubits, two endpoints: the analytics aggregate has nothing
                // to re-fetch when a filter changes, and a failure in either
                // must not blank the other half of the screen.
                BlocProvider(
                  create: (_) => AttendanceOverviewCubit(getOverall: sl()),
                ),
                BlocProvider(
                  create: (_) => AttendanceSessionsCubit(listSessions: sl()),
                ),
              ],
              child: const AttendancePage(),
            ),
          ),
          GoRoute(
            path: StudentRoutes.academicCalendar,
            builder: (_, _) => BlocProvider(
              create: (_) => AcademicCalendarCubit(getMyCalendar: sl()),
              child: const AcademicCalendarPage(),
            ),
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
      // One day's challenge — full-screen for the same reason the practice
      // workspace is.
      GoRoute(
        path: '${StudentRoutes.dailyChallenge}/:date',
        parentNavigatorKey: rootKey,
        builder: (context, state) => BlocProvider(
          create: (_) => DailySolveCubit(
            getByDate: sl(),
            getAttempts: sl(),
            submitAnswer: sl(),
            runCode: sl(),
            runCustom: sl(),
            useTicket: sl(),
            date: state.pathParameters['date']!,
          ),
          child: const DailySolvePage(),
        ),
      ),

      // The solve workspace: full-screen so the editor and the test-case output
      // get the whole display, and so the floating capsule cannot sit on top of
      // the Submit button.
      GoRoute(
        path: '${StudentRoutes.practice}/:questionId',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final questionId = state.pathParameters['questionId']!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => PracticeQuestionCubit(
                  getQuestion: sl(),
                  getAttempts: sl(),
                  submitAnswer: sl(),
                  runCode: sl(),
                  runCustom: sl(),
                  navigate: sl(),
                  setBookmarked: sl(),
                  questionId: questionId,
                ),
              ),
              BlocProvider(
                create: (_) => DiscussionCubit(
                  list: sl(),
                  post: sl(),
                  edit: sl(),
                  remove: sl(),
                  react: sl(),
                  questionId: questionId,
                ),
              ),
              // The Notes tab is scoped by the link this cubit carries.
              BlocProvider(
                create: (_) => MaterialNotesCubit(
                  list: sl(),
                  create: sl(),
                  link: NoteLinkContext(questionId: questionId),
                ),
              ),
            ],
            child: const PracticeQuestionPage(),
          );
        },
      ),

      // Full-screen above the shell: it is a long read, and the floating capsule
      // would otherwise sit on top of the licence text.
      GoRoute(
        path: StudentRoutes.licenses,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const LicensesPage(),
      ),
      // Above the shell so it covers the nav capsule, and because the nav row
      // is declared `exact` the detail must not light Announcements up.
      GoRoute(
        path: '${StudentRoutes.notes}/:noteId',
        parentNavigatorKey: rootKey,
        builder: (context, state) => BlocProvider(
          create: (_) => NoteDetailCubit(
            noteId: state.pathParameters['noteId']!,
            getNote: sl(),
            updateUseCase: sl(),
            deleteUseCase: sl(),
            toggleLikeUseCase: sl(),
          ),
          child: const NoteDetailPage(),
        ),
      ),
      GoRoute(
        path: '${StudentRoutes.announcements}/:announcementId',
        parentNavigatorKey: rootKey,
        builder: (context, state) => BlocProvider(
          create: (_) => AnnouncementDetailCubit(
            announcementId: state.pathParameters['announcementId']!,
            getAnnouncement: sl(),
            registerFor: sl(),
            cancelRegistrationFor: sl(),
          ),
          child: const AnnouncementDetailPage(),
        ),
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
