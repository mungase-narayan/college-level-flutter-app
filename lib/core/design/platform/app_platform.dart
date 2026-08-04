import 'package:flutter/foundation.dart';

/// The single platform seam for the whole app.
///
/// Every Liquid Glass branch in the codebase resolves through [useGlass] and
/// nothing else performs a platform check. That keeps the Android path a single
/// `else` away from the original Material tree — if this getter is false, the
/// app renders exactly what it rendered before the glass layer existed.
///
/// [defaultTargetPlatform] is used rather than `Platform.isIOS` because it is
/// overridable in tests, honours `ThemeData.platform`, and does not drag in
/// `dart:io` (which would break web builds).
///
/// Note that `defaultTargetPlatform` hard-returns [TargetPlatform.android]
/// whenever `FLUTTER_TEST` is set, so the existing widget tests take the
/// Material branch automatically. Glass behaviour must be tested by setting
/// [debugUseGlassOverride] or `debugDefaultTargetPlatformOverride`.
abstract final class AppPlatform {
  /// Forces the glass layer on or off regardless of the host platform.
  ///
  /// Intended for widget tests and for previewing the iOS design on an Android
  /// device during development. Leave `null` in production.
  static bool? debugUseGlassOverride;

  /// True when the UI should render Apple's Liquid Glass design language.
  ///
  /// macOS is included because it shares the same material vocabulary, and a
  /// desktop build of an iOS design reads correctly. Every other platform —
  /// Android, web, Windows, Linux, Fuchsia — keeps Material.
  static bool get useGlass {
    final override = debugUseGlassOverride;
    if (override != null) return override;

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// True only on real iOS — the gate for things that are genuinely
  /// iPhone-specific rather than merely stylistic, such as haptics.
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}
