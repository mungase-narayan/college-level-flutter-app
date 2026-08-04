import 'package:flutter/material.dart';

/// The student navigation tree — a 1:1 port of `navGroups` in
/// `src/pages/student/components/sidebar.tsx`.
///
/// Four groups, nineteen destinations, in exactly the order the React sidebar
/// renders them. The web app shows this as a fixed left sidebar; on a phone it
/// lives in the drawer, but the grouping, ordering, labels, and routes are
/// unchanged.
class StudentNav {
  const StudentNav._();

  static const groups = <StudentNavGroup>[
    StudentNavGroup(
      label: 'Overview',
      items: [
        StudentNavItem(
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          path: StudentRoutes.dashboard,
        ),
        StudentNavItem(
          label: 'Analytics',
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          path: StudentRoutes.analytics,
        ),
        StudentNavItem(
          label: 'Weekly Report',
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          path: StudentRoutes.weeklyReport,
        ),
      ],
    ),
    StudentNavGroup(
      label: 'Learning',
      items: [
        StudentNavItem(
          label: 'My Courses',
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          path: StudentRoutes.courses,
        ),
        StudentNavItem(
          label: 'Quizzes',
          icon: Icons.checklist_outlined,
          activeIcon: Icons.checklist_rounded,
          path: StudentRoutes.quiz,
        ),
        StudentNavItem(
          label: 'Assignments',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          path: StudentRoutes.assignments,
        ),
        StudentNavItem(
          label: 'Questions',
          icon: Icons.extension_outlined,
          activeIcon: Icons.extension_rounded,
          path: StudentRoutes.practice,
        ),
        StudentNavItem(
          label: 'Daily Challenge',
          icon: Icons.local_fire_department_outlined,
          activeIcon: Icons.local_fire_department_rounded,
          path: StudentRoutes.dailyChallenge,
        ),
        StudentNavItem(
          label: 'Notes',
          icon: Icons.sticky_note_2_outlined,
          activeIcon: Icons.sticky_note_2_rounded,
          path: StudentRoutes.notes,
        ),
      ],
    ),
    StudentNavGroup(
      label: 'Compete',
      items: [
        StudentNavItem(
          label: 'Contests',
          icon: Icons.emoji_events_outlined,
          activeIcon: Icons.emoji_events_rounded,
          path: StudentRoutes.contests,
        ),
        StudentNavItem(
          label: 'Rating',
          icon: Icons.trending_up_outlined,
          activeIcon: Icons.trending_up_rounded,
          path: StudentRoutes.rating,
        ),
        StudentNavItem(
          label: 'Leaderboard',
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard_rounded,
          path: StudentRoutes.leaderboard,
        ),
        StudentNavItem(
          label: 'Badges',
          icon: Icons.military_tech_outlined,
          activeIcon: Icons.military_tech_rounded,
          path: StudentRoutes.badges,
        ),
        StudentNavItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          path: StudentRoutes.wallet,
        ),
      ],
    ),
    StudentNavGroup(
      label: 'Campus',
      items: [
        StudentNavItem(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          path: StudentRoutes.announcements,
          // `end: true` in React — the detail route must not light this row up.
          exact: true,
        ),
        StudentNavItem(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          path: StudentRoutes.calendar,
        ),
        StudentNavItem(
          label: 'Attendance',
          icon: Icons.event_available_outlined,
          activeIcon: Icons.event_available_rounded,
          path: StudentRoutes.attendance,
        ),
        StudentNavItem(
          label: 'Academic Calendar',
          icon: Icons.date_range_outlined,
          activeIcon: Icons.date_range_rounded,
          path: StudentRoutes.academicCalendar,
        ),
        StudentNavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          path: StudentRoutes.settings,
        ),
      ],
    ),
  ];

  /// Every destination, flattened — used by the router and for active matching.
  static List<StudentNavItem> get allItems =>
      [for (final group in groups) ...group.items];

  /// The route-backed shortcuts on the bottom bar. The slot after these is
  /// **Menu**, which opens the drawer (or the glass sheet on iOS) holding all
  /// nineteen destinations rather than navigating.
  ///
  /// Profile is here as well as being reachable from the header avatar — it is a
  /// destination people return to often enough to deserve a tab, even though it is
  /// deliberately absent from [groups] (the sidebar mirrors the web app's, which
  /// has no profile row).
  static const bottomTabs = <StudentNavItem>[
    StudentNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      path: StudentRoutes.dashboard,
    ),
    StudentNavItem(
      label: 'Courses',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      path: StudentRoutes.courses,
    ),
    StudentNavItem(
      label: 'Practice',
      icon: Icons.extension_outlined,
      activeIcon: Icons.extension_rounded,
      path: StudentRoutes.practice,
    ),
    StudentNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      path: StudentRoutes.profile,
    ),
  ];

  /// Index of the Menu slot — the one that opens the drawer.
  ///
  /// Derived rather than hardcoded: it sat at a literal `3` and would have
  /// silently pointed at Profile the moment a tab was added.
  static int get menuTabIndex => bottomTabs.length;

  /// Which bottom tab [location] belongs to.
  ///
  /// Anything reached from the drawer rather than a shortcut (Notes, Wallet,
  /// Settings…) selects **Menu**, since that is how the user got there — a
  /// `NavigationBar` has to point at some destination, and leaving Home lit
  /// while the user reads Settings would be a lie.
  static int bottomIndexFor(String location) {
    for (var i = 0; i < bottomTabs.length; i++) {
      final path = bottomTabs[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return menuTabIndex;
  }

  /// The app's own name, used as the header's secondary line — and as the title
  /// of last resort when a route cannot be named.
  static const portalLabel = 'Student Portal';

  /// Titles for routes that are reachable but deliberately absent from the
  /// sidebar, so [activeFor] cannot name them.
  static const _offSidebarTitles = <String, String>{
    StudentRoutes.profile: 'Profile',
  };

  /// The header title for [location].
  ///
  /// Falls back to [portalLabel] only when a route is genuinely unnameable —
  /// which is also why the header suppresses its subtitle in that case, rather
  /// than rendering "Student Portal" twice.
  static String titleFor(String location) =>
      activeFor(location)?.label ??
      _offSidebarTitles[location] ??
      portalLabel;

  /// The nav row that owns [location], or null when the route isn't in the
  /// sidebar (a drill-down such as a course or contest detail).
  ///
  /// Longest match wins so `/student/courses/:id` still highlights My Courses,
  /// while an `exact` item only matches its own path.
  static StudentNavItem? activeFor(String location) {
    StudentNavItem? best;
    for (final item in allItems) {
      final matches = item.exact
          ? location == item.path
          : location == item.path || location.startsWith('${item.path}/');
      if (matches && (best == null || item.path.length > best.path.length)) {
        best = item;
      }
    }
    return best;
  }
}

class StudentNavGroup {
  const StudentNavGroup({required this.label, required this.items});

  final String label;
  final List<StudentNavItem> items;
}

class StudentNavItem {
  const StudentNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
    this.exact = false,
  });

  final String label;
  final IconData icon;

  /// Filled variant, shown while the row is active — the closest Material
  /// equivalent of the React animated-icon hover treatment.
  final IconData activeIcon;
  final String path;

  /// Match this route exactly, ignoring children.
  final bool exact;
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
