import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/design/glass.dart';

/// Runs [body] twice — once down the Material branch, once down the Liquid
/// Glass branch — so a screen is proven to carry the same features on Android
/// and on iOS.
///
/// `defaultTargetPlatform` is hard-wired to Android whenever `FLUTTER_TEST` is
/// set, so every other suite in this app takes the Material path by default and
/// the glass path is the one that goes unexercised. Asking for it explicitly is
/// exactly what [AppPlatform.debugUseGlassOverride] exists for; see
/// `test/core/glass/glass_adaptive_test.dart`, which established the pattern.
void bothPlatforms(
  String description,
  Future<void> Function(WidgetTester tester, ParityHost host) body,
) {
  for (final glass in [false, true]) {
    testWidgets(
      '$description — ${glass ? 'iOS (glass)' : 'Android (material)'}',
      (tester) async {
        AppPlatform.debugUseGlassOverride = glass;

        // A phone-sized surface. The default 800×600 test window is shorter
        // than any real device, which makes screens report overflows and puts
        // sheet buttons below the fold for reasons a user would never hit —
        // 390×844 is an iPhone 15 / Pixel-class viewport.
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(1170, 2532);

        addTearDown(() {
          // A leaked override would silently flip every later test in the run.
          AppPlatform.debugUseGlassOverride = null;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await body(tester, ParityHost(glass: glass));
      },
    );
  }
}

/// Wraps a screen in the app chrome the two branches each expect.
class ParityHost {
  const ParityHost({required this.glass});

  final bool glass;

  /// The theme the running platform would actually use, so a widget that reads
  /// `context.scheme` or the glass tokens finds what it would in the app.
  ThemeData get theme => glass ? LiquidGlassTheme.light : AppTheme.light;

  Widget call(Widget child) => MaterialApp(
        theme: theme,
        home: GlassScope(child: child),
      );
}
