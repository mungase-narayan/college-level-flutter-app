import 'package:flutter/animation.dart';

/// The motion vocabulary of the glass layer.
///
/// Apple's system animations are overwhelmingly *decelerating* — they start fast
/// and settle, which is what makes iOS feel responsive rather than floaty. These
/// curves reproduce that, and every glass widget animates with one of them so
/// motion reads as a single system rather than a pile of one-off tweens.
abstract final class GlassCurves {
  /// `easeOutExpo` — the workhorse. Nearly all of the travel happens in the
  /// first third of the duration, so the UI appears to respond instantly and
  /// then glide to rest. Matches the CSS cubic-bezier Apple's web properties use.
  static const easeOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);

  /// A gentler decelerate for opacity and blur, where an aggressive ease reads
  /// as a flicker.
  static const easeOutSmooth = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Symmetric ease for reversible state changes (a switch flipping back and
  /// forth) where an asymmetric curve makes the return trip feel wrong.
  static const easeInOutSmooth = Cubic(0.4, 0.0, 0.2, 1.0);

  /// The spring used for the nav bar's selection pill and the segmented
  /// control's thumb. Overshoots slightly then settles — the "snap into place"
  /// feel of iOS controls.
  static const spring = Cubic(0.34, 1.4, 0.42, 1.0);

  /// A softer spring for press-and-release scaling, where a visible overshoot
  /// on a button would read as a bounce rather than a tap.
  static const springSoft = Cubic(0.28, 1.18, 0.5, 1.0);

  /// Sheet presentation — a long, heavily decelerated glide, matching the way
  /// an iOS sheet slides up and settles under its own weight.
  static const sheet = Cubic(0.2, 0.9, 0.15, 1.0);
}

/// Canonical durations. Widgets pick from this ladder instead of inventing
/// millisecond values, so timings stay consistent as the library grows.
///
/// Always resolve these through `context.glass.duration(...)` (see
/// `glass_context.dart`) so that Reduce Motion can collapse them to zero.
abstract final class GlassDurations {
  /// Press feedback, hover, focus rings — must feel instantaneous.
  static const fast = Duration(milliseconds: 180);

  /// The default for selection changes, colour and blur transitions.
  static const base = Duration(milliseconds: 300);

  /// Larger reveals — a collapsing large title, an expanding section.
  static const slow = Duration(milliseconds: 480);

  /// Sheet and dialog presentation.
  static const sheet = Duration(milliseconds: 420);

  /// Cross-fading the whole theme between light and dark.
  static const theme = Duration(milliseconds: 350);
}
