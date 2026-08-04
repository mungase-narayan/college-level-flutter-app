import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../practice/domain/entities/practice_summary.dart';

/// Port of `src/pages/student/components/practice-analytics.tsx`.
///
/// The React version lays four Recharts panels in a row on desktop; on a phone
/// they stack, matching its own `grid-cols-1` breakpoint. Each panel shows an
/// empty state when every value in the series is zero, rather than an axis with
/// a flat line at nothing.
class PracticeAnalyticsSection extends StatelessWidget {
  const PracticeAnalyticsSection({super.key, required this.analytics});

  final PracticeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final week = analytics.lastWeek;
    final months = analytics.monthly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCard(
          title: 'Weekly practice',
          subtitle: 'Attempts over the last 7 days',
          icon: Icons.bar_chart_rounded,
          isEmpty: week.every((day) => day.attempts == 0),
          child: _AttemptsBarChart(days: week),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Accuracy trend',
          subtitle: 'Percentage correct over the last 7 days',
          icon: Icons.show_chart_rounded,
          isEmpty: week.every((day) => (day.accuracy ?? 0) == 0),
          child: _AccuracyLineChart(days: week),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Daily points',
          subtitle: 'Points earned over the last 7 days',
          icon: Icons.stars_rounded,
          isEmpty: week.every((day) => day.points == 0),
          child: _PointsAreaChart(days: week),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Questions solved',
          subtitle: 'Last 6 months',
          icon: Icons.pie_chart_outline_rounded,
          isEmpty: months.every((month) => month.solved == 0),
          child: _MonthlyDonut(months: months),
        ),
      ],
    );
  }
}

/// Shared chrome: title row, fixed-height plot area, and the shared empty state.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEmpty,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isEmpty;
  final Widget child;

  /// Every panel is the same height so the stacked cards read as one system.
  static const height = 190.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: SizedBox(
        height: height,
        child: isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No activity yet', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Solve some questions to see this chart.',
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Padding(padding: const EdgeInsets.only(top: 6), child: child),
      ),
    );
  }
}

/// Bottom axis: day-of-month only, matching the React tick formatter.
FlTitlesData _dayAxis(BuildContext context, List<PracticeDailyPoint> days) {
  final theme = Theme.of(context);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        getTitlesWidget: (value, meta) => Text(
          value.toInt().toString(),
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= days.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              days[index].dayLabel,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context) => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: context.scheme.border, strokeWidth: 1),
    );

class _AttemptsBarChart extends StatelessWidget {
  const _AttemptsBarChart({required this.days});

  final List<PracticeDailyPoint> days;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: _grid(context),
        titlesData: _dayAxis(context, days),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${Fmt.dmy(days[group.x].date)}\n${rod.toY.toInt()} attempts',
              TextStyle(color: scheme.popoverForeground, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].attempts.toDouble(),
                  width: 18,
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AccuracyLineChart extends StatelessWidget {
  const _AccuracyLineChart({required this.days});

  final List<PracticeDailyPoint> days;

  @override
  Widget build(BuildContext context) {
    // Cyan, as in the React chart.
    const stroke = Color(0xFF06B6D4);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        borderData: FlBorderData(show: false),
        gridData: _grid(context),
        titlesData: _dayAxis(context, days),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 2.5,
            color: stroke,
            dotData: const FlDotData(show: false),
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), (days[i].accuracy ?? 0).toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointsAreaChart extends StatelessWidget {
  const _PointsAreaChart({required this.days});

  final List<PracticeDailyPoint> days;

  @override
  Widget build(BuildContext context) {
    // Amber, as in the React `TrendArea`.
    const accent = Color(0xFFF59E0B);

    return LineChart(
      LineChartData(
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: _grid(context),
        titlesData: _dayAxis(context, days),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 2.5,
            color: accent,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.30),
                  accent.withValues(alpha: 0.02),
                ],
              ),
            ),
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), days[i].points.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

/// The donut of questions solved per month, with the total in the hole and a
/// legend beside it — the React `PieChart` with `innerRadius 62%`.
class _MonthlyDonut extends StatelessWidget {
  const _MonthlyDonut({required this.months});

  final List<PracticeMonthlyPoint> months;

  static const _palette = [
    Color(0xFF8A63FE),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = months.fold<int>(0, (sum, month) => sum + month.solved);

    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < months.length; i++)
                      if (months[i].solved > 0)
                        PieChartSectionData(
                          value: months[i].solved.toDouble(),
                          color: _palette[i % _palette.length],
                          radius: 22,
                          showTitle: false,
                        ),
                  ],
                ),
              ),
              // Ignores pointers so it never blocks a tap on a slice.
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Fmt.number(total),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('solved', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < months.length; i++)
                if (months[i].solved > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${months[i].label} · '
                            '${total == 0 ? 0 : ((months[i].solved / total) * 100).round()}%',
                            style: theme.textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Port of `PracticeDifficultyGrid` — easy / medium / hard, each with accuracy
/// and a solved-of-available bar.
class PracticeDifficultyGrid extends StatelessWidget {
  const PracticeDifficultyGrid({super.key, required this.difficulty});

  final List<PracticeBreakdown> difficulty;

  @override
  Widget build(BuildContext context) {
    if (difficulty.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in difficulty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DifficultyTile(row: row),
          ),
      ],
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.row});

  final PracticeBreakdown row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // `DIFF_META`: easy emerald, medium amber, hard rose.
    final shade = switch (row.label) {
      'easy' => TwColors.emerald,
      'hard' => TwColors.rose,
      _ => TwColors.amber,
    };
    final tone = tokens.tone(shade);
    final fraction =
        row.attempts == 0 ? 0.0 : (row.solved / row.attempts).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label.isEmpty
                      ? '—'
                      : row.label[0].toUpperCase() + row.label.substring(1),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: tone.foreground),
                ),
              ),
              Text(
                row.accuracy == null ? '—' : '${row.accuracy}% acc.',
                style: theme.textTheme.labelSmall?.copyWith(color: tone.foreground),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: tone.foreground.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(tone.foreground),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${row.solved} solved · ${row.attempts} attempted',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
