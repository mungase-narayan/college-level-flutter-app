import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/config/theme/theme_cubit.dart';
import '../../../../core/design/animations/glass_press.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/design/utils/glass_insets.dart';
import '../../../../core/design/utils/glass_scroll.dart';
import '../../../../core/design/widgets/liquid_glass_app_bar.dart';
import '../../../../core/design/widgets/liquid_glass_navigation_bar.dart';
import '../../../../core/design/widgets/sliver_liquid_glass_app_bar.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../rewards/domain/usecases/rewards_usecases.dart';
import '../widgets/glass_menu_sheet.dart';
import '../widgets/student_drawer.dart';
import '../widgets/student_nav.dart';

/// Port of `src/pages/student/layout.tsx`.
///
/// Header + drawer + scrolling content. The React app pins the sidebar open on
/// desktop; on a phone the same tree lives behind the hamburger, so every one
/// of the nineteen destinations is one tap away and none of them is privileged
/// by a bottom bar the web app doesn't have.
///
/// Each child route supplies its own body; the shell owns the chrome, so
/// screens declare `StudentScaffold` rather than their own `Scaffold`.
class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.child,
    required this.recordDailyVisit,
  });

  final Widget child;
  final RecordDailyVisitUseCase recordDailyVisit;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  /// Lets the Menu tab open the drawer without needing a `Builder` to find a
  /// Scaffold that is created in this same `build`.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Feeds the floating glass chrome the current scroll offset so it can frost up
  /// and collapse its large title. Never listened to on Android.
  final _scrollOffset = GlassScrollNotifier();

  /// The route the shell was showing on the previous build, used to reset the
  /// scroll offset when the body changes. `ShellRoute` rebuilds the body per tab
  /// rather than preserving it, so the incoming screen always starts at the top —
  /// but the notifier would otherwise keep the outgoing screen's offset and leave
  /// the chrome frosted over a screen that has not been scrolled.
  String? _previousLocation;

  @override
  void initState() {
    super.initState();
    // `DailyVisitTracker` — fire-and-forget once per app session; the backend
    // is idempotent per IST day and awards +1 point on the first call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.recordDailyVisit(const NoParams());
    });
  }

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onTabSelected(int index, String location) {
    if (index == StudentNav.menuTabIndex) {
      if (context.useGlass) {
        // A side drawer is not an iOS pattern; the same nineteen destinations
        // are presented as a glass sheet instead.
        unawaited(showGlassMenuSheet(context, currentPath: location));
      } else {
        _scaffoldKey.currentState?.openDrawer();
      }
      return;
    }

    final path = StudentNav.bottomTabs[index].path;
    // Re-tapping the active tab pops back to its root (e.g. from a course
    // detail to the course list) instead of pushing a duplicate.
    if (location == path) return;
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final title = StudentNav.titleFor(location);

    if (location != _previousLocation) {
      _previousLocation = location;
      // Post-frame: the notifier's listeners are the chrome widgets currently
      // being built, and mutating it mid-build would throw.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollOffset.reset());
    }

    if (context.useGlass) {
      return _GlassShellChrome(
        title: title,
        location: location,
        scrollOffset: _scrollOffset,
        onTabSelected: (index) => _onTabSelected(index, location),
        child: widget.child,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: StudentDrawer(currentPath: location),
      appBar: _StudentAppBar(title: title),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: StudentNav.bottomIndexFor(location),
        onDestinationSelected: (index) => _onTabSelected(index, location),
        destinations: [
          for (final tab in StudentNav.bottomTabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu_rounded),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}

/// The iOS shell: content scrolling beneath a floating glass app bar and a
/// floating glass navigation capsule.
///
/// `extendBody` and `extendBodyBehindAppBar` are what let content pass *under*
/// the chrome — the effect the whole design rests on. The cost is that scroll
/// views must pad themselves clear of the bars, which is what [GlassInsetsScope]
/// publishes.
class _GlassShellChrome extends StatelessWidget {
  const _GlassShellChrome({
    required this.title,
    required this.location,
    required this.scrollOffset,
    required this.onTabSelected,
    required this.child,
  });

  final String title;
  final String location;
  final GlassScrollNotifier scrollOffset;
  final ValueChanged<int> onTabSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // The header is a sliver inside the body now, not a Scaffold app bar, so
      // there is no app bar for the body to extend behind.
      body: NestedScrollView(
        // This is what makes the header hide on scroll-down and return on
        // scroll-up: as a sliver its height is part of the scroll extent, so the
        // body rises to fill exactly the space it vacates — at 1:1 with the
        // finger, with no hole left behind. See `SliverLiquidGlassAppBar` for why
        // no non-sliver approach can do this.
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverLiquidGlassAppBar(
            title: title,
            scrolledUnder: innerBoxIsScrolled,
            actions: const [_ThemeToggleAction(), _NotificationsAction()],
            leading: const _ProfileAvatarButton(),
          ),
        ],
        body: GlassScrollScope(
          notifier: scrollOffset,
          child: GlassInsetsScope(
            // No top inset: the sliver header occupies real scroll space, so
            // padding the body clear of it would double-count and reintroduce the
            // gap this replaced. Only the floating nav capsule still needs
            // reserving, since that genuinely floats above the content.
            contentInsets: EdgeInsets.only(
              bottom: GlassInsetsMath.bottomInset(),
            ),
            // Inside the NestedScrollView body, so the body's own scrollables are
            // at depth 0 here — the outer header position must not drive frost.
            child: GlassScrollObserver(notifier: scrollOffset, child: child),
          ),
        ),
      ),
      bottomNavigationBar: LiquidGlassNavigationBar(
        currentIndex: StudentNav.bottomIndexFor(location),
        onSelected: onTabSelected,
        scrollOffset: scrollOffset,
        items: [
          for (final tab in StudentNav.bottomTabs)
            GlassNavItem(
              label: tab.label,
              icon: tab.icon,
              activeIcon: tab.activeIcon,
            ),
          const GlassNavItem(
            label: 'Menu',
            icon: Icons.more_horiz_rounded,
            activeIcon: Icons.more_horiz_rounded,
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleAction extends StatelessWidget {
  const _ThemeToggleAction();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return LiquidGlassAppBarAction(
      icon: tokens.isDark
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined,
      tooltip: 'Toggle theme',
      size: 20,
      onPressed: () =>
          context.read<ThemeCubit>().toggle(Theme.of(context).brightness),
    );
  }
}

class _NotificationsAction extends StatelessWidget {
  const _NotificationsAction();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassAppBarAction(
      icon: Icons.notifications_none_rounded,
      tooltip: 'Notifications',
      onPressed: () => AppToast.warning(
        context,
        'Notifications are coming with the next tab.',
      ),
    );
  }
}

/// The avatar in the leading slot, opening the profile screen.
///
/// On iOS this navigates rather than opening a dropdown: a popover hanging off a
/// leading-edge avatar is awkward on a phone, and the account screen it would
/// have linked to now exists.
class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    return GlassPressable(
      onTap: () => context.go(StudentRoutes.profile),
      pressedScale: 0.9,
      semanticLabel: 'Account',
      child: AppAvatar(
        imageUrl: user?.avatar,
        name: user?.displayName,
        size: 32,
      ),
    );
  }
}

/// Port of `student/components/header.tsx`: hamburger · logo · title · theme
/// toggle · notifications · profile.
class _StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StudentAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;

        return AppBar(
          toolbarHeight: 60,
          // A Scaffold with a drawer inserts its own hamburger; the Menu tab in
          // the bottom bar is the drawer's entry point now, so suppress it and
          // let the title start at the leading edge.
          automaticallyImplyLeading: false,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Suppressed when the route could not be named and the title has
              // already fallen back to this same string.
              if (title != StudentNav.portalLabel)
                Text(StudentNav.portalLabel, style: theme.textTheme.labelSmall),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                tokens.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              onPressed: () =>
                  context.read<ThemeCubit>().toggle(theme.brightness),
            ),
            // The notification bell is wired once the notifications feature
            // lands; the slot is reserved so the header layout doesn't shift.
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded, size: 21),
              onPressed: () => AppToast.warning(
                context,
                'Notifications are coming with the next tab.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 12),
              child: _ProfileMenu(
                name: user?.displayName,
                email: user?.email,
                avatar: user?.avatar,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: context.scheme.border),
          ),
        );
      },
    );
  }
}

/// The avatar dropdown: name + email, then Log out.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({this.name, this.email, this.avatar});

  final String? name;
  final String? email;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? 'Student', style: theme.textTheme.titleSmall),
              if (email != null)
                Text(email!, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 18),
              const SizedBox(width: 10),
              Text('Settings', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: scheme.destructive),
              const SizedBox(width: 10),
              Text(
                'Log out',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.destructive),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'settings') {
          context.go(StudentRoutes.settings);
          return;
        }
        final confirmed = await showAppConfirmDialog(
          context,
          title: 'Log out?',
          message: "You'll need to sign in again to get back in.",
          confirmLabel: 'Log out',
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        context.read<AuthBloc>().add(const AuthLogoutRequested());
      },
      child: AppAvatar(imageUrl: avatar, name: name, size: 32),
    );
  }
}

/// The body wrapper every student screen uses.
///
/// The shell owns the app bar and drawer, so screens contribute only content —
/// this keeps the header stable across navigation instead of rebuilding a new
/// `Scaffold` per route.
class StudentScaffold extends StatelessWidget {
  const StudentScaffold({
    super.key,
    required this.child,
    this.floatingActionButton,
  });

  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        // On iOS the bottom clearance is supplied as scroll *padding* by
        // `GlassInsetsScope`, which lets content pass under the floating capsule.
        // A SafeArea here would instead clip the viewport short of it, and the two
        // together would leave a dead gap the width of the home indicator.
        bottom: !context.useGlass,
        child: child,
      ),
    );
  }
}
