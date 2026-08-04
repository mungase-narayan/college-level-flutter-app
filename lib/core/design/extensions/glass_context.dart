import 'package:flutter/widgets.dart';

import '../platform/app_platform.dart';
import '../platform/glass_scope.dart';
import '../utils/glass_insets.dart';

/// Ergonomics for the glass layer, mirroring the existing `context.tokens` /
/// `context.scheme` extension in `app_theme.dart` so both design systems are
/// reached the same way.
extension GlassContextX on BuildContext {
  /// True when this build should render Liquid Glass rather than Material.
  ///
  /// The one branch condition used throughout the app:
  ///
  /// ```dart
  /// if (context.useGlass) return LiquidGlassCard(...);
  /// return /* the original Material tree, untouched */;
  /// ```
  bool get useGlass => AppPlatform.useGlass;

  /// Glass materials with Reduce Transparency and Reduce Motion already applied.
  ResolvedGlass get glass => resolveGlass(this);

  /// Extra scroll-view padding so content clears the floating chrome.
  /// [EdgeInsets.zero] off iOS.
  EdgeInsets get glassContentInsets => GlassInsetsScope.of(this);
}
