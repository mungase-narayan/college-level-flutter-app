import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/utils/heatmap_calendar.dart';

/// Pure calendar rules — no widget pumping, so these are fast and cover the part
/// that is genuinely easy to get wrong.
void main() {
  group('rowOf', () {
    test('puts Sunday on row 0 and Saturday on row 6', () {
      // 1–7 Mar 2026 is a full Sun→Sat week.
      const expected = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6};
      for (final entry in expected.entries) {
        expect(
          HeatmapCalendar.rowOf(DateTime(2026, 3, entry.key)),
          entry.value,
          reason: 'Mar ${entry.key}',
        );
      }
    });

    test('weekStart returns the Sunday on or before a date', () {
      // Aug 1 2026 is a Saturday; its week began Sunday Jul 26.
      expect(
        HeatmapCalendar.weekStart(DateTime(2026, 8)),
        DateTime(2026, 7, 26),
      );
      // A Sunday is its own week start.
      expect(
        HeatmapCalendar.weekStart(DateTime(2026, 3)),
        DateTime(2026, 3),
      );
    });
  });

  group('date arithmetic', () {
    test('addDays crosses month and year boundaries', () {
      expect(HeatmapCalendar.addDays(DateTime(2026, 1, 31), 1),
          DateTime(2026, 2));
      expect(HeatmapCalendar.addDays(DateTime(2026, 12, 31), 1),
          DateTime(2027));
      expect(HeatmapCalendar.addDays(DateTime(2026, 3), -1),
          DateTime(2026, 2, 28));
    });

    test('addDays does not drift across a DST transition', () {
      // Adding 24 *hours* across a fall-back lands at 23:00 the previous day, which
      // would silently duplicate a cell. Rebuilding from components cannot.
      for (final start in [
        DateTime(2026, 3, 7), // around northern spring-forward
        DateTime(2026, 11, 1), // around northern fall-back
        DateTime(2026, 4, 4), // around southern transitions
        DateTime(2026, 10, 3),
      ]) {
        for (var i = 1; i <= 8; i++) {
          final result = HeatmapCalendar.addDays(start, i);
          expect(result.hour, 0, reason: '$start + $i lost midnight');
          expect(
            HeatmapCalendar.daysBetween(start, result),
            i,
            reason: '$start + $i drifted',
          );
        }
      }
    });

    test('lastDayOfMonth handles February, leap years and December', () {
      expect(HeatmapCalendar.lastDayOfMonth(DateTime(2026, 2)).day, 28);
      expect(HeatmapCalendar.lastDayOfMonth(DateTime(2028, 2)).day, 29);
      expect(HeatmapCalendar.lastDayOfMonth(DateTime(2026, 12)),
          DateTime(2026, 12, 31));
    });
  });

  group('layout stops at today', () {
    // The scenario from the report: today is Tue 4 Aug 2026, and Aug 1 is a
    // Saturday. The API returns the whole month, through Aug 31.
    final today = DateTime(2026, 8, 4);

    test('the current month ends on today, not on the payload', () {
      final months = HeatmapCalendar.layout(
        first: DateTime(2026, 7),
        last: DateTime(2026, 8, 31), // future days included, as the API sends them
        today: today,
      );

      final august = months.last;
      expect(august.month, DateTime(2026, 8));
      expect(august.lastDay, today, reason: 'must not render past today');
      expect(august.dayCount, 4, reason: 'Aug 1, 2, 3, 4 only');

      // Two columns: Aug 1 alone in the first, Aug 2–4 in the second.
      expect(august.columns, 2);
      expect(august.gridStart, DateTime(2026, 7, 26));
    });

    test('the exact cell grid for 4 Aug 2026', () {
      final august = HeatmapCalendar.layout(
        first: DateTime(2026, 8),
        last: DateTime(2026, 8, 31),
        today: today,
      ).single;

      // Column 0: blank until Saturday, which is Aug 1.
      for (var row = 0; row < 6; row++) {
        final date = august.dateAt(column: 0, row: row);
        expect(august.renders(date), isFalse, reason: 'col 0 row $row');
      }
      expect(august.dateAt(column: 0, row: 6), DateTime(2026, 8));
      expect(august.renders(DateTime(2026, 8)), isTrue);

      // Column 1: Sun/Mon/Tue are Aug 2/3/4, then placeholders to the week's end.
      expect(august.dateAt(column: 1, row: 0), DateTime(2026, 8, 2));
      expect(august.dateAt(column: 1, row: 1), DateTime(2026, 8, 3));
      expect(august.dateAt(column: 1, row: 2), DateTime(2026, 8, 4));
      for (var row = 0; row <= 2; row++) {
        expect(august.renders(august.dateAt(column: 1, row: row)), isTrue);
      }
      for (var row = 3; row < 7; row++) {
        final date = august.dateAt(column: 1, row: row);
        expect(
          august.renders(date),
          isFalse,
          reason: '$date is in the future and must stay a placeholder',
        );
      }
    });

    test('completed months still render in full', () {
      final july = HeatmapCalendar.layout(
        first: DateTime(2026, 7),
        last: DateTime(2026, 8, 31),
        today: today,
      ).first;

      expect(july.month, DateTime(2026, 7));
      expect(july.lastDay, DateTime(2026, 7, 31));
      expect(july.dayCount, 31, reason: 'a past month is not truncated');
    });

    test('wholly future months produce no block at all', () {
      final months = HeatmapCalendar.layout(
        first: DateTime(2026, 7),
        last: DateTime(2026, 10, 31),
        today: today,
      );

      // Jul and Aug only — Sep and Oct have not begun.
      expect(months.map((m) => m.month.month), [7, 8]);
    });

    test('a range entirely in the future lays out nothing', () {
      expect(
        HeatmapCalendar.layout(
          first: DateTime(2026, 9),
          last: DateTime(2026, 9, 30),
          today: today,
        ),
        isEmpty,
      );
    });

    test('today itself is always included', () {
      final august = HeatmapCalendar.layout(
        first: DateTime(2026, 8),
        last: DateTime(2026, 8, 31),
        today: today,
      ).single;

      expect(august.renders(today), isTrue, reason: 'today is not the future');
    });

    test('a time component on today does not truncate today', () {
      // `DateTime.now()` carries a time; comparing it directly would make every
      // cell "after today" for the rest of the day.
      final august = HeatmapCalendar.layout(
        first: DateTime(2026, 8),
        last: DateTime(2026, 8, 31),
        today: DateTime(2026, 8, 4, 23, 59, 59),
      ).single;

      expect(august.lastDay, DateTime(2026, 8, 4));
      expect(august.dayCount, 4);
    });
  });

  group('layout geometry', () {
    /// Verified weekdays for 2026: Mar 1 Sun, Apr 1 Wed, May 1 Fri, Jun 1 Mon,
    /// Jul 1 Wed, Aug 1 Sat.
    test('each month starts on its first day\'s weekday row', () {
      const expectedRow = {3: 0, 4: 3, 5: 5, 6: 1, 7: 3, 8: 6};

      for (final entry in expectedRow.entries) {
        final month = DateTime(2026, entry.key);
        final block = HeatmapCalendar.layout(
          first: month,
          last: HeatmapCalendar.lastDayOfMonth(month),
          today: DateTime(2027), // all months complete
        ).single;

        expect(
          HeatmapCalendar.rowOf(block.firstDay),
          entry.value,
          reason: 'month ${entry.key}',
        );
        // (0, row) is the 1st, and everything above it is a placeholder.
        expect(block.dateAt(column: 0, row: entry.value), month);
      }
    });

    test('a mid-month range start yields a partial first block', () {
      final months = HeatmapCalendar.layout(
        first: DateTime(2026, 3, 15),
        last: DateTime(2026, 4, 30),
        today: DateTime(2027),
      );

      expect(months.first.firstDay, DateTime(2026, 3, 15));
      expect(months.first.dayCount, 17, reason: 'Mar 15–31');
      expect(months.last.dayCount, 30, reason: 'all of April');
    });

    test('columns cover every day and no more', () {
      var month = DateTime(2025, 9);
      while (!month.isAfter(DateTime(2026, 8))) {
        final block = HeatmapCalendar.layout(
          first: month,
          last: HeatmapCalendar.lastDayOfMonth(month),
          today: DateTime(2027),
        ).single;

        final cells = block.columns * 7;
        final used = HeatmapCalendar.rowOf(block.firstDay) + block.dayCount;

        expect(used, lessThanOrEqualTo(cells), reason: '$month overflows');
        // And not a wasted column: dropping one would not fit.
        expect(used, greaterThan(cells - 7), reason: '$month has a spare column');

        month = DateTime(month.year, month.month + 1);
      }
    });

    test('spans a year boundary in order', () {
      final months = HeatmapCalendar.layout(
        first: DateTime(2025, 11, 15),
        last: DateTime(2026, 2, 10),
        today: DateTime(2027),
      );

      expect(
        months.map((m) => '${m.month.year}-${m.month.month}'),
        ['2025-11', '2025-12', '2026-1', '2026-2'],
      );
    });
  });
}
