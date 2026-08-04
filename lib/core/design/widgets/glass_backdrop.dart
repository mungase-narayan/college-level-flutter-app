import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../extensions/glass_context.dart';

/// The ambient colour field that sits behind everything on iOS.
///
/// Glass is a *sampling* material: a [BackdropFilter] over a flat, uniform
/// background produces a flat, uniform result, which reads as grey plastic
/// rather than as glass. Apple's own backgrounds are never flat — there is
/// always a wallpaper, a photo, or a subtle system gradient for the material to
/// pick up. This supplies that gradient so the floating chrome has something
/// worth blurring.
///
/// It is a deliberate evolution of the existing `_LoginBackdrop` in
/// `login_page.dart`, which already fakes this effect with two radial "blur
/// orbs" — the same idea, promoted to the whole app and drawn in one pass by a
/// [CustomPainter] rather than as stacked `Container`s.
///
/// Cheap by construction: three radial gradients painted once into a
/// [RepaintBoundary]. It never animates, so it rasterises a single time and is
/// then reused as a texture for every subsequent frame.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    // Under Reduce Transparency nothing samples the backdrop — every surface is
    // opaque — so painting the gradient would be pure cost for zero effect.
    if (glass.reduceTransparency) {
      return ColoredBox(color: scheme.background, child: child);
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _GlassBackdropPainter(
          base: scheme.background,
          // The violet brand hue and the pink chart accent, the same pairing the
          // login backdrop and the gradient logo chips already use.
          primary: scheme.primary,
          secondary: scheme.chart[3],
          tertiary: scheme.chart[2],
          isDark: glass.isDark,
        ),
        // `willChange: false` tells the engine this layer is static and safe to
        // cache — the single most important flag for keeping blur cheap.
        willChange: false,
        child: child,
      ),
    );
  }
}

class _GlassBackdropPainter extends CustomPainter {
  const _GlassBackdropPainter({
    required this.base,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.isDark,
  });

  final Color base;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = base);

    // Dark mode can carry a stronger wash before it muddies the foreground;
    // light mode needs restraint or the tint reads as a stain on white.
    final strength = isDark ? 0.22 : 0.13;

    // Top-left: the brand violet, anchored behind the app bar so the chrome's
    // blur has colour to sample from the moment the app opens.
    _orb(
      canvas: canvas,
      center: Offset(size.width * -0.1, size.height * -0.02),
      radius: size.width * 0.95,
      color: primary,
      alpha: strength,
    );

    // Bottom-right: the pink accent, sitting behind the floating nav capsule.
    _orb(
      canvas: canvas,
      center: Offset(size.width * 1.05, size.height * 0.92),
      radius: size.width * 0.9,
      color: secondary,
      alpha: strength * 0.85,
    );

    // Mid-left: a cool third hue that keeps the middle of long scrolls from
    // flattening out into the base colour.
    _orb(
      canvas: canvas,
      center: Offset(size.width * -0.15, size.height * 0.55),
      radius: size.width * 0.8,
      color: tertiary,
      alpha: strength * 0.45,
    );
  }

  void _orb({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
          // Most of the fade happens in the outer half, which avoids the hard
          // ring a linear radial fade produces.
          stops: const [0.0, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassBackdropPainter oldDelegate) =>
      base != oldDelegate.base ||
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary ||
      tertiary != oldDelegate.tertiary ||
      isDark != oldDelegate.isDark;
}
