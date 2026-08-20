import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';

/// Twelve mini-months, one column on a phone. A day with anything scheduled
/// carries a dot; tapping a month opens it.
class CalendarYearView extends StatelessWidget {
  const CalendarYearView({
    super.key,
    required this.year,
    required this.entries,
    required this.onTapMonth,
    this.bottomPadding = 0,
  });

  final int year;
  final List<CalendarEntry> entries;
  final ValueChanged<DateTime> onTapMonth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    // One pass over the year's entries; each mini-month then just asks the set.
    final busy = <String>{
      for (final entry in entries)
        '${entry.start.year}-${entry.start.month}-${entry.start.day}',
    };

    return ListView.separated(
      // Opted out of the PrimaryScrollController so this does not drive the
      // shell's collapsing app bar. This page has a fixed header of its own,
      // and a collapsing bar slides the whole body — header included — up
      // under the status bar.
      primary: false,
      padding: EdgeInsets.fromLTRB(2, 4, 2, 16 + bottomPadding),
      itemCount: 12,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final month = DateTime(year, index + 1);
        return _MiniMonth(
          month: month,
          busy: busy,
          onTap: () => onTapMonth(month),
        );
      },
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.busy,
    required this.onTap,
  });

  final DateTime month;
  final Set<String> busy;
  final VoidCallback onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final today = DateTime.now();

    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // `weekday` is 1 (Mon) … 7 (Sun); the grid starts on Monday.
    final leading = first.weekday - DateTime.monday;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat('MMMM').format(month),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final letter in _letters)
                Expanded(
                  child: Center(
                    child: Text(letter, style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + column - leading + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 26);
                        }
                        final day = DateTime(month.year, month.month, dayNumber);
                        final isToday = CalendarDates.isSameDay(day, today);
                        final isBusy =
                            busy.contains('${day.year}-${day.month}-${day.day}');
                        return SizedBox(
                          height: 26,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday
                                      ? scheme.primary
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  '$dayNumber',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: isToday
                                        ? scheme.primaryForeground
                                        : scheme.foreground,
                                    fontWeight: isToday ? FontWeight.w600 : null,
                                  ),
                                ),
                              ),
                              // Suppressed under today's filled circle, where it
                              // would read as a smudge.
                              SizedBox(
                                height: 4,
                                child: isBusy && !isToday
                                    ? Center(
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
