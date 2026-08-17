import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_refraction.dart';

/// The glass primitive. Every other widget in this library is built from it.
///
/// Four layers make a surface read as glass rather than as a translucent
/// rectangle, painted bottom-to-top:
///
/// 1. **Shadow** — outside the clip, so it is not shaved off by it.
/// 2. **Backdrop** — an optional [BackdropFilter], then the translucent tint,
///    with the specular wash baked into the same gradient so it costs no extra
///    paint.
/// 3. **Content** — the caller's child. The only unpositioned child, so it is
///    what sizes the surface.
/// 4. **Edge** — a hairline border with a brighter highlight along the top,
///    stroked in a single pass by [_GlassEdgePainter].
///
/// ### On blur cost
///
/// [blur] defaults to [GlassBlur.none], which renders *simulated* glass: no
/// [BackdropFilter] at all. This is the single most important performance
/// decision in the design system. A [BackdropFilter] is a full-screen GPU pass;
/// a handful is free, one per row in a scrolling list is not — and a card sitting
/// on the app's own background has nothing meaningful behind it to blur, so the
/// pass would buy nothing.
///
/// Real blur is spent where content genuinely passes underneath: navigation
/// chrome, sheets, dialogs, menus. Opt a content surface in explicitly when it
/// overlaps imagery.
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blur = GlassBlur.none,
    this.spec,
    this.borderRadius,
    this.radius = GlassRadius.md,
    this.padding,
    this.margin,
    this.showHighlight = true,
    this.showBorder = true,
    this.showShadow = true,
    this.tintOverride,
    this.sigmaOverride,
    this.constraints,
    this.clipBehavior = Clip.antiAlias,
    this.refract = false,
    this.saturation = 1.0,
  });

  final Widget child;

  /// How much real backdrop blur to apply. See the class docs on cost.
  final GlassBlur blur;

  /// Which material tier to render. Defaults to `context.glass.card`.
  final GlassSpec? spec;

  /// Overrides [radius] when the corners are not uniform.
  final BorderRadius? borderRadius;

  /// Uniform corner radius. Ignored when [borderRadius] is set.
  final double radius;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// The top-edge specular highlight and its wash. Disable for surfaces nested
  /// inside another glass surface, where a second bevel reads as a seam.
  final bool showHighlight;

  final bool showBorder;
  final bool showShadow;

  /// Replaces the resolved spec's tint, for one-off tinted surfaces (a selected
  /// chip, a destructive row).
  final Color? tintOverride;

  /// Replaces the blur sigma with an interpolated value. Used by the chrome,
  /// which ramps its blur as content scrolls beneath it.
  final double? sigmaOverride;

  final BoxConstraints? constraints;
  final Clip clipBehavior;

  /// Bends the blurred backdrop near the rim, the way real glass refracts light.
  ///
  /// Requires a real blur ([blur] or [sigmaOverride] non-zero) — there is nothing
  /// to displace otherwise. Reserved for chrome: it is the difference between
  /// "frosted" and "glass", but it costs a shader pass and a [LayoutBuilder], so
  /// content surfaces do not opt in. Degrades to a plain blur wherever
  /// `ImageFilter.shader` is unavailable.
  final bool refract;

  /// Saturation boost applied to the blurred backdrop, 1.0 for none.
  ///
  /// Opt-in per surface rather than baked into the blur: it exists to keep colour
  /// bleeding through a *small* surface that content passes under — the nav
  /// capsule — and on a full-width bar the same boost would tint the whole header
  /// from whatever happens to be under one end of it. Ignored when there is no real
  /// blur, since there is nothing to compensate for then.
  final double saturation;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final resolved = spec ?? glass.card;
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final tint = tintOverride ?? resolved.tint;

    // Reduce Transparency zeroes every sigma, so this also decides whether a
    // BackdropFilter is created at all.
    final sigma = sigmaOverride != null
        ? glass.sigmaOf(sigmaOverride!)
        : glass.sigma(blur);
    final isBlurred = sigma > 0;

    // The tint, with the specular wash folded into a single gradient. Compositing
    // the highlight into the top stop is physically right as well as cheap — the
    // bevel of real glass is denser than its face, so it is both brighter *and*
    // slightly more opaque.
    //
    // The wash is a *fraction* of the highlight, not the highlight itself: the
    // full-strength colour is reserved for the 1px edge stroke, where the bevel
    // actually reads. Painting it across the face at full strength blows out any
    // low-alpha [tintOverride] — a card tinted at 7% would come back as a heavy
    // top-to-bottom gradient rather than a wash of colour.
    final Decoration fill;
    if (showHighlight && resolved.highlightColor.a > 0) {
      fill = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              resolved.highlightColor
                  .withValues(alpha: resolved.highlightColor.a * 0.16),
              tint,
            ),
            tint,
          ],
          stops: const [0.0, 0.5],
        ),
      );
    } else {
      fill = BoxDecoration(color: tint);
    }

    Widget backdrop = DecoratedBox(decoration: fill);
    if (isBlurred) {
      backdrop = refract
          // The refraction shader needs the surface's painted size to locate its
          // rim, which is only known at layout — hence the LayoutBuilder. Only on
          // the refracting path, so no other surface pays for it.
          ? LayoutBuilder(
              builder: (context, constraints) => BackdropFilter(
                filter: GlassRefraction.filter(
                      sigma: sigma,
                      radius: shape.topLeft.x,
                      size: constraints.biggest,
                      saturation: saturation,
                    ) ??
                    ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: DecoratedBox(decoration: fill),
              ),
            )
          : BackdropFilter(
              filter: GlassRefraction.saturate(
                    ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    saturation,
                  ) ??
                  ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: backdrop,
            );
    }

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget surface = Stack(
      // Passthrough forwards the parent's constraints, so this works both when
      // the caller sizes the surface and when the content does.
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: backdrop),
        content,
        if (showBorder || showHighlight)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassEdgePainter(
                  borderRadius: shape,
                  borderColor: showBorder ? resolved.borderColor : null,
                  highlightColor:
                      showHighlight ? resolved.highlightColor : null,
                ),
              ),
            ),
          ),
      ],
    );

    surface = ClipRRect(
      borderRadius: shape,
      clipBehavior: clipBehavior,
      child: surface,
    );

    // Isolating the blur keeps a scroll or an animation elsewhere on screen from
    // forcing the expensive filter to re-rasterise.
    if (isBlurred) {
      surface = RepaintBoundary(child: surface);
    }

    if (showShadow && resolved.shadow.isNotEmpty) {
      // Outside the clip: a shadow drawn inside it would be clipped away.
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: resolved.shadow,
        ),
        child: surface,
      );
    }

    if (constraints != null) {
      surface = ConstrainedBox(constraints: constraints!, child: surface);
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    return surface;
  }
}

/// Strokes the hairline edge and the top specular highlight in one pass.
///
/// Two strokes rather than a [Border] because the highlight must *fade* — glass
/// catches light along its top edge and darkens toward the bottom, and a uniform
/// border cannot express that. [BoxDecoration] also rejects a non-uniform border
/// combined with a border radius, so the effect is not expressible declaratively.
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.borderRadius,
    required this.borderColor,
    required this.highlightColor,
  });

  final BorderRadius borderRadius;
  final Color? borderColor;
  final Color? highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke width so the 1px line lands fully inside the
    // clip; stroking on the boundary would clip away its outer half and render
    // as a 0.5px line.
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    if (rect.isEmpty) return;
    final rrect = borderRadius.toRRect(rect);

    final border = borderColor;
    if (border != null && border.a > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
    }

    final highlight = highlightColor;
    if (highlight != null && highlight.a > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [
              highlight,
              highlight.withValues(alpha: highlight.a * 0.35),
              highlight.withValues(alpha: 0),
            ],
            // Brightest at the very top, gone by 55% of the height — the falloff
            // of a light source above the surface.
            const [0.0, 0.28, 0.55],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) =>
      borderRadius != oldDelegate.borderRadius ||
      borderColor != oldDelegate.borderColor ||
      highlightColor != oldDelegate.highlightColor;
}
