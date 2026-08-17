import 'package:equatable/equatable.dart';

import 'calendar_entry.dart';

/// The four grids the web offers, in switcher order.
enum CalendarViewMode { day, week, month, year }

extension CalendarViewModeX on CalendarViewMode {
  String get wire => name;

  String get label => switch (this) {
        CalendarViewMode.day => 'Day',
        CalendarViewMode.week => 'Week',
        CalendarViewMode.month => 'Month',
        CalendarViewMode.year => 'Year',
      };
}

/// The filter strip. Filtering is done entirely on the client, and must stay
/// that way: the endpoint's `type` parameter rejects `class` outright and
/// silently drops the whole timetable for any other value, so sending it would
/// make every class disappear.
enum CalendarFilter { all, classes, event, meeting, task }

extension CalendarFilterX on CalendarFilter {
  String get label => switch (this) {
        CalendarFilter.all => 'All Scheduled',
        CalendarFilter.classes => 'Classes',
        CalendarFilter.event => 'Events',
        CalendarFilter.meeting => 'Meetings',
        CalendarFilter.task => 'Task Reminders',
      };

  /// Note `classes` matches on the *source*, not the type — the web does the
  /// same, and it is the only reading that survives a class row whose type
  /// string ever changes.
  bool matches(CalendarEntry entry) => switch (this) {
        CalendarFilter.all => true,
        CalendarFilter.classes => entry.source == CalendarSource.timetable,
        CalendarFilter.event => entry.type == CalendarEntryType.event,
        CalendarFilter.meeting => entry.type == CalendarEntryType.meeting,
        CalendarFilter.task => entry.type == CalendarEntryType.task,
      };
}

/// The `from`/`to` window a view asks the server for.
class CalendarRange extends Equatable {
  const CalendarRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  /// Every day in the window, midnight-anchored — the grid's cells.
  List<DateTime> get days {
    final result = <DateTime>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!cursor.isAfter(last)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  @override
  List<Object?> get props => [from, to];
}

/// Date maths shared by the cubit and the grids. A direct port of
/// `components/calendar/utils.ts`, including its Monday week start.
class CalendarDates {
  const CalendarDates._();

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// Monday of [date]'s week (`{ weekStartsOn: 1 }` on the web).
  static DateTime startOfWeek(DateTime date) =>
      startOfDay(date).subtract(Duration(days: date.weekday - DateTime.monday));

  static DateTime endOfWeek(DateTime date) =>
      endOfDay(startOfWeek(date).add(const Duration(days: 6)));

  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) =>
      endOfDay(DateTime(date.year, date.month + 1, 0));

  /// The window a view fetches. The month pads out to whole weeks so the grid
  /// is complete — the leading and trailing cells are real days with real
  /// entries, not blanks.
  static CalendarRange rangeFor(CalendarViewMode view, DateTime date) =>
      switch (view) {
        CalendarViewMode.day => CalendarRange(startOfDay(date), endOfDay(date)),
        CalendarViewMode.week =>
          CalendarRange(startOfWeek(date), endOfWeek(date)),
        CalendarViewMode.month => CalendarRange(
            startOfWeek(startOfMonth(date)),
            endOfWeek(endOfMonth(date)),
          ),
        CalendarViewMode.year => CalendarRange(
            DateTime(date.year),
            endOfDay(DateTime(date.year, 12, 31)),
          ),
      };

  /// Steps the anchor by one unit of the current view.
  static DateTime shift(CalendarViewMode view, DateTime date, int delta) =>
      switch (view) {
        CalendarViewMode.day =>
          DateTime(date.year, date.month, date.day + delta),
        CalendarViewMode.week =>
          DateTime(date.year, date.month, date.day + delta * 7),
        CalendarViewMode.month => _clampedDay(date.year, date.month + delta, date.day),
        CalendarViewMode.year => _clampedDay(date.year + delta, date.month, date.day),
      };

  /// `DateTime(2026, 2, 31)` rolls forward into March, which would make "next
  /// month" from the 31st skip February entirely. date-fns `addMonths` clamps
  /// instead, so this does too.
  static DateTime _clampedDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day < lastDay ? day : lastDay);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
