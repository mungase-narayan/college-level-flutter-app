import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/badge.dart';

/// The page header: how many badges are earned, out of how many exist.
///
/// A pure function of [badges], so it renders correctly from an empty
/// [BadgeCollection] while the first fetch is still in flight — which is how
/// the page keeps it on screen during loading, as the web does.
class BadgesProgressHero extends StatelessWidget {
  const BadgesProgressHero({super.key, required this.badges});

  final BadgeCollection badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final total = badges.totalCount;
    final percent = badges.progressPercent;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  size: 24,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Badges',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total > 0
                          ? "You've earned ${badges.earnedCount} of $total badges."
                          : 'Earn badges by practicing consistently.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      // Driven by the rounded percent rather than the raw
                      // ratio, so the bar and the label beside it can never
                      // disagree by a rounding step.
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: scheme.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
