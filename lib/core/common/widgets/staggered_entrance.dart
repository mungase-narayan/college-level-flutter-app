import 'package:flutter/widgets.dart';

import '../../design/animations/glass_curves.dart';
import '../../design/extensions/glass_context.dart';

/// Fades and lifts [child] into place, offset by its position in a list so a
/// run of items arrives one after another rather than all at once.
///
/// Timing and curve resolve through `context.glass`, which collapses them under
/// Reduce Motion — so the child simply appears, with no special-casing here.
/// `resolveGlass` falls back to a `MediaQuery`-derived instance when no
/// `GlassScope` is present, so this behaves identically on the Material branch.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggered = 10,
    this.offset = 12,
  });

  /// Position in the list. Drives the delay before this item animates.
  final int index;

  final Widget child;

  /// Items past this index all share the last delay. Without the cap a long
  /// page would leave the final rows visibly waiting.
  final int maxStaggered;

  /// How far the child travels upward, in logical pixels.
  final double offset;

  static const _step = Duration(milliseconds: 40);

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final duration = glass.duration(GlassDurations.base);

    // Nothing to animate under Reduce Motion, so skip the builder entirely
    // rather than running a zero-length tween.
    if (duration == Duration.zero) return child;

    final delay = _step * index.clamp(0, maxStaggered);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      // The delay is folded into the curve rather than a Timer: an interval
      // holds the value at 0 for the leading fraction, which keeps this a pure
      // build-time animation with no state to cancel if the row is disposed
      // mid-flight.
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: glass.curve(GlassCurves.easeOutExpo),
      ),
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
    );
  }
}
