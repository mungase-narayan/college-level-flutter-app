import 'package:flutter/widgets.dart';

/// How much real backdrop blur a glass surface asks for.
///
/// This is the performance dial of the whole design system, so it is explicit
/// rather than implied. A [BackdropFilter] is a full-screen GPU pass: a handful
/// on screen is free, one per row in a long list is not.
///
/// Apple spends real blur on **chrome and overlays** — nav bars, toolbars,
/// sheets, popovers — because content genuinely passes underneath them. Content
/// surfaces use a near-opaque material instead. A card sitting on the flat app
/// background has nothing meaningful behind it to blur, so [none] renders
/// *simulated* glass (layered tint + specular highlight + hairline + soft
/// shadow) which is visually equivalent and free to scroll.
///
/// Reach for [regular] or [thick] on a card only when it genuinely overlaps
/// imagery, such as a course thumbnail or an assessment hero.
enum GlassBlur {
  /// Simulated glass: no [BackdropFilter] at all. The default for content.
  none(0),

  /// A whisper of blur for controls layered directly on a tinted surface.
  thin(14),

  /// The standard content-over-content blur.
  regular(24),

  /// Heavy separation — used by modal sheets and dialogs, where the content
  /// behind should read as texture rather than as detail.
  thick(34),

  /// Navigation chrome. Sits between [regular] and [thick] at rest and is
  /// interpolated upward as content scrolls beneath it.
  chrome(30);

  const GlassBlur(this.sigma);

  /// The `sigmaX`/`sigmaY` passed to [ImageFilter.blur].
  final double sigma;

  bool get isBlurred => sigma > 0;
}

/// The full visual recipe for one tier of glass.
///
/// Four layers stack to make a surface read as glass rather than as a flat
/// translucent rectangle:
///
/// 1. **[tint]** — the translucent fill that gives the material its body.
/// 2. **[highlightColor]** — a specular line along the top edge, as if a light
///    source above were catching the bevel. This is the single most important
///    detail; without it glass reads as fog.
/// 3. **[borderColor]** — a 1px hairline that defines the shape's edge.
/// 4. **[shadow]** — a soft, large-radius, low-opacity drop shadow that lifts
///    the surface off the background and creates the sense of depth.
@immutable
class GlassSpec {
  const GlassSpec({
    required this.tint,
    required this.borderColor,
    required this.highlightColor,
    required this.shadow,
    required this.opaqueFill,
  });

  /// The translucent fill painted over the (optionally blurred) backdrop.
  final Color tint;

  /// The 1px edge hairline.
  final Color borderColor;

  /// The top-edge specular highlight. Fades to transparent downward.
  final Color highlightColor;

  /// A soft outer shadow. Large radius, low opacity, slight downward offset.
  final List<BoxShadow> shadow;

  /// The fully opaque colour this surface collapses to when the user has asked
  /// for reduced transparency. Chosen so contrast against the scheme's
  /// foreground stays legible.
  final Color opaqueFill;

  /// The Reduce Transparency variant: opaque fill, solid border, no specular
  /// highlight (there is no longer a translucent bevel to catch light), shadow
  /// retained so depth cues survive.
  GlassSpec toOpaque() => GlassSpec(
        tint: opaqueFill,
        borderColor: borderColor.withValues(alpha: 1.0),
        highlightColor: const Color(0x00000000),
        shadow: shadow,
        opaqueFill: opaqueFill,
      );

  GlassSpec copyWith({
    Color? tint,
    Color? borderColor,
    Color? highlightColor,
    List<BoxShadow>? shadow,
    Color? opaqueFill,
  }) =>
      GlassSpec(
        tint: tint ?? this.tint,
        borderColor: borderColor ?? this.borderColor,
        highlightColor: highlightColor ?? this.highlightColor,
        shadow: shadow ?? this.shadow,
        opaqueFill: opaqueFill ?? this.opaqueFill,
      );

  /// Interpolates every layer, so a light↔dark theme change cross-fades the
  /// glass instead of popping between two discrete looks.
  static GlassSpec lerp(GlassSpec a, GlassSpec b, double t) => GlassSpec(
        tint: Color.lerp(a.tint, b.tint, t)!,
        borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
        highlightColor: Color.lerp(a.highlightColor, b.highlightColor, t)!,
        shadow: BoxShadow.lerpList(a.shadow, b.shadow, t) ?? b.shadow,
        opaqueFill: Color.lerp(a.opaqueFill, b.opaqueFill, t)!,
      );
}

/// Corner radii for glass surfaces.
///
/// Apple's radii grew substantially in iOS 26 — glass needs a generous curve for
/// the specular highlight to travel around and read as a bevel. These sit well
/// above the app's Material radii (`AppTheme.radiusSm/Md/Lg` = 8/12/16), which
/// remain in use on Android.
abstract final class GlassRadius {
  /// Chips, badges, small inline controls.
  static const sm = 18.0;

  /// Buttons, inputs, list tiles.
  static const md = 22.0;

  /// Cards and sheets.
  static const lg = 28.0;

  /// Fully rounded — nav bar capsule, FAB, switch track, segmented control.
  static const capsule = 999.0;

  static BorderRadius all(double radius) => BorderRadius.circular(radius);

  /// Sheets are rounded on top only.
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(lg));
}

/// The spacing ladder. Widgets pick from here rather than inventing padding, so
/// rhythm stays consistent across the library.
abstract final class GlassSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

/// Fixed dimensions of the floating chrome.
///
/// These are constants rather than measured values because the content inset
/// calculation and the toast's overlay offset both need them *before* layout —
/// the toast in particular renders in the root [Overlay], above the shell, and
/// so cannot read the shell's geometry.
abstract final class GlassMetrics {
  /// Height of the floating navigation capsule.
  static const navBarHeight = 58.0;

  /// Horizontal inset of the capsule from the screen edges.
  static const navBarSideMargin = 16.0;

  /// Clearance between the capsule's bottom edge and the physical screen edge.
  ///
  /// Deliberately **not** the full `viewPadding.bottom`. That reserve is 34pt on a
  /// home-indicator device, but the indicator itself is only a ~5pt line sitting
  /// ~8pt up — so stacking a gap on top of the whole safe area parked the capsule
  /// 44pt off the edge and left a conspicuous empty band beneath it. 16pt clears
  /// the indicator comfortably while keeping the capsule where a floating iOS bar
  /// actually sits.
  ///
  /// Device-independent by design: on a home-button device (`viewPadding.bottom`
  /// of 0) 16pt from the edge is equally correct, so no branch is needed.
  static const navBarBottomInset = 16.0;

  /// Vertical space a scroll view must reserve so its last item clears the
  /// capsule: the capsule's own footprint plus a breathing gap.
  static const navBarReservedHeight =
      navBarBottomInset + navBarHeight + GlassSpacing.md;

  /// Where the capsule's top edge sits, measured up from the screen's bottom
  /// edge. The toast uses this to float above the capsule rather than behind it.
  static const navBarTopFromBottom = navBarBottomInset + navBarHeight;

  /// Blur sigma for the floating nav capsule, at rest and once content has
  /// scrolled beneath it.
  ///
  /// Deliberately far heavier than the app bar's 24→38. The two surfaces have
  /// opposite problems: the app bar spans the full width and needs its tint to
  /// carry legibility, whereas the capsule is a small surface with content passing
  /// directly under it — and the whole point of it is that you can *see* that
  /// content. A strong blur smears whatever is behind into a flat wash, which is
  /// what lets the tint stay translucent without the labels losing contrast.
  ///
  /// Zeroed entirely under Reduce Transparency, like every other sigma.
  static const navBarBlurSigma = 60.0;
  static const navBarBlurSigmaScrolled = 68.0;

  /// Edge refraction for chrome, in pixels of inward displacement at the rim.
  ///
  /// How visible this is depends entirely on what is behind the surface: bending a
  /// flat card yields a flat result, exactly as blurring one does. It reads
  /// strongly over text and avatars — a list, a chat — and barely at all over an
  /// empty panel. That is physically correct, not a defect.
  static const chromeRefraction = 18.0;

  /// Per-channel split at the rim, as a fraction of [chromeRefraction]. This is
  /// the faint colour fringing along the edge of Apple's own glass; past ~0.2 it
  /// stops reading as dispersion and starts reading as a rendering fault.
  static const chromeDispersion = 0.12;

  /// How far in from the edge the lensing reaches, in pixels. Clamped at runtime
  /// to half the surface's shortest side so the two rims cannot overlap.
  static const chromeRefractionEdge = 26.0;

  /// App bar height once the large title has collapsed.
  static const appBarCompactHeight = 52.0;

  /// App bar height with the large title fully expanded.
  static const appBarLargeHeight = 96.0;

  /// Scroll distance over which the large title collapses into the compact one.
  static const largeTitleCollapseDistance = 52.0;

  /// Scroll distance over which chrome blur and tint ramp to their scrolled
  /// values. Deliberately short so the frosting reacts immediately.
  static const chromeScrollRamp = 40.0;
}
