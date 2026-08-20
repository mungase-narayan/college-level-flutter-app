import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/submission.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../bloc/statistics_cubit.dart';

/// Port of `question-statistics.tsx`.
///
/// Hidden entirely for submission-type assessments, which have no questions to
/// analyse — the results page drops the tab rather than showing an empty one.
class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  @override
  void initState() {
    super.initState();
    context.read<StatisticsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StatisticsCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.load(refresh: true),
      child: BlocBuilder<StatisticsCubit, RemoteState<List<QuestionStat>>>(
        builder: (context, state) {
          final failure = state.failure;
          final stats = state.data ?? const <QuestionStat>[];

          if (state.isInitialLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: AppListSkeleton(rows: 3, lines: 4),
            );
          }
          if (state.status == RemoteStatus.failure && failure != null) {
            return AppErrorView(failure: failure, onRetry: cubit.load);
          }
          if (stats.isEmpty) {
            return const AppEmptyState(
              icon: Icons.query_stats_outlined,
              title: 'Nothing to analyse yet',
              description: 'Statistics appear once attempts are submitted.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Kpis(cubit: cubit),
              const SizedBox(height: 14),
              _AccuracyChart(stats: stats),
              const SizedBox(height: 16),
              Text(
                'Question breakdown',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Accumulated across every submitted attempt.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                StaggeredEntrance(
                  index: i,
                  child: _QuestionCard(stat: stats[i], index: i),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.cubit});

  final StatisticsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final avg = cubit.averageAccuracy;
    final highest = cubit.highestAccuracy;

    return AppStatGrid(
      tiles: [
        AppStatTile(
          label: 'Questions',
          value: '${cubit.questionCount}',
          icon: Icons.help_outline_rounded,
        ),
        AppStatTile(
          label: 'Avg accuracy',
          value: avg == null ? '—' : '$avg%',
          icon: Icons.track_changes_outlined,
        ),
        AppStatTile(
          label: 'Highest',
          value: highest == null ? '—' : '$highest%',
          icon: Icons.workspace_premium_outlined,
          shade: TwColors.emerald,
        ),
        AppStatTile(
          label: 'Needs grading',
          value: '${cubit.needsGrading}',
          icon: Icons.edit_note_rounded,
          shade: TwColors.amber,
        ),
      ],
    );
  }
}

/// One bar per auto-graded question. Coding and subjective questions carry no
/// accuracy, so they are left out rather than plotted as zero.
class _AccuracyChart extends StatelessWidget {
  const _AccuracyChart({required this.stats});

  final List<QuestionStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;

    final graded = [
      for (final stat in stats)
        if (stat.isAutoGraded) stat,
    ];
    if (graded.isEmpty) return const SizedBox.shrink();

    return AppSectionCard(
      title: 'Accuracy by question',
      subtitle: 'Auto-graded questions only',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: 100,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: scheme.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 25,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  // Labels collide once a paper runs long, so they thin out
                  // the same way the rating chart's do.
                  interval: (graded.length / 6).ceilToDouble(),
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= graded.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Q${index + 1}',
                        style:
                            theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.card,
                tooltipBorderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${graded[group.x].accuracy}%',
                  theme.textTheme.labelSmall?.copyWith(
                        color: scheme.foreground,
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < graded.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: (graded[i].accuracy ?? 0).toDouble(),
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                      color: tokens
                          .tone(
                            QuestionStatShade.forAccuracy(
                              graded[i].accuracy ?? 0,
                            ),
                          )
                          .foreground,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.stat, required this.index});

  final QuestionStat stat;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primaryForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stat.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(
                // "Manual" rather than 0% — the server did not score these,
                // so an accuracy would be a lie.
                stat.isAutoGraded ? '${stat.accuracy}%' : 'Manual',
                shade: stat.isAutoGraded
                    ? QuestionStatShade.forAccuracy(stat.accuracy!)
                    : TwColors.slate,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(QuestionType.label(stat.type), dense: true),
              AppBadge('${stat.points} pts', dense: true),
              AppBadge('${stat.totalResponses} responses', dense: true),
            ],
          ),
          const SizedBox(height: 12),
          if (stat.isChoice && stat.options.isNotEmpty)
            for (final option in stat.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionBar(option: option),
              )
          else
            _ManualNote(type: stat.type),
          if (stat.hasResults) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                _Tally(
                  label: 'Correct',
                  count: stat.correct,
                  shade: TwColors.emerald,
                ),
                const SizedBox(width: 14),
                _Tally(
                  label: 'Incorrect',
                  count: stat.incorrect,
                  shade: TwColors.rose,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({required this.option});

  final QuestionOptionStat option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(TwColors.emerald);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: option.isCorrect ? tone.background : null,
        border: Border.all(
          color: option.isCorrect
              ? tone.foreground.withValues(alpha: 0.35)
              : scheme.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (option.isCorrect) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: tone.foreground,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: InlineMarkdown(
                  option.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: option.isCorrect
                        ? scheme.foreground
                        : scheme.mutedForeground,
                    fontWeight:
                        option.isCorrect ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${option.percent}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: option.percent / 100,
                    minHeight: 5,
                    backgroundColor: scheme.muted,
                    valueColor: AlwaysStoppedAnimation(
                      option.isCorrect
                          ? tone.foreground
                          : scheme.mutedForeground.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${option.count} resp',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualNote extends StatelessWidget {
  const _ManualNote({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 15,
            color: scheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type == QuestionType.coding
                  ? 'Coding question — graded manually.'
                  : 'Open-ended question — graded manually.',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.label,
    required this.count,
    required this.shade,
  });

  final String label;
  final int count;
  final TwShade shade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(shade);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: tone.foreground,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text('$label $count', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
