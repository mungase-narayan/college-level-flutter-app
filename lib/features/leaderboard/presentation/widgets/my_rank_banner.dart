import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/leaderboard.dart';

/// The student's own standing.
///
/// Sits outside the list's loading and error branches: it is the one number on
/// the screen that is about the person reading it, and a failed page fetch
/// should not take it away.
class MyRankBanner extends StatelessWidget {
  const MyRankBanner({
    super.key,
    required this.me,
    required this.scope,
    required this.period,
  });

  final LeaderboardMe me;
  final String scope;
  final String period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      color: scheme.primary.withValues(alpha: 0.07),
      borderColor: scheme.primary.withValues(alpha: 0.20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  '#${me.rank}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primaryForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your rank', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${LeaderboardScope.label(scope)} · '
                      '${LeaderboardPeriod.label(period)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RankStat(
                icon: Icons.star_rounded,
                value: Fmt.number(me.points),
                label: 'POINTS',
                shade: TwColors.amber,
              ),
              const SizedBox(width: 8),
              _RankStat(
                icon: Icons.check_circle_rounded,
                value: Fmt.number(me.solved),
                label: 'SOLVED',
                shade: TwColors.blue,
              ),
              // Null until the student has attempted something — a 0% would
              // claim they have been getting everything wrong.
              if (me.accuracy != null) ...[
                const SizedBox(width: 8),
                _RankStat(
                  icon: Icons.my_location_rounded,
                  value: '${me.accuracy}%',
                  label: 'ACCURACY',
                  shade: TwColors.emerald,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RankStat extends StatelessWidget {
  const _RankStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.shade,
  });

  final IconData icon;
  final String value;
  final String label;
  final TwShade shade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(shade);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border.withValues(alpha: 0.60)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 14, color: tone.foreground),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Scaled down rather than ellipsized: three equal tiles leave
                  // "ACCURACY" a few pixels short, and "ACCURA…" reads as a
                  // bug. Shrinking keeps the whole word legible instead.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
