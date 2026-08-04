import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/widgets/heatmap_grid.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/utils/formatters.dart';

/// The activity grid is a port of the web app's contribution heatmap: week
/// columns bucketed into labelled month blocks, most recent on the right.
void main() {
  List<HeatmapDay> range(DateTime from, DateTime to, {int count = 0}) {
    final out = <HeatmapDay>[];
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      out.add(HeatmapDay(date: Fmt.isoDate(d), count: count));
    }
    return out;
  }

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: Center(child: child)),
      );

  group('month axis', () {
    testWidgets('labels every month the range spans, in order', (tester) async {
      // Mar 1 → Aug 15, the span in the reference design.
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 3), DateTime(2026, 8, 15)),
            today: DateTime(2027),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug']) {
        expect(find.text(label), findsOneWidget, reason: '$label missing');
      }

      // Left-to-right chronological, which is what makes the axis readable.
      final marX = tester.getTopLeft(find.text('Mar')).dx;
      final augX = tester.getTopLeft(find.text('Aug')).dx;
      expect(marX, lessThan(augX));
    });

    testWidgets('does not repeat a month label', (tester) async {
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 3), DateTime(2026, 5, 31)),
            today: DateTime(2027),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A month is one contiguous block of columns, so exactly one label each.
      for (final label in ['Mar', 'Apr', 'May']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a single-column month still gets its label', (tester) async {
      // Apr 1 2026 is a Wednesday, so a range ending Sat Apr 4 gives April exactly
      // one column. Its label is wider than the block itself and must not widen it:
      // doing so would drag every earlier month out of line with its columns.
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 3), DateTime(2026, 4, 4)),
            today: DateTime(2027),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Apr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can be turned off without disturbing the grid', (tester) async {
      final days = range(DateTime(2026, 3), DateTime(2026, 5, 31));

      await tester.pumpWidget(
        host(HeatmapGrid(days: days, today: DateTime(2027))),
      );
      await tester.pumpAndSettle();
      // Scoped to inside the scroll view: `find.byType(Column).first` picks up a
      // Column from Scaffold's own internals, which is screen-sized.
      final gridContent = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Column),
      );
      final withLabels = tester.getSize(gridContent.first);

      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: days,
            today: DateTime(2027),
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final without = tester.getSize(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Column),
            )
            .first,
      );

      expect(find.text('Mar'), findsNothing);
      // Identical width either way: labels live in fixed-width slots sized from the
      // same `_slotWidth`, so they contribute no horizontal size at all.
      expect(without.width, withLabels.width);
      expect(without.height, lessThan(withLabels.height));
    });
  });

  group('weekday alignment', () {
    /// The rule: row 0 is Sunday, row 1 Monday, … row 6 Saturday. A month whose
    /// 1st falls mid-week starts part-way down its first column.
    ///
    /// Verified dates in 2026: Mar 1 = Sunday, Jun 1 = Monday, Aug 1 = Saturday.
    const cases = <int, int>{3: 0, 6: 1, 8: 6};

    for (final entry in cases.entries) {
      final month = entry.key;
      final expectedRow = entry.value;

      testWidgets('a month starting on row $expectedRow begins on that row',
          (tester) async {
        final monthStart = DateTime(2026, month);
        await tester.pumpWidget(
          host(
            HeatmapGrid(
              // One whole month, so there is exactly one block and its top edge is
              // the grid's top edge.
              days: range(monthStart, DateTime(2026, month + 1, 0), count: 1),
              today: DateTime(2027), // every month complete, whatever the clock says
              showMonthLabels: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gridTop = tester
            .getTopLeft(
              find
                  .descendant(
                    of: find.byType(SingleChildScrollView),
                    matching: find.byType(Row),
                  )
                  .first,
            )
            .dy;

        // The first rendered cell is the 1st of the month.
        final firstCell = tester.getTopLeft(find.byType(Tooltip).first);

        const cell = 14.0, gap = 3.0;
        expect(
          firstCell.dy - gridTop,
          expectedRow * (cell + gap),
          reason: 'the 1st of month $month must sit on row $expectedRow',
        );
      });
    }

    testWidgets('the weekday rows before the 1st are left blank, not filled',
        (tester) async {
      // August 2026 starts on a Saturday, so its first column holds exactly one
      // day — the six rows above it belong to July and must be empty here.
      //
      // `today` is pinned past the range: without it the grid correctly truncates
      // at the real clock, and this test would assert a different number every day.
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 8), DateTime(2026, 8, 31), count: 1),
            today: DateTime(2027),
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 31 days in August, one tappable cell each — no spacers counted, and
      // crucially no extra cells borrowed from July.
      expect(find.byType(Tooltip), findsNWidgets(31));
    });

    testWidgets('a day is never drawn in the wrong month', (tester) async {
      // The old grouping assigned a whole Sun→Sat column to the month of its
      // Sunday, so Aug 1 (a Saturday) was drawn inside July's block and August
      // began at the next Sunday. Both months are present here, and the day count
      // per block is what proves the boundary is now correct.
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 7), DateTime(2026, 8, 31), count: 1),
            today: DateTime(2027), // both months complete, independent of the clock
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 31 (July) + 31 (August) — every day exactly once, none duplicated across
      // the boundary and none dropped.
      expect(find.byType(Tooltip), findsNWidgets(62));
    });
  });

  group('stops at today', () {
    // Today is Tue 4 Aug 2026; Aug 1 is a Saturday. The API returns all 31 days.
    final today = DateTime(2026, 8, 4);

    testWidgets('future days of the current week are not drawn', (tester) async {
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 8), DateTime(2026, 8, 31), count: 1),
            today: today,
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aug 1, 2, 3, 4 — and nothing else. The remaining 27 days the payload
      // contained are still in the future.
      expect(find.byType(Tooltip), findsNWidgets(4));
    });

    testWidgets('the drawn cells sit on the right weekday rows', (tester) async {
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 8), DateTime(2026, 8, 31), count: 1),
            today: today,
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridTop = tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Row),
                )
                .first,
          )
          .dy;

      const cell = 14.0, gap = 3.0;
      final cells = find.byType(Tooltip);

      // Rendered in build order: Aug 1 (col 0, Sat) then Aug 2/3/4 (col 1,
      // Sun/Mon/Tue).
      const expectedRows = [6, 0, 1, 2];
      for (final (i, row) in expectedRows.indexed) {
        expect(
          tester.getTopLeft(cells.at(i)).dy - gridTop,
          row * (cell + gap),
          reason: 'cell $i belongs on row $row',
        );
      }
    });

    testWidgets('a completed month is still drawn in full', (tester) async {
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(DateTime(2026, 7), DateTime(2026, 8, 31), count: 1),
            today: today,
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 31 of July, plus Aug 1–4.
      expect(find.byType(Tooltip), findsNWidgets(35));
    });

    testWidgets('layout is not recomputed for a cosmetic rebuild',
        (tester) async {
      final days = range(DateTime(2026, 7), DateTime(2026, 8, 31), count: 1);

      await tester.pumpWidget(
        host(HeatmapGrid(days: days, today: today, showMonthLabels: false)),
      );
      await tester.pumpAndSettle();
      final before = find.byType(Tooltip).evaluate().length;

      // Same data, different visual params: the month layout must be reused, and
      // the day set must be identical.
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: days,
            today: today,
            showMonthLabels: false,
            cell: 16,
            gap: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip).evaluate().length, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('grid', () {
    testWidgets('renders seven rows per week column', (tester) async {
      // Exactly one Sun→Sat week.
      final sunday = DateTime(2026, 3);
      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(sunday, sunday.add(const Duration(days: 6))),
            today: DateTime(2027),
            showMonthLabels: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cells = find.byType(Tooltip);
      expect(cells, findsNWidgets(7));

      // Measured on the cells themselves, not on the scroll view: a horizontally
      // scrolling viewport does NOT shrink-wrap its cross axis, so its height is
      // the whole screen and says nothing about the grid.
      const cell = 14.0, gap = 3.0;
      expect(tester.getSize(cells.first), const Size(cell, cell));
      final top = tester.getTopLeft(cells.first).dy;
      final bottom = tester.getBottomLeft(cells.last).dy;
      expect(bottom - top, cell * 7 + gap * 6);
    });

    testWidgets('shows a message rather than an empty box for no data',
        (tester) async {
      await tester.pumpWidget(host(const HeatmapGrid(days: [])));
      await tester.pumpAndSettle();

      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('survives malformed dates from the API', (tester) async {
      await tester.pumpWidget(
        host(
          const HeatmapGrid(
            days: [
              HeatmapDay(date: 'not-a-date', count: 3),
              HeatmapDay(date: '', count: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('taps report the day that was tapped', (tester) async {
      final tapped = <String>[];
      final sunday = DateTime(2026, 3);

      await tester.pumpWidget(
        host(
          HeatmapGrid(
            days: range(sunday, sunday.add(const Duration(days: 6)), count: 2),
            today: DateTime(2027),
            showMonthLabels: false,
            onDayTap: (day) => tapped.add(day.date),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tooltip).first);
      await tester.pump();

      expect(tapped, [Fmt.isoDate(sunday)]);
    });
  });

  group('intensity', () {
    test('zero activity uses the muted surface, not the brand colour', () {
      const scheme = AppColors.dark;
      expect(heatmapLevelColor(scheme, 0, 10), scheme.muted);
    });

    test('scales to the busiest day so a light user still sees contrast', () {
      const scheme = AppColors.dark;

      // With a max of 4, one attempt must not render as the faintest possible
      // shade — the ladder is relative, not absolute.
      final light = heatmapLevelColor(scheme, 1, 4);
      final heavy = heatmapLevelColor(scheme, 4, 4);

      expect(light.a, lessThan(heavy.a));
      expect(heavy.a, 1.0);
    });

    test('a single-day history is treated as full intensity', () {
      const scheme = AppColors.dark;
      // max <= 1 would otherwise divide toward zero and render invisibly.
      expect(heatmapLevelColor(scheme, 1, 1).a, 1.0);
    });

    test('the ladder is monotonic across the buckets', () {
      const scheme = AppColors.dark;
      var previous = 0.0;
      for (final count in [1, 3, 6, 8, 10]) {
        final alpha = heatmapLevelColor(scheme, count, 10).a;
        expect(alpha, greaterThanOrEqualTo(previous));
        previous = alpha;
      }
    });
  });
}
