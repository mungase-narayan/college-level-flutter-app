import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/core/design/glass.dart';

/// Goldens for the two button states that a finder cannot police.
///
/// Every one of these was green through a release where the disabled button was
/// visibly empty on screen: `find.text('Reset')` located the label and
/// `getRect` returned a sensible rectangle for it, because the widget really was
/// in the tree and really was laid out. It simply never got painted — an
/// [Opacity] wrapper had put the surface's backdrop filter inside a layer with
/// no backdrop to sample, and the whole subtree came out blank.
///
/// Nothing short of looking at the pixels catches that, so these look at the
/// pixels. They exist to assert "the surface painted *something*", not to freeze
/// the design — keep them few, and re-bless them without ceremony when the
/// design moves.
void main() {
  tearDown(() {
    AppPlatform.debugUseGlassOverride = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool dark,
    required Widget child,
  }) async {
    AppPlatform.debugUseGlassOverride = true;
    tester.view.devicePixelRatio = 3;
    // Pinned, and generously taller than the content: a viewport that clips
    // makes a golden fail for reasons that have nothing to do with painting.
    tester.view.physicalSize = const Size(1180, 480);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? LiquidGlassTheme.dark : LiquidGlassTheme.light,
        home: GlassScope(
          child: Scaffold(
            backgroundColor:
                dark ? const Color(0xFF0E0E17) : const Color(0xFFF9FAFC),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The exact regression: `AppFilterActions` renders Reset disabled until a
  /// filter is touched, and on dark it came out as an empty outline.
  testWidgets('a disabled outline button still paints its label — dark',
      (tester) async {
    await pump(
      tester,
      dark: true,
      child: const Row(
        key: ValueKey('actions'),
        children: [
          Expanded(
            child: AppButton(
              label: 'Reset',
              variant: AppButtonVariant.outline,
              expand: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: AppButton(label: 'Apply', expand: true),
          ),
        ],
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('actions')),
      matchesGoldenFile('goldens/button_disabled_outline_dark.png'),
    );
  });

  /// `primary` is the variant carrying a real shadow, so it covers the part of
  /// the disabled rewrite that fades each shadow's colour — the old `Opacity`
  /// wrapper faded the shadow along with everything else, and dimming colour by
  /// colour has to reproduce that.
  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';

    testWidgets('a disabled primary button keeps its fill and shadow — $name',
        (tester) async {
      await pump(
        tester,
        dark: dark,
        child: const SizedBox(
          width: 260,
          child: AppButton(label: 'Submit', expand: true),
        ),
      );

      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('goldens/button_disabled_primary_$name.png'),
      );
    });
  }

  /// Held down, not tapped: the blanking only happened *during* the press, so a
  /// golden captured after the gesture completed would look perfectly fine.
  testWidgets('a button held down still paints', (tester) async {
    await pump(
      tester,
      dark: true,
      child: SizedBox(
        width: 260,
        child: AppButton(label: 'Hold me', expand: true, onPressed: () {}),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(AppButton)));
    // Long enough for the press animation to reach its resting depth.
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(AppButton),
      matchesGoldenFile('goldens/button_pressed_dark.png'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
