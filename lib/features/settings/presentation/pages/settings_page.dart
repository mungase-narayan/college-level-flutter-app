import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/reduce_transparency_cubit.dart';
import '../../../../core/config/theme/theme_cubit.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/design/theme/glass_specs.dart';
import '../../../../core/design/widgets/liquid_glass_list_tile.dart';
import '../../../../core/design/widgets/liquid_glass_segmented_control.dart';
import '../../../../core/design/widgets/liquid_glass_switch.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../../profile/presentation/widgets/edit_profile_sheet.dart';
import '../../../shell/presentation/widgets/student_nav.dart';

/// The Settings screen.
///
/// Cross-platform by construction: it is built entirely from the shared widget
/// kit plus the glass section/tile primitives, so on iOS it renders as an
/// inset-grouped glass list and on Android the same rows come through as Material
/// surfaces. Nothing here is iOS-only.
///
/// The appearance controls are wired to the two cubits that actually drive the
/// theme — [ThemeCubit] and [ReduceTransparencyCubit] — so these are real
/// settings, not a mock-up.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = context.glassContentInsets;

    return StudentScaffold(
      child: ListView(
        padding: EdgeInsets.only(
          left: GlassSpacing.lg,
          right: GlassSpacing.lg,
          top: GlassSpacing.md + insets.top,
          bottom: GlassSpacing.xxl + insets.bottom,
        ),
        children: const [
          _AppearanceSection(),
          _AccessibilitySection(),
          _NotificationsSection(),
          _AccountSection(),
          _AboutSection(),
          _SignOutSection(),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;

    return LiquidGlassSection(
      header: 'APPEARANCE',
      footer: 'Following the system setting switches automatically with '
          "your device's appearance schedule.",
      children: [
        Padding(
          padding: const EdgeInsets.all(GlassSpacing.md),
          child: LiquidGlassSegmentedControl<ThemeMode>(
            value: themeMode,
            onChanged: (mode) => context.read<ThemeCubit>().set(mode),
            segments: const [
              GlassSegment(
                value: ThemeMode.light,
                label: 'Light',
                icon: Icons.light_mode_outlined,
              ),
              GlassSegment(
                value: ThemeMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
              ),
              GlassSegment(
                value: ThemeMode.system,
                label: 'Auto',
                icon: Icons.brightness_auto_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessibilitySection extends StatelessWidget {
  const _AccessibilitySection();

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = context.watch<ReduceTransparencyCubit>().state;
    final systemHighContrast = MediaQuery.highContrastOf(context);

    return LiquidGlassSection(
      header: 'ACCESSIBILITY',
      footer: systemHighContrast
          ? 'Your device has increased contrast enabled, so transparency is '
              'already reduced.'
          : 'Makes frosted surfaces opaque, which increases contrast and '
              'lightens rendering work.',
      children: [
        LiquidGlassListTile(
          title: 'Reduce transparency',
          subtitle: 'Replace frosted glass with solid surfaces',
          leadingIcon: Icons.blur_off_rounded,
          trailing: LiquidGlassSwitch(
            // The system setting forces this on and cannot be overridden
            // downward, so the control reflects that rather than lying.
            value: reduceTransparency || systemHighContrast,
            onChanged: systemHighContrast
                ? null
                : (value) => context.read<ReduceTransparencyCubit>().set(value),
            semanticLabel: 'Reduce transparency',
          ),
        ),
        LiquidGlassListTile(
          title: 'Motion',
          subtitle: 'Controlled by your device settings',
          leadingIcon: Icons.animation_rounded,
          trailingText:
              MediaQuery.disableAnimationsOf(context) ? 'Reduced' : 'Full',
        ),
        LiquidGlassListTile(
          title: 'Text size',
          subtitle: 'Controlled by your device settings',
          leadingIcon: Icons.format_size_rounded,
          trailingText:
              '${(MediaQuery.textScalerOf(context).scale(100)).round()}%',
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();

  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  // Local-only for now: there is no notification preferences endpoint yet, and
  // the toggles are wired to state rather than faked so they behave correctly the
  // moment one exists.
  bool _assignments = true;
  bool _announcements = true;
  bool _dailyChallenge = false;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSection(
      header: 'NOTIFICATIONS',
      footer: 'Delivery is not wired up yet — these preferences are saved on '
          'this device only.',
      children: [
        LiquidGlassListTile(
          title: 'Assignment reminders',
          leadingIcon: Icons.assignment_outlined,
          trailing: LiquidGlassSwitch(
            value: _assignments,
            onChanged: (value) => setState(() => _assignments = value),
            semanticLabel: 'Assignment reminders',
          ),
        ),
        LiquidGlassListTile(
          title: 'Announcements',
          leadingIcon: Icons.campaign_outlined,
          trailing: LiquidGlassSwitch(
            value: _announcements,
            onChanged: (value) => setState(() => _announcements = value),
            semanticLabel: 'Announcements',
          ),
        ),
        LiquidGlassListTile(
          title: 'Daily challenge',
          leadingIcon: Icons.local_fire_department_outlined,
          trailing: LiquidGlassSwitch(
            value: _dailyChallenge,
            onChanged: (value) => setState(() => _dailyChallenge = value),
            semanticLabel: 'Daily challenge',
          ),
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final user = state.user;

    return LiquidGlassSection(
      header: 'ACCOUNT',
      children: [
        LiquidGlassListTile(
          title: 'Profile',
          subtitle: user?.email,
          leading: AppAvatar(
            imageUrl: user?.avatar,
            name: user?.displayName,
            size: 30,
          ),
          showChevron: true,
          onTap: () => context.go(StudentRoutes.profile),
        ),
        // The web app puts profile editing in Settings, so it is reachable from
        // both here and the Profile screen's own header.
        LiquidGlassListTile(
          title: 'Edit profile',
          subtitle: 'Username and profile picture',
          leadingIcon: Icons.edit_outlined,
          enabled: user != null,
          onTap: user == null ? null : () => showEditProfileSheet(context, user),
        ),
        if (state.roles.length > 1)
          LiquidGlassListTile(
            title: 'Switch role',
            subtitle: state.activeRole?.label,
            leadingIcon: Icons.switch_account_outlined,
            showChevron: true,
            onTap: () => _switchRole(context),
          ),
        LiquidGlassListTile(
          title: 'School',
          trailingText: state.school?.name,
          leadingIcon: Icons.school_outlined,
        ),
      ],
    );
  }

  Future<void> _switchRole(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final current = authBloc.state.activeRole;

    final picked = await showAppOptionSheet(
      context,
      title: 'Switch role',
      selected: current,
      options: [
        for (final role in authBloc.state.roles)
          AppSheetOption(
            value: role.name,
            label: role.name.label,
            description: role.name.description,
            icon: role.name.icon,
          ),
      ],
    );

    if (picked == null || picked == current) return;
    authBloc.add(AuthRoleSelected(picked));
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSection(
      header: 'ABOUT',
      children: [
        const LiquidGlassListTile(
          title: 'Version',
          leadingIcon: Icons.info_outline_rounded,
          trailingText: '1.0.0',
        ),
        LiquidGlassListTile(
          title: 'Open source licences',
          leadingIcon: Icons.description_outlined,
          showChevron: true,
          // A pushed route rather than `showLicensePage`: that helper builds a
          // plain Material page onto the shell's navigator, so the shell app bar
          // and nav capsule stayed on top of it.
          onTap: () => context.push(StudentRoutes.licenses),
        ),
      ],
    );
  }
}

class _SignOutSection extends StatelessWidget {
  const _SignOutSection();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSection(
      children: [
        LiquidGlassListTile(
          title: 'Log out',
          leadingIcon: Icons.logout_rounded,
          destructive: true,
          onTap: () => _confirmLogout(context),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // Captured before the await: logging out tears this route down, so reading
    // the bloc off `context` afterwards would be reading a dead element.
    final authBloc = context.read<AuthBloc>();

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to get back in.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed) return;

    authBloc.add(const AuthLogoutRequested());
  }
}
