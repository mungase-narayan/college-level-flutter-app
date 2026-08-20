import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/contest_rating.dart';

/// The rating curve — one point per rated contest, oldest to newest.
///
/// Port of the web's Recharts `AreaChart`, drawn with `fl_chart`, which the
/// dashboard's analytics panels already use. The one thing not carried over is
/// the direct value label on the final point: Recharts reserves a 56px right
/// margin for it and `fl_chart` has no equivalent, so an overlay would drift out
/// of alignment as the domain changes. The current rating is already the
/// largest number on the screen in the first stat tile.
class RatingChart extends StatelessWidget {
  const RatingChart({super.key, required this.history});

  /// Oldest first, as the API returns it.
  final List<RatingHistoryEntry> history;

  static const height = 200.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // Only contests that actually moved the rating can be plotted.
    final points =
        history.where((entry) => entry.ratingAfter != null).toList(growable: false);
    if (points.isEmpty) return const SizedBox(height: height);

    final values = points.map((p) => p.ratingAfter!).toList(growable: false);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);

    // The web's padding rule. Without it a flat run of results sits pinned to
    // the frame and reads as though the axis were clipped.
    final pad = math.max(60.0, (highest - lowest) * 0.35);
    final minY = ((lowest - pad) / 50).floorToDouble() * 50;
    final maxY = ((highest + pad) / 50).ceilToDouble() * 50;

    // Tier thresholds that actually fall inside the visible band.
    final bands = RatingTier.all
        .where((tier) => tier.from > minY && tier.from < maxY)
        .toList(growable: false);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.border, strokeWidth: 1),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (final tier in bands)
                HorizontalLine(
                  y: tier.from.toDouble(),
                  color: tier.color.withValues(alpha: 0.45),
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontSize: 9, color: tier.color),
                    labelResolver: (_) => tier.name,
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, _) => Text(
                  '${value.toInt()}',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // Every label would collide on a phone once there are more than
                // a handful of contests, so they thin out as the run grows.
                interval: (points.length / 4).ceilToDouble(),
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Fmt.dm(points[index].endAt),
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.card,
              tooltipBorderRadius: BorderRadius.circular(AppTheme.radiusMd),
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  _tooltip(context, points[spot.x.toInt()]),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 2.5,
              color: scheme.primary,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: scheme.primary,
                  strokeColor: scheme.card,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    scheme.primary.withValues(alpha: 0.01),
                  ],
                ),
              ),
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].ratingAfter!.toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The web tooltip's four lines, flattened into the single string `fl_chart`
  /// allows — with the signed change carrying its own colour.
  LineTooltipItem _tooltip(BuildContext context, RatingHistoryEntry entry) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final delta = entry.ratingDelta ?? 0;
    final isGain = delta >= 0;

    final base = theme.textTheme.labelSmall?.copyWith(
          color: scheme.foreground,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle();
    final muted = base.copyWith(
      color: scheme.mutedForeground,
      fontWeight: FontWeight.w400,
    );

    return LineTooltipItem(
      entry.contestTitle,
      base,
      children: [
        TextSpan(text: '\n${entry.ratingAfter}  ', style: base),
        TextSpan(
          text: '${isGain ? '+' : ''}$delta',
          style: base.copyWith(
            color: tokens
                .tone(isGain ? TwColors.emerald : TwColors.rose)
                .foreground,
          ),
        ),
        if (entry.rank != null && entry.participants != null)
          TextSpan(
            text: '\nRank ${entry.rank} / ${entry.participants}',
            style: muted,
          ),
        if (entry.endAt != null)
          TextSpan(text: '\n${Fmt.longDate(entry.endAt)}', style: muted),
      ],
    );
  }
}
