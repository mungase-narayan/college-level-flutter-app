import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/widgets/widgets.dart';

import '../support/platform_parity.dart';

/// The label names the number, so it is the wrong half to clip. At three
/// columns on a phone the side-by-side layout left it about 40pt.
void main() {
  /// Whether the label ran out of room and got an ellipsis. Asked of the
  /// render object rather than re-measured with a TextPainter, which would
  /// have to reconstruct the inherited style and can disagree with what was
  /// actually painted.
  bool isClipped(WidgetTester t, String text) =>
      (t.renderObject(find.text(text)) as RenderParagraph).didExceedMaxLines;

  bothPlatforms('three columns still show the whole label', (t, h) async {
    await t.pumpWidget(h(const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: AppStatGrid(
          columns: 3,
          tiles: [
            AppStatTile(
              label: 'Marks',
              value: '5',
              icon: Icons.star_outline_rounded,
            ),
            AppStatTile(
              label: 'Attempts',
              value: '1',
              icon: Icons.repeat_rounded,
            ),
            AppStatTile(
              label: 'Time limit',
              value: '30 min',
              icon: Icons.timer_outlined,
            ),
          ],
        ),
      ),
    )));
    await t.pumpAndSettle();

    for (final label in ['Marks', 'Attempts', 'Time limit']) {
      expect(
        isClipped(t, label),
        isFalse,
        reason: '"$label" is being clipped at three columns',
      );
    }
  });

  bothPlatforms('a wide tile keeps the icon beside the label', (t, h) async {
    await t.pumpWidget(h(const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: AppStatGrid(
          columns: 1,
          tiles: [
            AppStatTile(
              label: 'Attempts',
              value: '1',
              icon: Icons.repeat_rounded,
            ),
          ],
        ),
      ),
    )));
    await t.pumpAndSettle();

    // Side by side, so their vertical centres line up; stacked, they would not.
    expect(
      t.getCenter(find.byIcon(Icons.repeat_rounded)).dy,
      closeTo(t.getCenter(find.text('Attempts')).dy, 1),
    );
  });
}
