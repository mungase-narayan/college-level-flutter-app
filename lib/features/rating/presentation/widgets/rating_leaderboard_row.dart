import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/animations/glass_curves.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../domain/entities/contest_rating.dart';

/// One rated student in the school standings.
class RatingLeaderboardRow extends StatelessWidget {
  const RatingLeaderboardRow({super.key, required this.entry, this.onTap});

  final RatingLeaderboardEntry entry;
  final VoidCallback? onTap;

  /// Gold, silver, bronze, then neutral — the web's medal colours.
  Color _rankColor(BuildContext context) => switch (entry.rank) {
        1 => context.tokens.tone(TwColors.amber).foreground,
        2 => context.tokens.tone(TwColors.slate).foreground,
        3 => context.tokens.tone(TwColors.orange).foreground,
        _ => context.scheme.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    return AnimatedContainer(
      duration: glass.duration(GlassDurations.base),
      curve: glass.curve(GlassCurves.easeOutSmooth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        color: entry.isCurrentUser
            ? scheme.primary.withValues(alpha: 0.06)
            : null,
        border: entry.isCurrentUser
            ? Border.all(color: scheme.primary.withValues(alpha: 0.40))
            : null,
      ),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // Transparent so the tint above shows through rather than covering it.
        color: entry.isCurrentUser ? Colors.transparent : null,
        borderColor: entry.isCurrentUser ? Colors.transparent : null,
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _rankColor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppAvatar(imageUrl: entry.avatarUrl, name: entry.name, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (entry.isCurrentUser) ...[
                        const SizedBox(width: 5),
                        Text(
                          '(you)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // A dot in the tier colour, then the tier name — the web
                      // shows both so the colour is never the only signal.
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: entry.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${entry.tier} · ${entry.contestsPlayed} contest'
                          '${entry.contestsPlayed == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.rating}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
