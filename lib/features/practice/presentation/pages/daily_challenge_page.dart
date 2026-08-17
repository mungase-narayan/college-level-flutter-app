import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/daily_challenge.dart';
import '../bloc/daily_challenge_cubit.dart';

/// Port of `src/pages/student/practice/daily-challenge.tsx` — the hub.
///
/// The web lays this out in two columns and hides the history below `lg`, which
/// on a phone would mean never seeing it at all. Here everything stacks and the
/// history stays.
class DailyChallengePage extends StatefulWidget {
  const DailyChallengePage({super.key});

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage> {
  @override
  void initState() {
    super.initState();
    context.read<DailyChallengeCubit>().load();
  }

  void _open(String date) => context.push('/student/daily-challenge/$date');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailyChallengeCubit>();
    final glassInsets = context.glassContentInsets;

    return StudentScaffold(
      child: RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: RemoteView<DailyChallengeCubit, DailyChallengeHome>(
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsets.all(16),
            child: AppListSkeleton(rows: 3),
          ),
          builder: (context, home) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + glassInsets.bottom),
            children: [
              _Hero(challenge: home.today, onSolve: _open),
              const SizedBox(height: 14),
              _CalendarCard(
                calendar: home.calendar,
                isLoading: home.isMonthLoading,
                onShiftMonth: cubit.shiftMonth,
                onPickDay: _open,
              ),
              if (home.calendar != null) ...[
                const SizedBox(height: 14),
                _MonthlyBadgeCard(summary: home.calendar!.summary),
              ],
              const SizedBox(height: 18),
              Text(
                'Recent challenges',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (home.history.isEmpty)
                const AppEmptyState(
                  title: 'No past challenges yet',
                  description: 'Your daily challenge history will appear here.',
                  icon: Icons.calendar_month_outlined,
                )
              else
                for (final day in home.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryRow(day: day, onTap: () => _open(day.date)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Streak, the day's state, and the one call to action.
class _Hero extends StatelessWidget {
  const _Hero({required this.challenge, required this.onSolve});

  final DailyChallenge challenge;
  final ValueChanged<String> onSolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final set = challenge.set;
    final completion = challenge.completion;
    final attempted = completion?.attemptedQuestionIds.length ?? 0;
    final isCompleted = challenge.isCompleted;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [TwColors.orange.s500, TwColors.amber.s500],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Challenge', style: theme.textTheme.titleMedium),
                    Text(
                      'Keep your streak alive — a fresh set every day.',
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
              _Stat(
                value: '${challenge.streak.currentStreak}',
                label: 'day streak',
                icon: Icons.local_fire_department_rounded,
                shade: TwColors.orange,
              ),
              const SizedBox(width: 10),
              // The +10 is the reward for finishing the *set*, so it stops
              // being an incentive the moment the set is done.
              if (set != null && !isCompleted)
                _Stat(
                  value: '+10',
                  label: 'points on completion',
                  icon: Icons.star_rounded,
                  shade: TwColors.amber,
                ),
            ],
          ),
          if (completion != null && !isCompleted && set != null) ...[
            const SizedBox(height: 12),
            _ProgressBar(
              fraction: completion.fraction,
              label: '${completion.solvedCount} of ${set.totalQuestions} solved',
            ),
          ],
          const SizedBox(height: 14),
          if (challenge.available && set != null)
            AppButton(
              label: isCompleted
                  ? "Review today's challenge"
                  : attempted > 0
                      ? "Continue today's challenge"
                      : "Solve today's challenge",
              icon: isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.local_fire_department_rounded,
              expand: true,
              // The server's date, never a locally computed one: it buckets
              // days in IST, so a phone in another timezone would ask for the
              // wrong day late in the evening.
              onPressed: () => onSolve(set.date),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                // The payload cannot say which of the two it is — no set
                // posted, or no semester on the profile — so the copy covers
                // both without guessing.
                'No challenge today — keep your streak alive tomorrow.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.shade,
  });

  final String value;
  final String label;
  final IconData icon;
  final TwShade shade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(shade);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: tone.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: tone.foreground),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: scheme.muted,
          ),
        ),
      ],
    );
  }
}

/// The month grid.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.calendar,
    required this.isLoading,
    required this.onShiftMonth,
    required this.onPickDay,
  });

  final DailyCalendar? calendar;
  final bool isLoading;
  final ValueChanged<int> onShiftMonth;
  final ValueChanged<String> onPickDay;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendar = this.calendar;

    if (calendar == null) {
      return const AppCard(child: AppSkeleton(height: 220));
    }

    final summary = calendar.summary;
    final month = _parseMonth(calendar.month);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      month == null
                          ? calendar.month
                          : Fmt.monthYear(month),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      summary.postedCount > 0
                          ? '${summary.completedCount} of ${summary.postedCount} completed'
                          : 'No challenges',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : () => onShiftMonth(-1),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: isLoading ? null : () => onShiftMonth(1),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: isLoading ? 0.5 : 1,
            child: _MonthGrid(
              calendar: calendar,
              month: month,
              onPickDay: isLoading ? (_) {} : onPickDay,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _LegendDot(label: 'Completed', shade: TwColors.emerald),
              _LegendDot(label: 'In progress', shade: TwColors.amber),
              _LegendDot(label: 'Missed', shade: TwColors.rose),
            ],
          ),
        ],
      ),
    );
  }

  /// `YYYY-MM` → a date on the first of that month, or null if malformed.
  static DateTime? _parseMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts.first);
    final index = int.tryParse(parts.last);
    if (year == null || index == null) return null;
    return DateTime(year, index);
  }

  static const _weekdayLabels = _weekdays;
}

/// Row height of the month grid, and the diameter of the circle inside it —
/// the two are the same number so a completed day is a circle rather than an
/// oval, and so a row is no taller than the date it shows.
const double _dayCellExtent = 38;

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.calendar,
    required this.month,
    required this.onPickDay,
  });

  final DailyCalendar calendar;
  final DateTime? month;
  final ValueChanged<String> onPickDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final month = this.month;
    if (month == null) return const SizedBox.shrink();

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // `weekday` is 1..7 from Monday; the grid starts on Sunday.
    final leading = DateTime(month.year, month.month).weekday % 7;

    return Column(
      children: [
        Row(
          children: [
            for (final label in _CalendarCard._weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Load-bearing. A `BoxScrollView` with null padding silently adopts
          // `MediaQuery.padding` — so this grid was padding itself with the
          // status bar's 59pt at the top and the home indicator's 34pt at the
          // bottom, which is the gap under the weekday row and above the
          // legend. `AppStatGrid` zeroes it for the same reason.
          padding: EdgeInsets.zero,
          // `mainAxisExtent`, not an aspect ratio: across seven columns a
          // square cell is as tall as the card is wide over seven, which left
          // each date floating in ~76pt of empty row — and stacked that gap
          // above the first row and below the last. The row is now the height
          // of the day circle it holds.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            mainAxisExtent: _dayCellExtent,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();

            final day = index - leading + 1;
            final date = '${month.year.toString().padLeft(4, '0')}-'
                '${month.month.toString().padLeft(2, '0')}-'
                '${day.toString().padLeft(2, '0')}';
            final entry = calendar.dayOn(date);

            // A day with nothing posted is inert — no dot, no tap, and no
            // tooltip promising something that is not there.
            if (entry == null) {
              return Center(
                child: Text(
                  '$day',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.mutedForeground.withValues(alpha: 0.4),
                  ),
                ),
              );
            }

            return _DayCell(
              day: day,
              entry: entry,
              onTap: () => onPickDay(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.entry, required this.onTap});

  final int day;
  final DailyChallengeDay entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isDone = entry.status == 'completed';

    final dot = switch (entry.status) {
      'in_progress' => TwColors.amber,
      'missed' => TwColors.rose,
      _ => null,
    };

    return Tooltip(
      message: '${entry.title} — ${entry.solvedCount}/${entry.totalQuestions} solved',
      // Sized rather than filling the cell: a grid column is wider than a row
      // is tall, so a stretched circle comes out an oval.
      child: Center(
        child: SizedBox.square(
          dimension: _dayCellExtent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? tokens.tone(TwColors.emerald).background
                    : Colors.transparent,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isDone)
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: tokens.tone(TwColors.emerald).foreground,
                    )
                  else
                    // Nudged up by the dot's height so the number stays
                    // optically centred in the circle.
                    Padding(
                      padding: EdgeInsets.only(bottom: dot == null ? 0 : 6),
                      child: Text('$day', style: theme.textTheme.labelMedium),
                    ),
                  if (dot != null)
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: tokens.tone(dot).foreground,
                          shape: BoxShape.circle,
                        ),
                      ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.shade});

  final String label;
  final TwShade shade;

  @override
  Widget build(BuildContext context) {
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
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// The monthly badge, and how close the student is to it.
class _MonthlyBadgeCard extends StatelessWidget {
  const _MonthlyBadgeCard({required this.summary});

  final DailyCalendarSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Earned only once the month has closed with every posted day completed.
    // While it is still open the badge is in progress, not lost.
    final earned = summary.perfect && summary.isClosed;
    final onTrack = !summary.isClosed && summary.completedCount > 0;

    final (shade, icon) = earned
        ? (TwColors.amber, Icons.workspace_premium_rounded)
        : onTrack
            ? (TwColors.amber, Icons.emoji_events_outlined)
            : (TwColors.slate, Icons.lock_outline_rounded);
    final tone = tokens.tone(shade);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 21, color: tone.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly badge', style: theme.textTheme.titleSmall),
                Text(
                  'Complete every daily challenge this month to earn it.',
                  style: theme.textTheme.labelSmall,
                ),
                if (summary.postedCount > 0) ...[
                  const SizedBox(height: 8),
                  _ProgressBar(
                    fraction: summary.completedCount / summary.postedCount,
                    label:
                        '${summary.completedCount}/${summary.postedCount} days',
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.day, required this.onTap});

  final DailyChallengeDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final (shade, label) = switch (day.status) {
      'completed' => (TwColors.emerald, 'Completed'),
      'in_progress' => (TwColors.amber, 'In progress'),
      'missed' => (TwColors.rose, 'Missed'),
      _ => (TwColors.slate, 'Upcoming'),
    };

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            day.status == 'completed'
                ? Icons.check_circle_rounded
                : Icons.calendar_today_rounded,
            size: 20,
            color: tokens.tone(shade).foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Fmt.longDate(day.date)} · '
                  '${day.solvedCount}/${day.totalQuestions} solved',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppBadge(label, shade: shade, dense: true),
        ],
      ),
    );
  }
}
