import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/badge.dart';

/// One badge, earned or still locked.
///
/// The web's locked card is dashed-bordered. That is dropped here: `AppCard`
/// draws its hairline in a `CustomPainter` on the iOS glass branch, so a dashed
/// overlay would double the edge on one platform only. Locked is still carried
/// by the muted surface, the grey medallion, the padlock pip and the muted
/// text.
class BadgeCard extends StatelessWidget {
  const BadgeCard({super.key, required this.definition, this.earned});

  final BadgeDefinition definition;

  /// The matching earned row, or null when the badge is still locked.
  final EarnedBadge? earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final badge = earned;
    final isEarned = badge != null;

    final accent = tokens.tone(BadgeTier.accent(definition.tier));
    // An unparseable timestamp drops the whole line rather than rendering
    // "Earned —", which is what `Fmt.longDate` would produce on its own.
    final earnedOn = isEarned && Fmt.parse(badge.earnedAt) != null
        ? Fmt.longDate(badge.earnedAt)
        : null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      color: isEarned
          ? accent.background
          : scheme.muted.withValues(alpha: 0.20),
      borderColor: isEarned
          ? accent.foreground.withValues(alpha: 0.30)
          : scheme.border.withValues(alpha: 0.50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Medallion(tier: definition.tier, isEarned: isEarned),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        definition.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isEarned
                              ? scheme.foreground
                              : scheme.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      // The default constructor, not `AppBadge.status` — that
                      // one humanises the label and would turn GOLD into Gold.
                      definition.tier.toUpperCase(),
                      shade: isEarned
                          ? BadgeTier.accent(definition.tier)
                          : TwColors.slate,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  definition.description,
                  style: theme.textTheme.bodySmall,
                ),
                if (earnedOn != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: tokens.success.foreground,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Earned $earnedOn',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.success.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tier-gradient disc, with a status pip tucked into its corner.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.tier, required this.isEarned});

  final String tier;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;

    return Stack(
      // The pip hangs off the disc's corner. The card's 14px padding keeps it
      // clear of `AppCard`'s own clip.
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEarned
                  ? BadgeTier.gradient(tier)
                  : [scheme.muted, scheme.muted],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            size: 22,
            color: isEarned
                ? Colors.white
                : scheme.mutedForeground.withValues(alpha: 0.40),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEarned
                    ? tokens.success.foreground.withValues(alpha: 0.30)
                    : scheme.border,
              ),
            ),
            child: Icon(
              isEarned ? Icons.check_rounded : Icons.lock_rounded,
              size: 12,
              color: isEarned
                  ? tokens.success.foreground
                  : scheme.mutedForeground.withValues(alpha: 0.60),
            ),
          ),
        ),
      ],
    );
  }
}
