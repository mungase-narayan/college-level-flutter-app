import 'package:flutter/material.dart';

/// One navigation destination — a sidebar row on the web, a drawer/menu-sheet
/// row here, and sometimes a bottom-bar shortcut.
class NavItem {
  const NavItem({
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

/// A labelled run of destinations, mirroring one `navGroups` entry on the web.
class NavGroup {
  const NavGroup({required this.label, required this.items});

  final String label;
  final List<NavItem> items;
}

/// Everything the shell chrome needs to render one role's area.
///
/// The drawer, the glass menu sheet, the app bar title, and the bottom bar all
/// read a spec rather than a specific role's nav class, so a second role costs a
/// data declaration instead of a second copy of the chrome.
class NavSpec {
  const NavSpec({
    required this.root,
    required this.groups,
    required this.bottomTabs,
    required this.portalLabel,
    required this.profilePath,
    required this.settingsPath,
    this.offSidebarTitles = const {},
  });

  /// The area prefix (`/student`, `/teacher`) the router guards on.
  final String root;

  final List<NavGroup> groups;

  /// The route-backed shortcuts on the bottom bar. The slot after these is
  /// **Menu**, which opens the drawer (or the glass sheet on iOS) holding every
  /// destination rather than navigating.
  final List<NavItem> bottomTabs;

  /// The area's name, used as the header's secondary line — and as the title of
  /// last resort when a route cannot be named.
  final String portalLabel;

  /// The account screen, reached from the app bar avatar and the menu sheet.
  final String profilePath;

  /// The settings screen, reached from the profile dropdown on Android.
  final String settingsPath;

  /// Titles for routes that are reachable but deliberately absent from the
  /// sidebar, so [activeFor] cannot name them.
  final Map<String, String> offSidebarTitles;

  /// Every destination, flattened — used by the router and for active matching.
  List<NavItem> get allItems => [for (final group in groups) ...group.items];

  /// Index of the Menu slot — the one that opens the drawer.
  ///
  /// Derived rather than hardcoded: it would silently point at the last tab the
  /// moment another shortcut was added.
  int get menuTabIndex => bottomTabs.length;

  /// Which bottom tab [location] belongs to.
  ///
  /// Anything reached from the drawer rather than a shortcut selects **Menu**,
  /// since that is how the user got there — a `NavigationBar` has to point at
  /// some destination, and leaving Home lit while the user reads Settings would
  /// be a lie.
  int bottomIndexFor(String location) {
    for (var i = 0; i < bottomTabs.length; i++) {
      final path = bottomTabs[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return menuTabIndex;
  }

  /// The header title for [location].
  ///
  /// Falls back to [portalLabel] only when a route is genuinely unnameable —
  /// which is also why the header suppresses its subtitle in that case, rather
  /// than rendering the portal label twice.
  String titleFor(String location) =>
      activeFor(location)?.label ?? offSidebarTitles[location] ?? portalLabel;

  /// The nav row that owns [location], or null when the route isn't in the
  /// sidebar (a drill-down such as a course or contest detail).
  ///
  /// Longest match wins so `/student/courses/:id` still highlights My Courses,
  /// while an `exact` item only matches its own path.
  NavItem? activeFor(String location) {
    NavItem? best;
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

/// Publishes the running shell's [NavSpec] to the screens beneath it.
///
/// Screens shared between role areas — the account screen, settings — need to
/// link to *their own* area's routes. Without this they would hardcode
/// `StudentRoutes`, and a teacher tapping Settings would be sent to
/// `/student/settings`, which the router's role guard bounces straight back.
class NavSpecScope extends InheritedWidget {
  const NavSpecScope({super.key, required this.spec, required super.child});

  final NavSpec spec;

  /// The area this screen is rendering inside, or null when it is not hosted by
  /// a shell at all (a root-navigator drill-down, or a widget test).
  static NavSpec? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavSpecScope>()?.spec;

  @override
  bool updateShouldNotify(NavSpecScope oldWidget) =>
      !identical(oldWidget.spec, spec);
}
