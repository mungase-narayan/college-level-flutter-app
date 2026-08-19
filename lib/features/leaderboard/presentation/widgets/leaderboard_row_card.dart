import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/animations/glass_curves.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../domain/entities/leaderboard.dart';
import 'podium.dart';

/// One student's standing.
///
/// The web's `sm+` view is a six-column table; a phone gets a card instead, with
/// solved, accuracy and badges folded into the subtitle — which is what the
/// web's own mobile card does.
class LeaderboardRowCard extends StatelessWidget {
  const LeaderboardRowCard({super.key, required this.row, this.onTap});

  final LeaderboardRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    final subtitle = [
      if ((row.rollNumber ?? '').isNotEmpty) row.rollNumber!,
      '${row.solved} solved',
      // Null means never attempted. An em dash says that; 0% would claim they
      // got everything wrong.
      if (row.accuracy != null) '${row.accuracy}%' else '—',
      if (row.badgeCount > 0) '${row.badgeCount} badges',
    ].join(' · ');

    return AnimatedContainer(
      duration: glass.duration(GlassDurations.base),
      curve: glass.curve(GlassCurves.easeOutSmooth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        // The current user's row is tinted and ringed, as on the web.
        color: row.isMe ? scheme.primary.withValues(alpha: 0.06) : null,
        border: row.isMe
            ? Border.all(color: scheme.primary.withValues(alpha: 0.40))
            : null,
      ),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        // Transparent so the tint above shows through rather than being covered.
        color: row.isMe ? Colors.transparent : null,
        borderColor: row.isMe ? Colors.transparent : null,
        child: Row(
          children: [
            RankBadge(rank: row.rank),
            const SizedBox(width: 10),
            AppAvatar(imageUrl: row.avatar, name: row.fullName, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (row.isMe) ...[
                        const SizedBox(width: 5),
                        Text(
                          '(You)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: context.tokens.warning.foreground,
                ),
                const SizedBox(width: 3),
                Text(
                  '${row.points}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
