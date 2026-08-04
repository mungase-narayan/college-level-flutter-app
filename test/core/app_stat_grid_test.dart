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
