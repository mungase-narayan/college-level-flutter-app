import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/constants/user_constants.dart';
import '../../domain/entities/user.dart';

/// Port of the React `RoleSelectorDialog`.
///
/// Shown only when the login response carries more than one role — single-role
/// users go straight to their home. Also reused by the settings screen to
/// switch the active role mid-session.
class RoleSelectorSheet extends StatelessWidget {
  const RoleSelectorSheet({super.key, required this.roles, this.selected});

  final List<LoginRole> roles;
  final UserRole? selected;

  /// Resolves to the chosen role, or null if the sheet was dismissed.
  static Future<UserRole?> show(
    BuildContext context, {
    required List<LoginRole> roles,
    UserRole? selected,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<UserRole>(
      context: context,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      builder: (_) => PopScope(
        canPop: dismissible,
        child: RoleSelectorSheet(roles: roles, selected: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a role', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Your account has more than one role. Pick the one you want to work in.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: roles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final role = roles[index].name;
                final isSelected = role == selected;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(role),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.card,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: isSelected ? scheme.primary : scheme.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: role.gradient),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Icon(role.icon, size: 21, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(role.label, style: theme.textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(role.description, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
