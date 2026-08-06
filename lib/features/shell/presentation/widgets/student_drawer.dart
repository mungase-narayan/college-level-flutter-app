import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../auth/presentation/widgets/role_selector_sheet.dart';
import 'student_nav.dart';

/// Port of `src/pages/student/components/sidebar.tsx`.
///
/// The React app pins this as a fixed left sidebar; on a phone the same tree
/// lives in the drawer. Group labels, ordering, routes, and the active-row
/// treatment (primary tint + left marker bar + tinted icon chip) are unchanged.
class StudentDrawer extends StatelessWidget {
  const StudentDrawer({super.key, required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final active = StudentNav.activeFor(currentPath);

    return Drawer(
      width: 292,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                children: [
                  for (final group in StudentNav.groups) ...[
                    _GroupLabel(group.label),
                    for (final item in group.items)
                      _NavRow(item: item, isActive: item == active),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const _DrawerFooter(),
          ],
        ),
      ),
    );
  }
}

/// The app-logo chip + school name / "Student Portal" block from
/// `MobileStudentSidebar`.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final school = state.school;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Row(
            children: [
              const AppLogo(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school?.config?.appName ?? school?.name ?? 'College Level',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Student Portal', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// `px-4 text-[12px] uppercase tracking-widest text-muted-foreground/60`.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// One sidebar row.
///
/// Active: `bg-primary/10`, primary text, semibold, a 4×20 left marker bar, and
/// an icon chip tinted `bg-primary/15`.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.item, required this.isActive});

  final StudentNavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Material(
            color: isActive ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () {
                Navigator.of(context).pop();
                // `go`, not `push` — sidebar rows replace the current screen
                // rather than stacking, matching NavLink.
                if (!isActive) context.go(item.path);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive
                            ? scheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 17,
                        color: isActive ? scheme.primary : scheme.sidebarForeground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isActive ? scheme.primary : scheme.foreground,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The `-left-2 h-5 w-1 rounded-r-full bg-primary` marker.
          if (isActive)
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Role switcher (multi-role accounts only) + log out.
class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.session?.isMultiRole ?? false)
              ListTile(
                dense: true,
                leading: const Icon(Icons.swap_horiz_rounded, size: 20),
                title: Text('Switch role', style: theme.textTheme.bodyMedium),
                onTap: () async {
                  final selected = await RoleSelectorSheet.show(
                    context,
                    roles: state.roles,
                    selected: state.activeRole,
                  );
                  if (selected == null || !context.mounted) return;
                  Navigator.of(context).pop();
                  context.read<AuthBloc>().add(AuthRoleSelected(selected));
                },
              ),
            ListTile(
              dense: true,
              leading: Icon(Icons.logout_rounded, size: 20, color: scheme.destructive),
              title: Text(
                'Log out',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.destructive),
              ),
              onTap: () async {
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
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
