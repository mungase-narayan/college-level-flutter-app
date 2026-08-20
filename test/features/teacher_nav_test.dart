import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/config/router/app_router.dart';
import 'package:college_level/features/shared/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:college_level/features/shared/shell/presentation/widgets/nav_spec.dart';
import 'package:college_level/features/shared/shell/presentation/widgets/student_nav.dart';
import 'package:college_level/features/shared/shell/presentation/widgets/teacher_nav.dart';

/// The drawer is a 1:1 port of the React teacher sidebar, so its shape is part
/// of the contract, not an implementation detail. Mirror of
/// `student_nav_test.dart`.
void main() {
  group('TeacherNav structure', () {
    test('has the four groups in sidebar order', () {
      expect(
        TeacherNav.groups.map((g) => g.label),
        ['Overview', 'Teaching', 'Academics', 'Campus'],
      );
    });

    test('has all twelve destinations', () {
      expect(TeacherNav.allItems, hasLength(12));
    });

    test('every route sits under /teacher and is unique', () {
      final paths = TeacherNav.allItems.map((i) => i.path).toList();
      expect(paths.every((p) => p.startsWith('/teacher/')), isTrue);
      expect(paths.toSet(), hasLength(paths.length));
    });

    test('groups match the React sidebar row for row', () {
      expect(TeacherNav.groups[0].items.map((i) => i.label), ['Dashboard']);
      expect(
        TeacherNav.groups[1].items.map((i) => i.label),
        ['My Courses', 'Quizzes', 'Assignments', 'Attendance'],
      );
      expect(
        TeacherNav.groups[2].items.map((i) => i.label),
        ['Question Bank', 'Practice Review', 'Notes'],
      );
      expect(
        TeacherNav.groups[3].items.map((i) => i.label),
        ['Announcements', 'Calendar', 'Academic Calendar', 'Settings'],
      );
    });

    test('the slugs match the paths the React router declares', () {
      // These three are hyphenated on the web; a mismatch here routes a teacher
      // to the 404 page rather than the tab.
      expect(TeacherRoutes.questionBank, '/teacher/question-bank');
      expect(TeacherRoutes.practiceReview, '/teacher/practice-review');
      expect(TeacherRoutes.academicCalendar, '/teacher/academic-calendar');
    });
  });

  group('TeacherNav.bottomIndexFor', () {
    test('exposes the route-backed shortcuts, then Menu', () {
      expect(
        TeacherNav.bottomTabs.map((t) => t.label),
        ['Home', 'Courses', 'Attendance', 'Profile'],
      );
      // Menu is the slot after the route-backed tabs and is not route-backed
      // itself. Derived, so adding a tab can never leave it pointing at one.
      expect(TeacherNav.menuTabIndex, TeacherNav.bottomTabs.length);
    });

    test('every shortcut points at a real teacher route', () {
      for (final tab in TeacherNav.bottomTabs) {
        expect(
          tab.path.startsWith(TeacherRoutes.root),
          isTrue,
          reason: '${tab.label} must be route-backed',
        );
      }
    });

    test('selects the matching shortcut', () {
      expect(TeacherNav.bottomIndexFor(TeacherRoutes.dashboard), 0);
      expect(TeacherNav.bottomIndexFor(TeacherRoutes.courses), 1);
      expect(TeacherNav.bottomIndexFor(TeacherRoutes.attendance), 2);
      // Profile is a tab as well as being reachable from the header avatar, so
      // it must light its own tab rather than falling through to Menu.
      expect(TeacherNav.bottomIndexFor(TeacherRoutes.profile), 3);
    });

    test('keeps the shortcut selected on its drill-downs', () {
      expect(TeacherNav.bottomIndexFor(TeacherRoutes.course('abc-123')), 1);
      expect(
        TeacherNav.bottomIndexFor(TeacherRoutes.attendanceSession('s-1')),
        2,
      );
    });

    test('falls back to Menu for drawer-only destinations', () {
      for (final path in [
        TeacherRoutes.quizzes,
        TeacherRoutes.assignments,
        TeacherRoutes.questionBank,
        TeacherRoutes.practiceReview,
        TeacherRoutes.notes,
        TeacherRoutes.settings,
      ]) {
        expect(
          TeacherNav.bottomIndexFor(path),
          TeacherNav.menuTabIndex,
          reason: '$path should light the Menu tab',
        );
      }
    });

    test('always returns an index the NavigationBar can render', () {
      // selectedIndex must stay within [0, destinations.length) or the bar
      // throws — including for routes that are not in the sidebar at all.
      final destinationCount = TeacherNav.bottomTabs.length + 1;
      for (final path in [...TeacherNav.allItems.map((i) => i.path), '/nope']) {
        final index = TeacherNav.bottomIndexFor(path);
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(destinationCount));
      }
    });
  });

  group('TeacherNav.activeFor', () {
    test('matches a destination exactly', () {
      expect(
        TeacherNav.activeFor(TeacherRoutes.questionBank)?.label,
        'Question Bank',
      );
    });

    test('keeps the parent row active on a drill-down', () {
      expect(
        TeacherNav.activeFor(TeacherRoutes.course('abc-123'))?.label,
        'My Courses',
      );
      expect(
        TeacherNav.activeFor('/teacher/courses/abc/assignments')?.label,
        'My Courses',
      );
    });

    test('an `exact` item ignores its children', () {
      // Announcements is `end: true` in React — the detail page must not light
      // the row up.
      expect(
        TeacherNav.activeFor(TeacherRoutes.announcements)?.label,
        'Announcements',
      );
      expect(TeacherNav.activeFor('/teacher/announcements/abc'), isNull);
    });

    test('prefers the longest match so sibling prefixes do not collide', () {
      // `/teacher/academic-calendar` must not be swallowed by `/teacher/calendar`
      // or vice versa — they are distinct destinations with a shared word.
      expect(
        TeacherNav.activeFor(TeacherRoutes.academicCalendar)?.label,
        'Academic Calendar',
      );
      expect(TeacherNav.activeFor(TeacherRoutes.calendar)?.label, 'Calendar');
    });

    test('returns null for a route outside the sidebar', () {
      expect(TeacherNav.activeFor('/auth/login'), isNull);
      expect(TeacherNav.activeFor('/student/dashboard'), isNull);
    });
  });

  group('TeacherNav.titleFor', () {
    test('names sidebar destinations from their nav row', () {
      expect(TeacherNav.titleFor(TeacherRoutes.dashboard), 'Dashboard');
      expect(TeacherNav.titleFor(TeacherRoutes.courses), 'My Courses');
      expect(TeacherNav.titleFor(TeacherRoutes.settings), 'Settings');
    });

    test('names off-sidebar destinations too', () {
      // Profile is reached from the header avatar, not the sidebar, so
      // `activeFor` cannot name it — without this the header would render
      // "Teacher Portal" on both of its lines.
      expect(TeacherNav.titleFor(TeacherRoutes.profile), 'Profile');
      expect(
        TeacherNav.titleFor(TeacherRoutes.profile),
        isNot(TeacherNav.portalLabel),
      );
    });

    test('falls back to the portal label only when truly unnameable', () {
      expect(
        TeacherNav.titleFor('/teacher/nothing-here'),
        TeacherNav.portalLabel,
      );
    });

    test('every nameable route differs from the subtitle it sits above', () {
      for (final item in TeacherNav.allItems) {
        expect(
          TeacherNav.titleFor(item.path),
          isNot(TeacherNav.portalLabel),
          reason: '${item.path} would render its title twice',
        );
      }
    });
  });

  group('the two areas stay disjoint', () {
    test('the teacher portal label is its own', () {
      expect(TeacherNav.portalLabel, 'Teacher Portal');
    });

    test('no teacher route leaks into the student area', () {
      for (final item in TeacherNav.allItems) {
        expect(item.path.startsWith('/student'), isFalse);
      }
    });

    test('the shared screens point at different routes per area', () {
      // ProfilePage and SettingsPage are reused across areas. If these two
      // specs agreed, one area would be linking into the other's routes — and
      // the router's role guard would bounce the user straight home.
      expect(
        TeacherNav.spec.settingsPath,
        isNot(StudentNav.spec.settingsPath),
      );
      expect(TeacherNav.spec.profilePath, isNot(StudentNav.spec.profilePath));
      expect(TeacherNav.spec.root, '/teacher');
      expect(StudentNav.spec.root, '/student');
    });
  });

  group('NavSpecScope', () {
    testWidgets('hands a shared screen the area it is rendering in',
        (tester) async {
      NavSpec? seen;

      await tester.pumpWidget(
        MaterialApp(
          home: NavSpecScope(
            spec: TeacherNav.spec,
            child: Builder(
              builder: (context) {
                seen = NavSpecScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // This is what stops the account screen's Settings row from sending a
      // teacher to `/student/settings`.
      expect(seen, same(TeacherNav.spec));
      expect(seen?.settingsPath, TeacherRoutes.settings);
    });

    testWidgets('is absent outside a shell, so callers must have a fallback',
        (tester) async {
      NavSpec? seen = TeacherNav.spec;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = NavSpecScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen, isNull);
    });
  });

  group('the router accepts both shells', () {
    test('builds the whole route tree without a path collision', () {
      // GoRouter validates paths when it is constructed, so this is the check
      // that the second ShellRoute did not collide with the student one or
      // declare a malformed path. Builders are lazy, so nothing is resolved
      // from the service locator here.
      final auth = _MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      final router = createRouter(auth);
      addTearDown(router.dispose);

      expect(router.configuration.routes, isNotEmpty);
    });
  });
}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
