import 'package:flutter/foundation.dart';

/// Date arithmetic and month layout for the contribution heatmap.
///
/// Pure Dart with no widget or `BuildContext` dependency, so the calendar rules —
/// which are the part that is easy to get subtly wrong — are unit-testable without
/// pumping a widget, and the layout can be precomputed once per data change rather
/// than recomputed on every rebuild.
///
/// ### Conventions
///
/// * Rows are weekdays with **Sunday at row 0** and Saturday at row 6.
/// * Columns are weeks. Cell `(column, row)` of a month is
///   `gridStart + (column * 7 + row)` days, which makes row ≡ weekday by
///   construction rather than by arithmetic that could drift.
/// * Nothing after **today** is ever laid out, no matter what the API sends.
abstract final class HeatmapCalendar {
  /// Strips the time component. Every date in this file is midnight local.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Row index of [date]: Sunday 0 … Saturday 6.
  ///
  /// `DateTime.weekday` is Mon=1…Sun=7, so `% 7` maps Sunday to 0 and shifts the
  /// rest down by one — which is exactly the row order the grid renders.
  static int rowOf(DateTime date) => date.weekday % 7;

  /// Adds [days] without DST drift.
  ///
  /// `date.add(Duration(days: 1))` adds 24 *hours*, so across a fall-back
  /// transition it lands at 23:00 on the **same** day and the grid silently
  /// duplicates a cell. Rebuilding the date from its components cannot drift.
  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// The Sunday on or before [date].
  static DateTime weekStart(DateTime date) => addDays(date, -rowOf(date));

  /// Whole days from [from] to [to]. Built in UTC so DST cannot make a day 23 or
  /// 25 hours long and round the wrong way.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  /// Last day of [date]'s month.
  ///
  /// Day 0 of the following month is the last day of this one, and Dart normalises
  /// the month overflow — so December needs no special case.
  static DateTime lastDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0);

  static DateTime firstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static DateTime earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  static DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Lays out `[first, last]` as one [HeatmapMonth] per calendar month.
  ///
  /// [today] caps the whole grid. Cells are generated up to
  /// `min(last, today)` and no further, so the remaining weekdays of the current
  /// week render as empty placeholders instead of as zero-activity days that have
  /// not happened yet — matching GitHub.
  ///
  /// That cap is deliberately taken from the clock rather than from the payload:
  /// the API returns whole months, including days still to come, so trusting
  /// `last` alone renders the rest of the month as real cells.
  ///
  /// Months entirely after [today] produce no block at all. A labelled but wholly
  /// empty column would only take space to say "nothing has happened yet, and
  /// could not have".
  static List<HeatmapMonth> layout({
    required DateTime first,
    required DateTime last,
    required DateTime today,
  }) {
    final from = dateOnly(first);
    final visibleEnd = earlier(dateOnly(last), dateOnly(today));

    // The entire range is in the future, or the range is inverted.
    if (visibleEnd.isBefore(from)) return const [];

    final months = <HeatmapMonth>[];
    var cursor = firstDayOfMonth(from);
    final lastMonth = firstDayOfMonth(visibleEnd);

    while (!cursor.isAfter(lastMonth)) {
      final monthEnd = lastDayOfMonth(cursor);

      // Clamped at both ends: a range starting mid-month renders a partial first
      // block rather than inventing days, and the current month stops at today.
      final firstDay = later(cursor, from);
      final lastDay = earlier(monthEnd, visibleEnd);

      if (!firstDay.isAfter(lastDay)) {
        final gridStart = weekStart(firstDay);
        final span = daysBetween(gridStart, lastDay) + 1;

        months.add(
          HeatmapMonth(
            month: cursor,
            gridStart: gridStart,
            firstDay: firstDay,
            lastDay: lastDay,
            columns: (span / 7).ceil(),
          ),
        );
      }

      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return months;
  }
}

/// The precomputed layout of one calendar month.
///
/// Each month is its own small calendar rather than a slice of one continuous
/// strip, which is what lets a month whose 1st falls mid-week start part-way down
/// its first column.
@immutable
class HeatmapMonth {
  const HeatmapMonth({
    required this.month,
    required this.gridStart,
    required this.firstDay,
    required this.lastDay,
    required this.columns,
  });

  /// First of the month. Used for the axis label.
  final DateTime month;

  /// The Sunday on or before [firstDay] — the origin cell (0, 0) maps to.
  final DateTime gridStart;

  /// First and last day this block actually renders. [lastDay] is never after
  /// today.
  final DateTime firstDay;
  final DateTime lastDay;

  /// Week columns needed to cover [gridStart] → [lastDay].
  final int columns;

  /// The date at a grid position, whether or not it belongs to this block.
  DateTime dateAt({required int column, required int row}) =>
      HeatmapCalendar.addDays(gridStart, column * 7 + row);

  /// Whether [date] is a day this block should paint. Everything else is a
  /// placeholder: days of an adjacent month, and days after today.
  bool renders(DateTime date) =>
      !date.isBefore(firstDay) && !date.isAfter(lastDay);

  /// Days this block paints — the count a test can assert on.
  int get dayCount => HeatmapCalendar.daysBetween(firstDay, lastDay) + 1;

  @override
  bool operator ==(Object other) =>
      other is HeatmapMonth &&
      other.month == month &&
      other.gridStart == gridStart &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay &&
      other.columns == columns;

  @override
  int get hashCode => Object.hash(month, gridStart, firstDay, lastDay, columns);

  @override
  String toString() =>
      'HeatmapMonth(${month.year}-${month.month}, '
      'days ${firstDay.day}–${lastDay.day}, $columns cols)';
}
