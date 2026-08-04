import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'liquid_glass_container.dart';

/// An iOS-proportioned switch with a glass track and a solid thumb.
///
/// Deliberately not `CupertinoSwitch`: that paints an opaque track, which reads
/// as a foreign element sitting on a translucent row. This keeps Apple's
/// geometry — 51×31 track, 27pt thumb, 2pt inset — while letting the backdrop
/// show through the off-state track, and it uses the design system's own spring
/// so the thumb settles like every other glass control.
class LiquidGlassSwitch extends StatelessWidget {
  const LiquidGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the control.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  /// Apple's switch metrics.
  static const _trackWidth = 51.0;
  static const _trackHeight = 31.0;
  static const _thumbInset = 2.0;
  static const _thumbSize = _trackHeight - _thumbInset * 2;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: _enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled
            ? () {
                GlassHaptics.light();
                onChanged!(!value);
              }
            : null,
        // Dragging the thumb is how many people use a switch; without this it
        // would only respond to taps.
        onHorizontalDragEnd: _enabled
            ? (details) {
                final next = details.velocity.pixelsPerSecond.dx >= 0;
                if (next == value) return;
                GlassHaptics.light();
                onChanged!(next);
              }
            : null,
        child: Opacity(
          opacity: _enabled ? 1.0 : 0.45,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value ? 1.0 : 0.0),
            duration: glass.duration(GlassDurations.base),
            // The thumb overshoots very slightly then settles — the "click" of
            // an iOS switch expressed as motion.
            curve: GlassCurves.spring,
            builder: (context, t, _) {
              final trackSpec = glass.control.copyWith(
                tint: Color.lerp(
                  glass.control.tint,
                  scheme.primary.withValues(alpha: 0.92),
                  t,
                ),
                borderColor: Color.lerp(
                  glass.control.borderColor,
                  scheme.primary.withValues(alpha: 0.5),
                  t,
                ),
              );

              return LiquidGlassContainer(
                spec: trackSpec,
                radius: GlassRadius.capsule,
                showShadow: false,
                child: SizedBox(
                  width: _trackWidth,
                  height: _trackHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        top: _thumbInset,
                        // Interpolated rather than aligned, so the spring's
                        // overshoot is visible in the thumb's travel.
                        left: _thumbInset +
                            (_trackWidth - _thumbSize - _thumbInset * 2) * t,
                        child: _Thumb(isDark: glass.isDark),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LiquidGlassSwitch._thumbSize,
      height: LiquidGlassSwitch._thumbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The thumb is the one opaque part of the control — it has to read as a
        // solid object moving over the translucent track.
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
    );
  }
}
