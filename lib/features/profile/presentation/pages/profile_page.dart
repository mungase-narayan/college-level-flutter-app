import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/design/theme/glass_specs.dart';
import '../../../../core/design/widgets/liquid_glass_card.dart';
import '../../../../core/design/widgets/liquid_glass_list_tile.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../widgets/edit_profile_sheet.dart';

/// The account screen, reached from the app bar avatar and from the menu sheet.
///
/// Read-only and entirely derived from the session already in [AuthBloc] — no new
/// API calls, no data layer, no cubit. That is deliberate: everything shown here
/// is already in memory, so adding a repository would buy nothing but a loading
/// spinner.
///
/// Cross-platform: built from the shared kit plus the glass primitives, so it
/// renders as an inset-grouped glass list on iOS and as Material surfaces on
/// Android.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = context.glassContentInsets;
    final state = context.watch<AuthBloc>().state;
    final user = state.user;

    return StudentScaffold(
      child: ListView(
        padding: EdgeInsets.only(
          left: GlassSpacing.lg,
          right: GlassSpacing.lg,
          top: GlassSpacing.md + insets.top,
          bottom: GlassSpacing.xxl + insets.bottom,
        ),
        children: [
          _ProfileHeader(
            name: user?.displayName ?? 'Student',
            email: user?.email,
            avatar: user?.avatar,
            username: user?.username,
            verified: user?.isEmailVerified ?? false,
            // Only offered when there is a user to edit; the header still renders
            // its placeholder state while the session is resolving.
            onEdit: user == null ? null : () => showEditProfileSheet(context, user),
          ),
          const SizedBox(height: GlassSpacing.xl),
          LiquidGlassSection(
            header: 'DETAILS',
            children: [
              LiquidGlassListTile(
                title: 'Username',
                leadingIcon: Icons.alternate_email_rounded,
                // As a subtitle, matching the Email row below. These usernames are
                // full email addresses, and a value that long in the trailing slot
                // crushed the title until "Username" wrapped mid-word.
                subtitle: user?.username,
              ),
              LiquidGlassListTile(
                title: 'Email',
                leadingIcon: Icons.mail_outline_rounded,
                subtitle: user?.email,
                trailing: AppBadge(
                  (user?.isEmailVerified ?? false) ? 'Verified' : 'Unverified',
                  shade: (user?.isEmailVerified ?? false)
                      ? TwColors.emerald
                      : TwColors.amber,
                  dense: true,
                ),
              ),
              LiquidGlassListTile(
                title: 'Status',
                leadingIcon: Icons.verified_user_outlined,
                trailing: AppBadge.status(user?.status ?? 'unknown', dense: true),
              ),
            ],
          ),
          if (state.roles.isNotEmpty)
            LiquidGlassSection(
              header: state.roles.length > 1 ? 'ROLES' : 'ROLE',
              // The description lives in the footer rather than as a row
              // subtitle: at this width it wrapped to two lines and crushed the
              // "Active" badge. A single-line row with a trailing badge matches
              // the Status row above, and the footer is where iOS puts the
              // explanatory text anyway.
              footer: state.roles.length > 1
                  ? 'You can switch between your roles from Settings.'
                  : state.roles.first.name.description,
              children: [
                for (final role in state.roles)
                  LiquidGlassListTile(
                    title: role.name.label,
                    leadingIcon: role.name.icon,
                    trailing: role.name == state.activeRole
                        ? const AppBadge('Active',
                            shade: TwColors.violet, dense: true)
                        : null,
                  ),
              ],
            ),
          if (state.school case final school?)
            LiquidGlassSection(
              header: 'SCHOOL',
              children: [
                LiquidGlassListTile(
                  title: school.name,
                  leading: SchoolLogo(
                    logo: school.config?.logo,
                    logoDark: school.config?.logoDark,
                    name: school.name,
                    height: 26,
                  ),
                ),
              ],
            ),
          LiquidGlassSection(
            children: [
              LiquidGlassListTile(
                title: 'Settings',
                leadingIcon: Icons.settings_outlined,
                showChevron: true,
                onTap: () => context.go(StudentRoutes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The hero header: a large avatar on a glass card, over a brand-tinted wash.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.avatar,
    required this.username,
    required this.verified,
    required this.onEdit,
  });

  final String name;
  final String? email;
  final String? avatar;
  final String? username;
  final bool verified;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final email = this.email;

    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: GlassSpacing.xl,
        vertical: GlassSpacing.xxl,
      ),
      // A brand-tinted edge lifts the header above the plain sections below it.
      borderColor: scheme.primary.withValues(alpha: glass.isDark ? 0.34 : 0.22),
      child: Column(
        children: [
          // The avatar reads as a physical object on the glass, so it gets a
          // ring and a shadow of its own rather than sitting flat.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: AppAvatar(imageUrl: avatar, name: name, size: 76),
          ),
          const SizedBox(height: GlassSpacing.lg),
          Text(
            name,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (email != null) ...[
            const SizedBox(height: 2),
            Text(
              email,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (username != null) ...[
            const SizedBox(height: GlassSpacing.md),
            AppBadge('@$username', shade: TwColors.violet, dense: true),
          ],
          if (onEdit != null) ...[
            const SizedBox(height: GlassSpacing.lg),
            AppButton(
              label: 'Edit profile',
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}
