import 'package:flutter/material.dart';

import 'nav_spec.dart';

/// The student navigation tree — a 1:1 port of `navGroups` in
/// `src/pages/student/components/sidebar.tsx`.
///
/// Four groups, nineteen destinations, in exactly the order the React sidebar
/// renders them. The web app shows this as a fixed left sidebar; on a phone it
/// lives in the drawer, but the grouping, ordering, labels, and routes are
/// unchanged.
///
/// The tree is declared as a [NavSpec] so the shell chrome — drawer, glass menu
/// sheet, app bar, bottom bar — is shared with the other role areas. The static
/// members below are thin delegates kept for the call sites that read them.
class StudentNav {
  const StudentNav._();

  static const spec = NavSpec(
    root: StudentRoutes.root,
    portalLabel: portalLabel,
    profilePath: StudentRoutes.profile,
    settingsPath: StudentRoutes.settings,
    // Reachable but deliberately absent from the sidebar (which mirrors the
    // web app's, and the web app has no profile row), so `activeFor` cannot
    // name it.
    offSidebarTitles: {StudentRoutes.profile: 'Profile'},
    groups: groups,
    bottomTabs: bottomTabs,
  );

  static const groups = <NavGroup>[
    NavGroup(
      label: 'Overview',
      items: [
        NavItem(
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          path: StudentRoutes.dashboard,
        ),
        NavItem(
          label: 'Analytics',
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          path: StudentRoutes.analytics,
        ),
        NavItem(
          label: 'Weekly Report',
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          path: StudentRoutes.weeklyReport,
        ),
      ],
    ),
    NavGroup(
      label: 'Learning',
      items: [
        NavItem(
          label: 'My Courses',
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          path: StudentRoutes.courses,
        ),
        NavItem(
          label: 'Quizzes',
          icon: Icons.checklist_outlined,
          activeIcon: Icons.checklist_rounded,
          path: StudentRoutes.quiz,
        ),
        NavItem(
          label: 'Assignments',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          path: StudentRoutes.assignments,
        ),
        NavItem(
          label: 'Questions',
          icon: Icons.extension_outlined,
          activeIcon: Icons.extension_rounded,
          path: StudentRoutes.practice,
        ),
        NavItem(
          label: 'Daily Challenge',
          icon: Icons.local_fire_department_outlined,
          activeIcon: Icons.local_fire_department_rounded,
          path: StudentRoutes.dailyChallenge,
        ),
        NavItem(
          label: 'Notes',
          icon: Icons.sticky_note_2_outlined,
          activeIcon: Icons.sticky_note_2_rounded,
          path: StudentRoutes.notes,
        ),
      ],
    ),
    NavGroup(
      label: 'Compete',
      items: [
        NavItem(
          label: 'Contests',
          icon: Icons.emoji_events_outlined,
          activeIcon: Icons.emoji_events_rounded,
          path: StudentRoutes.contests,
        ),
        NavItem(
          label: 'Rating',
          icon: Icons.trending_up_outlined,
          activeIcon: Icons.trending_up_rounded,
          path: StudentRoutes.rating,
        ),
        NavItem(
          label: 'Leaderboard',
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard_rounded,
          path: StudentRoutes.leaderboard,
        ),
        NavItem(
          label: 'Badges',
          icon: Icons.military_tech_outlined,
          activeIcon: Icons.military_tech_rounded,
          path: StudentRoutes.badges,
        ),
        NavItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          path: StudentRoutes.wallet,
        ),
      ],
    ),
    NavGroup(
      label: 'Campus',
      items: [
        NavItem(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          path: StudentRoutes.announcements,
          // `end: true` in React — the detail route must not light this row up.
          exact: true,
        ),
        NavItem(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          path: StudentRoutes.calendar,
        ),
        NavItem(
          label: 'Attendance',
          icon: Icons.event_available_outlined,
          activeIcon: Icons.event_available_rounded,
          path: StudentRoutes.attendance,
        ),
        NavItem(
          label: 'Academic Calendar',
          icon: Icons.date_range_outlined,
          activeIcon: Icons.date_range_rounded,
          path: StudentRoutes.academicCalendar,
        ),
        NavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          path: StudentRoutes.settings,
        ),
      ],
    ),
  ];

  /// Every destination, flattened — used by the router and for active matching.
  static List<NavItem> get allItems => spec.allItems;

  /// The route-backed shortcuts on the bottom bar. The slot after these is
  /// **Menu**, which opens the drawer (or the glass sheet on iOS) holding all
  /// nineteen destinations rather than navigating.
  ///
  /// Profile is here as well as being reachable from the header avatar — it is a
  /// destination people return to often enough to deserve a tab, even though it is
  /// deliberately absent from [groups] (the sidebar mirrors the web app's, which
  /// has no profile row).
  static const bottomTabs = <NavItem>[
    NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      path: StudentRoutes.dashboard,
    ),
    NavItem(
      label: 'Courses',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      path: StudentRoutes.courses,
    ),
    NavItem(
      label: 'Practice',
      icon: Icons.extension_outlined,
      activeIcon: Icons.extension_rounded,
      path: StudentRoutes.practice,
    ),
    NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      path: StudentRoutes.profile,
    ),
  ];

  /// Index of the Menu slot — the one that opens the drawer.
  static int get menuTabIndex => spec.menuTabIndex;

  /// Which bottom tab [location] belongs to.
  static int bottomIndexFor(String location) => spec.bottomIndexFor(location);

  /// The app's own name, used as the header's secondary line — and as the title
  /// of last resort when a route cannot be named.
  static const portalLabel = 'Student Portal';

  /// The header title for [location].
  static String titleFor(String location) => spec.titleFor(location);

  /// The nav row that owns [location], or null when the route isn't in the
  /// sidebar (a drill-down such as a course or contest detail).
  static NavItem? activeFor(String location) => spec.activeFor(location);
}

/// Every student route path, mirroring `src/routes/index.tsx` L153–245.
class StudentRoutes {
  const StudentRoutes._();

  static const root = '/student';

  // Overview
  static const dashboard = '/student/dashboard';
  static const analytics = '/student/analytics';
  static const weeklyReport = '/student/weekly-report';

  // Learning
  static const courses = '/student/courses';
  static String course(String id) => '/student/courses/$id';
  static const quiz = '/student/quiz';
  static String quizDetail(String id) => '/student/quiz/$id';
  static const assignments = '/student/assignments';
  static String assignmentDetail(String id) => '/student/assignments/$id';
  static const practice = '/student/practice';
  static String practiceQuestion(String id) => '/student/practice/$id';
  static const dailyChallenge = '/student/daily-challenge';
  static String dailyChallengeDate(String date) => '/student/daily-challenge/$date';
  static const notes = '/student/notes';
  static String note(String id) => '/student/notes/$id';

  // Compete
  static const contests = '/student/contests';
  static String contest(String id) => '/student/contests/$id';
  static String contestArena(String id) => '/student/contests/$id/arena';
  static String contestStandings(String id) => '/student/contests/$id/standings';
  static String contestSubmissions(String id) => '/student/contests/$id/submissions';
  static const rating = '/student/rating';
  static const leaderboard = '/student/leaderboard';
  static const badges = '/student/badges';
  static const wallet = '/student/wallet';

  // Campus
  static const announcements = '/student/announcements';
  static String announcement(String id) => '/student/announcements/$id';
  static const calendar = '/student/calendar';
  static const attendance = '/student/attendance';
  static const academicCalendar = '/student/academic-calendar';
  static const settings = '/student/settings';

  /// The account screen, reached from the app bar's avatar rather than from the
  /// sidebar — which is why it is not one of [StudentNav.groups]' nineteen
  /// destinations.
  static const profile = '/student/profile';

  /// Open-source attribution, reached from Settings. A drill-down, so it covers the
  /// shell chrome rather than rendering beneath it.
  static const licenses = '/student/settings/licenses';
}
