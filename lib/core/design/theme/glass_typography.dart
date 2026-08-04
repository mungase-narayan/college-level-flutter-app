import 'package:flutter/material.dart';

/// iOS typographic refinements layered onto the app's existing type scale.
///
/// The scale itself is already close to Apple's: `app_theme.dart` ports
/// `13 / 15 / 17 / 19 / 21 / 26 / 32 / 40` from the web app, and iOS's own body
/// size is 17. So this does not replace the scale — replacing it would make iOS
/// and Android drift apart in content density for no reason. It only applies the
/// two things SF Pro needs and the Material scale omits:
///
/// 1. **Negative tracking at display sizes.** SF Pro is optically sized: Apple
///    tightens letter spacing as type grows. Without this, large headings look
///    conspicuously loose on iOS.
/// 2. **A large-title style.** iOS's 34pt navigation large title has no Material
///    equivalent, so it is added rather than mapped onto `displaySmall`.
abstract final class GlassTypography {
  /// Applies Apple's optical tracking to an existing [TextTheme].
  ///
  /// Colours and sizes are inherited untouched, so the light/dark palette
  /// wiring in `app_theme.dart` continues to own them.
  static TextTheme refine(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge?.copyWith(letterSpacing: -1.0),
        displayMedium: base.displayMedium?.copyWith(letterSpacing: -0.8),
        displaySmall: base.displaySmall?.copyWith(letterSpacing: -0.6),
        headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.5),
        headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.4),
        titleLarge: base.titleLarge?.copyWith(letterSpacing: -0.35),
        titleMedium: base.titleMedium?.copyWith(letterSpacing: -0.3),
        titleSmall: base.titleSmall?.copyWith(letterSpacing: -0.2),
        bodyLarge: base.bodyLarge?.copyWith(letterSpacing: -0.2),
        bodyMedium: base.bodyMedium?.copyWith(letterSpacing: -0.1),
        labelLarge: base.labelLarge?.copyWith(letterSpacing: -0.2),
      );

  /// The 34pt navigation large title.
  static TextStyle largeTitle(Color color) => TextStyle(
        fontSize: 34,
        height: 41 / 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: color,
      );

  /// Labels under the floating nav bar's icons. Smaller and tighter than
  /// `labelSmall` (12pt) because four of them share one capsule.
  static TextStyle navLabel(Color color, {required bool selected}) => TextStyle(
        fontSize: 11,
        height: 13 / 11,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: -0.1,
        color: color,
      );

  /// The uppercase header above an inset-grouped list section, as used by the
  /// iOS Settings app.
  static TextStyle sectionHeader(Color color) => TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color,
      );
}
