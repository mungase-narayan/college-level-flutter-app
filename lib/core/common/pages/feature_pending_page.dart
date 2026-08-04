import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../widgets/app_card.dart';

/// Honest placeholder for a student route whose feature is scheduled for a
/// later pass.
///
/// The route, navigation entry, and role guard are all real and wired — only
/// the screen body is outstanding. Keeping these visible (rather than hiding
/// the nav entries) means the information architecture matches the React app
/// from day one.
class FeaturePendingPage extends StatelessWidget {
  const FeaturePendingPage({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_rounded,
    this.showAppBar = true,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.muted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Icon(icon, size: 25, color: scheme.mutedForeground),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
