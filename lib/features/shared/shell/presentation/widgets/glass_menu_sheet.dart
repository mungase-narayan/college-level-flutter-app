import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/design/theme/glass_specs.dart';
import '../../../../../core/design/widgets/liquid_glass_list_tile.dart';
import '../../../../../core/design/widgets/liquid_glass_container.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import 'nav_spec.dart';

/// The iOS form of [AppDrawer].
///
/// A side drawer is a Material pattern — iOS has no equivalent, and reaching for
/// one on an iPhone is one of the clearest signs an app was designed for Android
/// first. The same destinations are presented here as an inset-grouped glass
/// sheet, which is how iOS actually surfaces a long secondary menu.
///
/// Reads the same [NavSpec] the drawer does, so the two platforms cannot drift
/// on what the menu contains or in what order.
Future<void> showAppMenuSheet(
  BuildContext context, {
  required NavSpec spec,
  required String currentPath,
}) async {
  final destination = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator, so the sheet covers the floating nav capsule instead of
    // being painted under it — the capsule is the shell Scaffold's
    // `bottomNavigationBar`, which always draws above its body. See
    // `showLiquidGlassSheet`.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: context.glass.scrim,
    builder: (context) =>
        _GlassMenuSheet(spec: spec, currentPath: currentPath),
  );

  // Navigate only after the sheet has closed, so the push animation does not
  // fight the sheet's dismissal.
  if (destination != null && context.mounted) {
    context.go(destination);
  }
}

class _GlassMenuSheet extends StatelessWidget {
  const _GlassMenuSheet({required this.spec, required this.currentPath});

  final NavSpec spec;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final media = MediaQuery.of(context);
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final activeRole = context.select((AuthBloc bloc) => bloc.state.activeRole);

    return ConstrainedBox(
      // Tall but not full-height: leaving the top of the screen visible is what
      // keeps this reading as a sheet over the app rather than as a new page.
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: LiquidGlassContainer(
        blur: GlassBlur.thick,
        spec: glass.overlay,
        borderRadius: GlassRadius.sheetTop,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(
                  top: GlassSpacing.sm,
                  bottom: GlassSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.mutedForeground.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(GlassRadius.capsule),
                ),
              ),
            ),
            // The account row doubles as the menu's header and as the entry point
            // to the profile screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GlassSpacing.lg,
                0,
                GlassSpacing.lg,
                GlassSpacing.lg,
              ),
              child: LiquidGlassSection(
                margin: EdgeInsets.zero,
                children: [
                  LiquidGlassListTile(
                    title: user?.displayName ?? activeRole?.label ?? 'Account',
                    subtitle: user?.email,
                    leading: AppAvatar(
                      imageUrl: user?.avatar,
                      name: user?.displayName,
                      size: 38,
                    ),
                    showChevron: true,
                    onTap: () =>
                        Navigator.of(context).pop(spec.profilePath),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: EdgeInsets.only(
                  left: GlassSpacing.lg,
                  right: GlassSpacing.lg,
                  bottom: media.viewPadding.bottom + GlassSpacing.lg,
                ),
                children: [
                  for (final group in spec.groups)
                    LiquidGlassSection(
                      header: group.label.toUpperCase(),
                      children: [
                        for (final item in group.items)
                          LiquidGlassListTile(
                            title: item.label,
                            leadingIcon: _isActive(item) ? item.activeIcon : item.icon,
                            // The active row is tinted rather than filled, so the
                            // sheet stays scannable.
                            leadingTint: _isActive(item)
                                ? scheme.primary
                                : scheme.mutedForeground,
                            trailing: _isActive(item)
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  )
                                : null,
                            showChevron: !_isActive(item),
                            onTap: () =>
                                Navigator.of(context).pop(item.path),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: GlassSpacing.xs),
                    child: LiquidGlassSection(
                      margin: EdgeInsets.zero,
                      children: [
                        LiquidGlassListTile(
                          title: 'Log out',
                          leadingIcon: Icons.logout_rounded,
                          destructive: true,
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: GlassSpacing.lg),
                    child: Center(
                      child: Text(
                        'College Level',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isActive(NavItem item) =>
      currentPath == item.path || currentPath.startsWith('${item.path}/');

  Future<void> _confirmLogout(BuildContext context) async {
    // Capture the bloc before awaiting — the sheet's context is unmounted by the
    // time the dialog resolves.
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to get back in.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed) return;

    navigator.pop();
    authBloc.add(const AuthLogoutRequested());
  }
}
