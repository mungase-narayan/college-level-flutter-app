import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// A glass surface rendered by `liquid_glass_renderer`'s [FakeGlass].
///
/// The package draws the material — a tinted, blurred, saturated backdrop under
/// a squircle clip — and this adds the two things it has no parameters for: the
/// hairline that defines the shape's edge, and the shadow that lifts it off the
/// page. Both come from the app's own [GlassSpec] tiers, so a surface rendered
/// here still matches one rendered by [LiquidGlassContainer] beside it.
///
/// **Why [FakeGlass] and not [LiquidGlass]:** the real renderer bends the pixels
/// behind the surface, so it only earns its shader pass where content actually
/// passes underneath. Buttons, fields and chips in this app sit on opaque cards
/// and near-flat page backgrounds — the package's own README says to use
/// [FakeGlass] for exactly that case. The nav capsule, which genuinely floats
/// over a scrolling page, is the one surface that uses the real thing.
///
/// **Reduce Transparency** is honoured here rather than at each call site: the
/// setting must strip every filter in the app, and [FakeGlass] builds a
/// `BackdropFilterLayer` inside its own render object rather than using a
/// [BackdropFilter] widget — so a test asserting no `BackdropFilter` would pass
/// while the blur was still on screen. Routing the fallback through one place is
/// what keeps that from happening silently.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.spec,
    this.radius = GlassRadius.md,
    this.blur = 8,
    this.saturation = 1.0,
    this.padding,
    this.constraints,
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;

  /// Which material tier to render. Defaults to `context.glass.card`.
  final GlassSpec? spec;

  /// Corner radius. Pass [GlassRadius.capsule] for a pill — the underlying
  /// [RoundedSuperellipseBorder] clamps it to half the shortest side, so the
  /// surface does not need to know its own height.
  final double radius;

  /// Backdrop blur in logical pixels. Independent of refraction.
  final double blur;

  /// Saturation of the blurred backdrop. Left at 1.0 deliberately.
  ///
  /// The nav capsule boosts this, because blurring a *card* passing underneath
  /// greys out colour that should bleed through. These surfaces have no card
  /// under them — only the ambient backdrop's violet wash — so a boost does not
  /// restore colour, it invents it: at 1.1 a focused search field came out
  /// visibly lavender instead of the colourless glass it should be.
  final double saturation;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final resolved = spec ?? glass.card;

    // The in-house container already resolves to an opaque fill with no filter
    // of any kind, so Reduce Transparency reuses it wholesale.
    if (glass.reduceTransparency) {
      return LiquidGlassContainer(
        spec: resolved,
        radius: radius,
        padding: padding,
        constraints: constraints,
        showBorder: showBorder,
        showShadow: showShadow,
        child: child,
      );
    }

    final border = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: showBorder
          ? BorderSide(color: resolved.borderColor)
          : BorderSide.none,
    );

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget surface = FakeGlass(
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: LiquidGlassSettings(
        glassColor: resolved.tint,
        blur: blur,
        saturation: saturation,
        // Thickness and refractive index are documented as inert on FakeGlass —
        // there is no refraction to scale — so setting them would only imply a
        // depth this surface does not have.
        lightIntensity: 0.4,
        ambientStrength: 0.1,
      ),
      child: content,
    );

    // Foreground, because FakeGlass only *clips* to its shape; it never strokes
    // the outline. Same superellipse the clip uses, so the two register.
    surface = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(shape: border),
      child: surface,
    );

    if (showShadow && resolved.shadow.isNotEmpty) {
      surface = DecoratedBox(
        decoration: ShapeDecoration(
          shape: border.copyWith(side: BorderSide.none),
          shadows: resolved.shadow,
        ),
        child: surface,
      );
    }

    if (constraints != null) {
      surface = ConstrainedBox(constraints: constraints!, child: surface);
    }

    return surface;
  }
}
