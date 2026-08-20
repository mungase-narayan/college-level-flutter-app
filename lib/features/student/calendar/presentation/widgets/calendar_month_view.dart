import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The month grid — Monday-start, whole weeks, a few chips per day.
class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    super.key,
    required this.month,
    required this.days,
    required this.entriesOn,
    required this.onTapDay,
    required this.onTapEntry,
    this.bottomPadding = 0,
  });

  /// Any date inside the month being shown — cells outside it are dimmed.
  final DateTime month;

  /// Every day the grid covers, already padded out to whole weeks.
  final List<DateTime> days;

  final List<CalendarEntry> Function(DateTime day) entriesOn;
  final ValueChanged<DateTime> onTapDay;
  final ValueChanged<CalendarEntry> onTapEntry;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final weeks = <List<DateTime>>[
      for (var i = 0; i < days.length; i += 7)
        days.sublist(i, i + 7 > days.length ? days.length : i + 7),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fill the available height when the weeks allow it, but never
              // squeeze a row below what a date and one chip need.
              final rowHeight = (constraints.maxHeight / weeks.length)
                  .clamp(76.0, 132.0);
              final maxChips = rowHeight >= 96 ? 3 : 2;
              final content = Column(
                children: [
                  for (final week in weeks)
                    SizedBox(
                      height: rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final day in week)
                            Expanded(
                              child: _DayCell(
                                day: day,
                                entries: entriesOn(day),
                                inMonth: day.month == month.month &&
                                    day.year == month.year,
                                isToday: CalendarDates.isSameDay(day, today),
                                maxChips: maxChips,
                                onTapDay: () => onTapDay(day),
                                onTapEntry: onTapEntry,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );

              final total = rowHeight * weeks.length;
              if (total <= constraints.maxHeight && bottomPadding == 0) {
                return content;
              }
              return SingleChildScrollView(
                // See the note in CalendarYearView: the page's header is fixed,
                // so its scroll views must not drive the shell's collapsing app
                // bar.
                primary: false,
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: content,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entries,
    required this.inMonth,
    required this.isToday,
    required this.maxChips,
    required this.onTapDay,
    required this.onTapEntry,
  });

  final DateTime day;
  final List<CalendarEntry> entries;
  final bool inMonth;
  final bool isToday;
  final int maxChips;
  final VoidCallback onTapDay;
  final ValueChanged<CalendarEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final visible = entries.take(maxChips).toList(growable: false);
    final hidden = entries.length - visible.length;

    return InkWell(
      onTap: onTapDay,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: inMonth ? null : scheme.muted.withValues(alpha: 0.35),
          border: Border(
            bottom: BorderSide(color: scheme.border.withValues(alpha: 0.4)),
            left: BorderSide(color: scheme.border.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? scheme.primary : Colors.transparent,
                ),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isToday
                        ? scheme.primaryForeground
                        : (inMonth ? scheme.foreground : scheme.mutedForeground),
                    fontWeight: isToday ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Cell height varies with how many weeks the month spans, so the
            // contents lay out naturally and whatever does not fit is clipped
            // rather than reported as an overflow.
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: CalendarEntryChip(
                            entry: entry,
                            onTap: () => onTapEntry(entry),
                          ),
                        ),
                      // Not a button on the web either — it falls through to
                      // the day cell, which is the useful thing to do anyway.
                      if (hidden > 0)
                        Text(
                          '+$hidden more',
                          style:
                              theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact entry pill: accent dot, start time, title.
class CalendarEntryChip extends StatelessWidget {
  const CalendarEntryChip({super.key, required this.entry, required this.onTap});

  final CalendarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = parseHexColor(entry.accentHex)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                entry.isAllDay
                    ? entry.title
                    : '${DateFormat('h:mm').format(entry.start)} ${entry.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
