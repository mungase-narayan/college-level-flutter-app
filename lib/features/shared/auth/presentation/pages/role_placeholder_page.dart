import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/constants/user_constants.dart';
import '../bloc/auth/auth_bloc.dart';
import '../widgets/role_selector_sheet.dart';

/// Landing shell for the roles this pass hasn't built yet — teacher,
/// class teacher, HOD, school admin, super admin, and accountant.
///
/// They authenticate and route correctly; the feature screens come in later
/// passes on the same foundation. A user who also holds the student role can
/// switch straight into it from here.
class RolePlaceholderPage extends StatelessWidget {
  const RolePlaceholderPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final otherRoles =
            state.roles.where((r) => r.name != role).toList(growable: false);

        return Scaffold(
          appBar: AdaptiveAppBar(
            title: role.label,
            actions: [
              IconButton(
                tooltip: 'Log out',
                onPressed: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: role.gradient),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Icon(role.icon, size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Signed in as ${state.user?.displayName ?? role.label}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The ${role.label} experience is not part of this release yet. '
                          'Your account, school, and permissions are all set up correctly.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  if (otherRoles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppSectionCard(
                      title: 'Switch role',
                      subtitle: 'Your account holds more than one role.',
                      icon: Icons.swap_horiz_rounded,
                      child: AppButton(
                        label: 'Choose a different role',
                        variant: AppButtonVariant.outline,
                        expand: true,
                        onPressed: () async {
                          final selected = await RoleSelectorSheet.show(
                            context,
                            roles: state.roles,
                            selected: state.activeRole,
                          );
                          if (selected == null || !context.mounted) return;
                          context.read<AuthBloc>().add(AuthRoleSelected(selected));
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
