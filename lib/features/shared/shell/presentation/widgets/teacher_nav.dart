import 'package:flutter/material.dart';

import 'nav_spec.dart';

/// The teacher navigation tree — a 1:1 port of `navGroups` in
/// `src/pages/teacher/components/sidebar.tsx`.
///
/// Four groups, twelve destinations, in exactly the order the React sidebar
/// renders them. `teacher`, `class_teacher` and `hod` all share this one area —
/// the web app draws no distinction between them, and neither does this.
class TeacherNav {
  const TeacherNav._();

  static const spec = NavSpec(
    root: TeacherRoutes.root,
    portalLabel: portalLabel,
    profilePath: TeacherRoutes.profile,
    settingsPath: TeacherRoutes.settings,
    // Reachable from the app bar avatar and the menu sheet, but absent from the
    // sidebar (which mirrors the web app's), so `activeFor` cannot name it.
    offSidebarTitles: {TeacherRoutes.profile: 'Profile'},
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
          path: TeacherRoutes.dashboard,
        ),
      ],
    ),
    NavGroup(
      label: 'Teaching',
      items: [
        NavItem(
          label: 'My Courses',
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          path: TeacherRoutes.courses,
        ),
        NavItem(
          label: 'Quizzes',
          icon: Icons.checklist_outlined,
          activeIcon: Icons.checklist_rounded,
          path: TeacherRoutes.quizzes,
        ),
        NavItem(
          label: 'Assignments',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          path: TeacherRoutes.assignments,
        ),
        NavItem(
          label: 'Attendance',
          icon: Icons.event_available_outlined,
          activeIcon: Icons.event_available_rounded,
          path: TeacherRoutes.attendance,
        ),
      ],
    ),
    NavGroup(
      label: 'Academics',
      items: [
        NavItem(
          label: 'Question Bank',
          icon: Icons.quiz_outlined,
          activeIcon: Icons.quiz_rounded,
          path: TeacherRoutes.questionBank,
        ),
        NavItem(
          label: 'Practice Review',
          icon: Icons.rate_review_outlined,
          activeIcon: Icons.rate_review_rounded,
          path: TeacherRoutes.practiceReview,
        ),
        NavItem(
          label: 'Notes',
          icon: Icons.sticky_note_2_outlined,
          activeIcon: Icons.sticky_note_2_rounded,
          path: TeacherRoutes.notes,
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
          path: TeacherRoutes.announcements,
          // The detail route must not light this row up — `end: true` in React.
          exact: true,
        ),
        NavItem(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          path: TeacherRoutes.calendar,
        ),
        NavItem(
          label: 'Academic Calendar',
          icon: Icons.date_range_outlined,
          activeIcon: Icons.date_range_rounded,
          path: TeacherRoutes.academicCalendar,
        ),
        NavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          path: TeacherRoutes.settings,
        ),
      ],
    ),
  ];

  /// Every destination, flattened.
  static List<NavItem> get allItems => spec.allItems;

  /// The bottom-bar shortcuts. The slot after these is **Menu**, which opens the
  /// drawer (or the glass sheet on iOS) holding all twelve destinations.
  ///
  /// Attendance takes the third slot rather than Quizzes or Assignments: it is
  /// the one destination a teacher opens on a fixed schedule, every session.
  static const bottomTabs = <NavItem>[
    NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      path: TeacherRoutes.dashboard,
    ),
    NavItem(
      label: 'Courses',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      path: TeacherRoutes.courses,
    ),
    NavItem(
      label: 'Attendance',
      icon: Icons.event_available_outlined,
      activeIcon: Icons.event_available_rounded,
      path: TeacherRoutes.attendance,
    ),
    NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      path: TeacherRoutes.profile,
    ),
  ];

  /// Index of the Menu slot — the one that opens the drawer.
  static int get menuTabIndex => spec.menuTabIndex;

  /// Which bottom tab [location] belongs to.
  static int bottomIndexFor(String location) => spec.bottomIndexFor(location);

  static const portalLabel = 'Teacher Portal';

  /// The header title for [location].
  static String titleFor(String location) => spec.titleFor(location);

  /// The nav row that owns [location], or null for a drill-down.
  static NavItem? activeFor(String location) => spec.activeFor(location);
}

/// Every teacher route path, mirroring `src/routes/index.tsx` L249–355.
class TeacherRoutes {
  const TeacherRoutes._();

  static const root = '/teacher';

  // Overview
  static const dashboard = '/teacher/dashboard';

  // Teaching
  static const courses = '/teacher/courses';
  static String course(String id) => '/teacher/courses/$id';
  static const quizzes = '/teacher/quizzes';
  static String quizResults(String id) => '/teacher/quizzes/$id';
  static const assignments = '/teacher/assignments';
  static String assignmentResults(String id) => '/teacher/assignments/$id';
  static const attendance = '/teacher/attendance';
  static String attendanceSession(String id) => '/teacher/attendance/$id';

  // Academics
  static const questionBank = '/teacher/question-bank';
  static const createQuestion = '/teacher/question-bank/create';
  static String question(String id) => '/teacher/question-bank/$id';
  static const practiceReview = '/teacher/practice-review';
  static const notes = '/teacher/notes';
  static String note(String id) => '/teacher/notes/$id';

  // Campus
  static const announcements = '/teacher/announcements';
  static String announcement(String id) => '/teacher/announcements/$id';
  static const calendar = '/teacher/calendar';
  static const academicCalendar = '/teacher/academic-calendar';
  static const settings = '/teacher/settings';

  /// The account screen, reached from the app bar's avatar rather than from the
  /// sidebar — which is why it is not one of [TeacherNav.groups]' twelve
  /// destinations.
  static const profile = '/teacher/profile';
}
