import 'package:flutter/widgets.dart';

import '../extensions/glass_context.dart';
import '../utils/glass_haptics.dart';
import 'glass_curves.dart';

/// Press feedback for glass surfaces: a subtle scale-down, a dip in opacity, an
/// inner glow, and a haptic tick.
///
/// This is the iOS counterpart to Material's ink ripple. A ripple is the wrong
/// idiom here for two reasons: iOS does not use one, and an expanding [InkWell]
/// splash rendered inside a translucent surface visibly smears against the blur
/// behind it. Scale plus glow reads correctly on glass and costs less.
///
/// Every interactive widget in the library routes its press through this, so
/// timing, curve and haptic strength are consistent instead of being re-tuned
/// per widget.
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.965,
    this.pressedOpacity = 0.88,
    this.glowColor,
    this.borderRadius,
    this.enableHaptics = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale at full press. 0.965 is about as far as a large surface can travel
  /// before the movement reads as a bounce rather than a press.
  final double pressedScale;

  /// Opacity at full press.
  final double pressedOpacity;

  /// When set, a soft glow of this colour blooms behind the surface while
  /// pressed — used by primary buttons to suggest light passing through glass.
  final Color? glowColor;

  /// Needed only for the glow, which must match the surface's own corners.
  final BorderRadius? borderRadius;

  final bool enableHaptics;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Created eagerly rather than lazily. A `late final` initialiser would be
    // forced to run inside `dispose()` for any instance whose `build` returned
    // early (the non-interactive path below), and constructing a ticker there
    // performs an inherited-widget lookup on an already-deactivated element,
    // which trips a framework assertion.
    _controller = AnimationController(
      // Release is slower than press: the finger-down response must feel
      // immediate, while the spring-back is what makes it feel physical.
      duration: GlassDurations.fast,
      reverseDuration: GlassDurations.base,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!mounted) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleTap() {
    if (widget.enableHaptics) GlassHaptics.light();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.enableHaptics) GlassHaptics.medium();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    if (!widget._enabled) {
      // Nothing to animate and nothing to announce — return the child untouched
      // so a non-interactive card costs no extra layers.
      return widget.child;
    }

    // Reduce Motion suppresses the travel but keeps the opacity dip, so a press
    // is still visibly acknowledged.
    final targetScale = glass.pressScale(widget.pressedScale);
    final duration = glass.duration(GlassDurations.fast);
    final curve = glass.curve(GlassCurves.springSoft);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = duration == Duration.zero
                ? (_controller.value > 0 ? 1.0 : 0.0)
                : curve.transform(_controller.value);

            final scale = 1.0 + (targetScale - 1.0) * t;
            final opacity = 1.0 + (widget.pressedOpacity - 1.0) * t;

            Widget result = Opacity(opacity: opacity, child: child);

            final glow = widget.glowColor;
            if (glow != null && t > 0) {
              result = DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.42 * t),
                      blurRadius: 26 * t,
                      spreadRadius: 1 * t,
                    ),
                  ],
                ),
                child: result,
              );
            }

            // `filterQuality: null` keeps this a cheap transform rather than
            // forcing a resampled layer.
            return Transform.scale(scale: scale, child: result);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
