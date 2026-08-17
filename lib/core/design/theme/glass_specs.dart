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
  ///
  /// Sized from its contents rather than picked: a 24pt glyph, a 4pt gap and a
  /// 13pt label line come to 41pt, and the selection pill needs [navBarPillInset]
  /// above and below that to read as a pill inside the capsule rather than as a
  /// second bar filling it.
  ///
  /// Every rounded shape here follows from this one number, because both the
  /// capsule and the pill are fully rounded: the capsule's radius is `height / 2`
  /// (33) and the pill's is that less its inset (27). Growing the bar past ~70pt
  /// does *not* scale the design — the content stack stays 41pt tall, so the extra
  /// height lands inside the pill as dead air and the lozenge reads as bloated.
  static const navBarHeight = 66.0;

  /// Horizontal inset of the capsule from the screen edges.
  ///
  /// A floating iOS tab bar sits visibly inboard of the screen edges — the gap is
  /// what says "this is an object above the content" rather than a docked strip.
  /// This constant is the whole width control: the capsule is
  /// `screen − 2 × margin`, so 18pt puts it at ~91% of the screen on any iPhone.
  ///
  /// Widening it widens every slot with it, so the selection pill gets more room
  /// to grow into and the labels more space between them, without either of those
  /// being touched here.
  static const navBarSideMargin = 18.0;

  /// Clearance between the capsule's bottom edge and the physical screen edge.
  ///
  /// Deliberately **not** the full `viewPadding.bottom`. That reserve is 34pt on a
  /// home-indicator device, but the indicator itself is only a ~5pt line sitting
  /// ~8pt up — so stacking a gap on top of the whole safe area parked the capsule
  /// 44pt off the edge and left a conspicuous empty band beneath it.
  ///
  /// 16pt is measured against the indicator rather than the safe area: it clears
  /// the top of that line, while keeping the capsule where a floating iOS bar
  /// actually sits.
  ///
  /// Device-independent by design: on a home-button device (`viewPadding.bottom`
  /// of 0) 16pt from the edge is equally correct, so no branch is needed.
  static const navBarBottomInset = 16.0;

  /// Inset of the selection pill from the capsule's own edges.
  ///
  /// Equal on all four sides, which is what makes the pill *concentric* with the
  /// capsule: both are fully-rounded, so the inner radius comes out at
  /// `navBarHeight / 2 - navBarPillInset` on its own and the gap to the rim stays
  /// constant all the way around the curve.
  ///
  /// A tighter *horizontal* inset is the trap here. It looks correct in the middle
  /// slots and fails at the two ends, where the capsule's own corner curves away
  /// from a pill that is still travelling straight — the first and last tabs then
  /// read as a blob bursting out of the bar rather than a pill sitting in it.
  /// Shrinking this value is safe in a way that shrinking one axis is not, because
  /// it keeps the two shapes concentric.
  ///
  /// 4 rather than 6: at the end slots the leftover space forms a visible crescent
  /// between the pill's cap and the capsule's, and 6pt of it read as the pill
  /// floating adrift of the bar rather than nested in it. The crescent is inherent
  /// to one rounded end inside another; the only lever on how big it looks is this.
  static const navBarPillInset = 4.0;

  /// Glyph size in the capsule. iOS tab icons do not change size on selection —
  /// the fill of the glyph and the pill behind it carry the state.
  static const navBarIconSize = 24.0;

  /// Air between the selection pill's ends and the label inside it.
  ///
  /// The pill is sized from this plus the label rather than from the slot it sits
  /// in, so that every destination gets the same breathing space. A slot-width
  /// pill gives whatever is left over — which across five tabs on a phone came to
  /// about 7pt around a word like "Courses", tight enough that the lozenge looked
  /// clamped onto the text.
  static const navBarPillPadding = 14.0;

  /// Floor for the pill's width, so a two-letter label still gets a lozenge rather
  /// than a circle around its glyph.
  static const navBarPillMinWidth = 52.0;

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
  /// Deliberately **lighter** than the app bar's 24→38, which is the opposite of
  /// where this started (60→68).
  ///
  /// The two surfaces are not the same problem. The app bar spans the full width
  /// and sits under the status bar, so it can afford to obliterate what passes
  /// beneath it. The capsule is a small object floating over the page, and the only
  /// thing that makes it read as *glass* rather than as a white slab with rounded
  /// ends is that you can see what it is on top of. Every increase in sigma trades
  /// that away: at 60 a card, a book cover and an empty background all render
  /// identically underneath it.
  ///
  /// 22 keeps shapes behind clearly recognisable — colour, position and outline all
  /// survive — while detail and text go soft. Roughly a 44px CSS blur.
  ///
  /// It sat at 14 while the tint carried the material at 38%. Now that the tint is
  /// down to 25% the frost *is* the material, which is what the reference bar does:
  /// the body of the surface comes from the blur, and the tint only has to give the
  /// selection pill something to sit on. The ceiling is the app bar's resting 24 —
  /// this capsule must stay the lighter of the two.
  ///
  /// Zeroed entirely under Reduce Transparency, like every other sigma.
  static const navBarBlurSigma = 22.0;
  static const navBarBlurSigmaScrolled = 28.0;

  /// Saturation multiplier applied to the capsule's blurred backdrop.
  ///
  /// Blurring averages colour toward grey, so a faithful blur of a vivid card comes
  /// back washed out. iOS compensates: its materials saturate what they blur, which
  /// is why colour bleeds *through* Apple's glass rather than fading under it.
  ///
  /// It rose from 1.18 with the sigma: 22 averages more colour to grey than 14 did,
  /// and with only 25% of tint left the colour bleeding through *is* the tell that
  /// this is glass. 1.3 remains the hard ceiling — past it the bleed stops reading
  /// as vibrancy and starts looking like a colour cast — so this sits just short of
  /// it. Retreat to 1.20 if a vivid card ever casts the capsule.
  ///
  /// Nav-capsule only. The app bar spans the full width, where the same boost would
  /// tint the whole header from whatever happened to scroll under its left edge.
  static const navBarSaturation = 1.26;

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
  ///
  /// 0.12 was already past that line in practice: at 18pt of displacement it split
  /// a card's hairline edge passing under the rim into a ~2px cyan stroke, which on
  /// a screenshot reads as a stray line rather than as glass. Half that keeps the
  /// split sub-pixel, where it tints the rim instead of drawing on it.
  static const chromeDispersion = 0.05;

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
