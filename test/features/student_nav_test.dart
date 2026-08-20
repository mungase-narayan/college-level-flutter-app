import 'package:college_level/features/shared/shell/presentation/widgets/student_nav.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drawer is a 1:1 port of the React sidebar, so its shape is part of the
/// contract, not an implementation detail.
void main() {
  group('StudentNav structure', () {
    test('has the four groups in sidebar order', () {
      expect(
        StudentNav.groups.map((g) => g.label),
        ['Overview', 'Learning', 'Compete', 'Campus'],
      );
    });

    test('has all nineteen destinations', () {
      expect(StudentNav.allItems, hasLength(19));
    });

    test('every route sits under /student and is unique', () {
      final paths = StudentNav.allItems.map((i) => i.path).toList();
      expect(paths.every((p) => p.startsWith('/student/')), isTrue);
      expect(paths.toSet(), hasLength(paths.length));
    });

    test('Overview matches the React group, including Weekly Report', () {
      expect(
        StudentNav.groups.first.items.map((i) => i.label),
        ['Dashboard', 'Analytics', 'Weekly Report'],
      );
    });
  });

  group('StudentNav.bottomIndexFor', () {
    test('exposes the route-backed shortcuts, then Menu', () {
      expect(
        StudentNav.bottomTabs.map((t) => t.label),
        ['Home', 'Courses', 'Practice', 'Profile'],
      );
      // Menu is the slot after the route-backed tabs and is not route-backed
      // itself. Derived, so adding a tab can never leave it pointing at one.
      expect(StudentNav.menuTabIndex, StudentNav.bottomTabs.length);
    });

    test('every shortcut points at a real student route', () {
      for (final tab in StudentNav.bottomTabs) {
        expect(
          tab.path.startsWith(StudentRoutes.root),
          isTrue,
          reason: '${tab.label} must be route-backed',
        );
      }
    });

    test('selects the matching shortcut', () {
      expect(StudentNav.bottomIndexFor(StudentRoutes.dashboard), 0);
      expect(StudentNav.bottomIndexFor(StudentRoutes.courses), 1);
      expect(StudentNav.bottomIndexFor(StudentRoutes.practice), 2);
      // Profile is a tab as well as being reachable from the header avatar, so it
      // must light its own tab rather than falling through to Menu.
      expect(StudentNav.bottomIndexFor(StudentRoutes.profile), 3);
    });

    test('keeps the shortcut selected on its drill-downs', () {
      expect(StudentNav.bottomIndexFor('/student/courses/abc-123'), 1);
      expect(StudentNav.bottomIndexFor('/student/practice/q-1'), 2);
    });

    test('falls back to Menu for drawer-only destinations', () {
      for (final path in [
        StudentRoutes.notes,
        StudentRoutes.wallet,
        StudentRoutes.settings,
        StudentRoutes.contests,
        StudentRoutes.weeklyReport,
      ]) {
        expect(
          StudentNav.bottomIndexFor(path),
          StudentNav.menuTabIndex,
          reason: '$path should light the Menu tab',
        );
      }
    });

    test('always returns an index the NavigationBar can render', () {
      // selectedIndex must stay within [0, destinations.length) or the bar
      // throws — including for routes that are not in the sidebar at all.
      //
      // Derived, not hardcoded: the bar renders one destination per bottom tab
      // plus the Menu slot, so adding a tab must not silently invalidate this.
      final destinationCount = StudentNav.bottomTabs.length + 1;
      for (final path in [...StudentNav.allItems.map((i) => i.path), '/nope']) {
        final index = StudentNav.bottomIndexFor(path);
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(destinationCount));
      }
    });
  });

  group('StudentNav.activeFor', () {
    test('matches a destination exactly', () {
      expect(StudentNav.activeFor(StudentRoutes.badges)?.label, 'Badges');
    });

    test('keeps the parent row active on a drill-down', () {
      expect(
        StudentNav.activeFor('/student/courses/abc-123')?.label,
        'My Courses',
      );
      expect(
        StudentNav.activeFor('/student/contests/xyz/arena')?.label,
        'Contests',
      );
    });

    test('an `exact` item ignores its children', () {
      // Announcements is `end: true` in React — the detail page must not
      // light the row up.
      expect(StudentNav.activeFor(StudentRoutes.announcements)?.label,
          'Announcements');
      expect(StudentNav.activeFor('/student/announcements/abc'), isNull);
    });

    test('prefers the longest match so sibling prefixes do not collide', () {
      // `/student/daily-challenge` must not be swallowed by any shorter path.
      expect(
        StudentNav.activeFor('/student/daily-challenge/2026-07-09')?.label,
        'Daily Challenge',
      );
    });

    test('returns null for a route outside the sidebar', () {
      expect(StudentNav.activeFor('/auth/login'), isNull);
    });
  });

  group('StudentNav.titleFor', () {
    test('names sidebar destinations from their nav row', () {
      expect(StudentNav.titleFor(StudentRoutes.dashboard), 'Dashboard');
      expect(StudentNav.titleFor(StudentRoutes.courses), 'My Courses');
      expect(StudentNav.titleFor(StudentRoutes.settings), 'Settings');
    });

    test('names off-sidebar destinations too', () {
      // Profile is reached from the header avatar, not the sidebar, so
      // `activeFor` cannot name it — without this it fell back to the portal
      // label and the header rendered "Student Portal" on both of its lines.
      expect(StudentNav.titleFor(StudentRoutes.profile), 'Profile');
      expect(
        StudentNav.titleFor(StudentRoutes.profile),
        isNot(StudentNav.portalLabel),
      );
    });

    test('falls back to the portal label only when truly unnameable', () {
      expect(StudentNav.titleFor('/student/nothing-here'),
          StudentNav.portalLabel);
    });

    test('every nameable route differs from the subtitle it sits above', () {
      // The header shows `portalLabel` as its second line, so any title equal to
      // it would duplicate. Guards the whole sidebar at once.
      for (final item in StudentNav.allItems) {
        expect(
          StudentNav.titleFor(item.path),
          isNot(StudentNav.portalLabel),
          reason: '${item.path} would render its title twice',
        );
      }
    });
  });
}
