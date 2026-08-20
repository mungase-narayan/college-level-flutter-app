import 'package:college_level/core/common/widgets/app_stat_tile.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dashboard panels live inside a `SingleChildScrollView`, so their vertical
/// constraint is unbounded. A widget that needs a finite height there — a Row
/// with `CrossAxisAlignment.stretch`, or a grid whose height is derived from an
/// aspect ratio — throws during layout and takes the whole screen down with it,
/// which is exactly how the dashboard once rendered blank.
///
/// These tests pump the stat widgets in that unbounded context and fail if any
/// layout exception is raised.
Widget _unbounded(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

List<Widget> _tiles(int count) => [
      for (var i = 0; i < count; i++)
        AppStatTile(
          label: 'A deliberately long stat label $i',
          value: '1,234',
          caption: 'a caption that also runs long',
          icon: Icons.check_circle_outline_rounded,
        ),
    ];

void main() {
  group('AppStatGrid in an unbounded scroll view', () {
    testWidgets('lays out stacked (columns: 1) without overflowing',
        (tester) async {
      await tester.pumpWidget(
        _unbounded(AppStatGrid(columns: 1, tiles: _tiles(3))),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppStatTile), findsNWidgets(3));
    });

    testWidgets('lays out two-per-row without overflowing', (tester) async {
      await tester.pumpWidget(
        _unbounded(AppStatGrid(tiles: _tiles(4))),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppStatTile), findsNWidgets(4));
    });

    testWidgets('survives three columns, where an aspect ratio would clip',
        (tester) async {
      await tester.pumpWidget(
        _unbounded(AppStatGrid(columns: 3, tiles: _tiles(3))),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a lone trailing tile fills the row instead of leaving a hole',
        (tester) async {
      // Three tiles in two columns. The odd one out used to sit at half width
      // with dead space beside it, which reads as a card that failed to load.
      await tester.pumpWidget(_unbounded(AppStatGrid(tiles: _tiles(3))));

      expect(tester.takeException(), isNull);
      final tiles = find.byType(AppStatTile);
      expect(tiles, findsNWidgets(3));

      final first = tester.getSize(tiles.at(0)).width;
      final third = tester.getSize(tiles.at(2)).width;

      // The stranded tile spans both columns plus the gutter between them.
      expect(third, greaterThan(first));
      expect(third, moreOrLessEquals(first * 2 + 12, epsilon: 0.5));
    });

    testWidgets('a full last row still splits evenly', (tester) async {
      await tester.pumpWidget(_unbounded(AppStatGrid(tiles: _tiles(4))));

      final widths = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byType(AppStatTile).at(i)).width,
      ];

      expect(widths.toSet(), hasLength(1));
    });

    testWidgets('tiles without captions do not carry a captioned tile\'s height',
        (tester) async {
      // The course-detail grid has no captions on any of its five tiles. With a
      // fixed extent they each kept the empty band a caption would have filled,
      // which read on screen as a large unexplained gap under every number.
      List<Widget> plain(int count) => [
            for (var i = 0; i < count; i++)
              AppStatTile(label: 'Credits $i', value: '3', icon: Icons.star),
          ];

      await tester.pumpWidget(_unbounded(AppStatGrid(tiles: plain(2))));
      final withoutCaption =
          tester.getSize(find.byType(AppStatTile).first).height;

      await tester.pumpWidget(_unbounded(AppStatGrid(tiles: _tiles(2))));
      final withCaption = tester.getSize(find.byType(AppStatTile).first).height;

      expect(withoutCaption, lessThan(withCaption));
    });

    testWidgets('tiles in one row share the tallest tile\'s height',
        (tester) async {
      // Mixed captions in a row must still line up, or the row edge goes ragged.
      await tester.pumpWidget(
        _unbounded(
          AppStatGrid(
            tiles: [
              const AppStatTile(label: 'Plain', value: '1'),
              const AppStatTile(
                label: 'Captioned',
                value: '2',
                caption: 'a caption',
              ),
            ],
          ),
        ),
      );

      final first = tester.getSize(find.byType(AppStatTile).at(0)).height;
      final second = tester.getSize(find.byType(AppStatTile).at(1)).height;
      expect(first, second);
    });

    testWidgets('tile height does not shrink as columns increase',
        (tester) async {
      await tester.pumpWidget(_unbounded(AppStatGrid(tiles: _tiles(2))));
      final twoCol = tester.getSize(find.byType(AppStatTile).first).height;

      await tester.pumpWidget(
        _unbounded(AppStatGrid(columns: 3, tiles: _tiles(3))),
      );
      final threeCol = tester.getSize(find.byType(AppStatTile).first).height;

      // A childAspectRatio grid would make the three-column tiles shorter and
      // overflow their content; a fixed main-axis extent keeps them equal.
      expect(threeCol, twoCol);
    });
  });
}
