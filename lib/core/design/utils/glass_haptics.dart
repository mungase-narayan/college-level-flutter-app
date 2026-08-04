import 'package:flutter/services.dart';

import '../platform/app_platform.dart';

/// Haptic feedback, gated to real iOS.
///
/// Every method is a no-op off iOS, so call sites never need their own platform
/// check — and Android's behaviour is unchanged because nothing fires. (Android
/// haptics would also require a `VIBRATE` permission, which this app does not
/// declare.)
///
/// The mapping follows Apple's own usage: `selection` for moving between
/// discrete options, `light` for a successful tap on a control, `medium` for a
/// state change the user should feel, and `success`/`warning`/`error` for
/// outcome notifications.
abstract final class GlassHaptics {
  /// Moving between discrete values — nav tabs, segmented control, picker rows.
  static void selection() {
    if (!AppPlatform.isIOS) return;
    HapticFeedback.selectionClick();
  }

  /// A tap landing on a button or card.
  static void light() {
    if (!AppPlatform.isIOS) return;
    HapticFeedback.lightImpact();
  }

  /// A meaningful state change — a switch toggling, a sheet snapping open.
  static void medium() {
    if (!AppPlatform.isIOS) return;
    HapticFeedback.mediumImpact();
  }

  /// A destructive or irreversible action committing.
  static void heavy() {
    if (!AppPlatform.isIOS) return;
    HapticFeedback.heavyImpact();
  }

  /// An operation succeeded. Flutter exposes no dedicated notification haptic,
  /// so this uses the closest available impact.
  static void success() => light();

  /// An operation failed or was rejected.
  static void error() => heavy();
}
