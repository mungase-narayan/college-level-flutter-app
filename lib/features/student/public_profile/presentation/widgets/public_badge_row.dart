import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../badges/domain/entities/badge.dart';
import '../../domain/entities/public_profile.dart';

/// One earned badge, full width.
///
/// A single column of wide rows rather than a grid of squares: at three columns
/// a phone gives each badge ~108px, which wrapped every name onto two lines and
/// clipped the category beneath it. Laid out horizontally the same content fits
/// on one line each, and the medallion still leads.
///
/// Reuses [BadgeTier] and [BadgeCategory] from the badges feature so the
/// gradient, accent and icon match the Badges tab exactly — these are the same
/// awards, and two palettes for one badge would be a bug.
class PublicBadgeRow extends StatelessWidget {
  const PublicBadgeRow({super.key, required this.badge});

  final PublicBadge badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final accent = context.tokens.tone(BadgeTier.accent(badge.tier));

    // "Jul 2026", as the web renders it.
    final earnedOn = badge.earnedAt;
    final earned =
        earnedOn == null ? '' : '${Fmt.monthShort(earnedOn)} ${earnedOn.year}';
    final category = BadgeCategory.label(badge.category);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      color: accent.background,
      borderColor: accent.foreground.withValues(alpha: 0.28),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: BadgeTier.gradient(badge.tier),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: scheme.card.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: Icon(
              BadgeCategory.icon(badge.category),
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  earned.isEmpty ? category : '$category · $earned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.foreground.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge.tier,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
