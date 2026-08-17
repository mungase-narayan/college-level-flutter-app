import 'package:flutter/material.dart';

import 'glass_specs.dart';

/// Every glass material value, carried on [ThemeData.extensions] so it travels
/// with the theme and interpolates when the theme animates.
///
/// The values are tuned against the app's existing palette in `app_colors.dart`
/// (dark base `#070711`, card `#0F0F1A`, primary `#8A63FE`; light base
/// `#F9FAFC`, card `#FFFFFF`, primary `#6E41DB`) rather than inventing a second
/// colour system. Only the *material* — translucency, blur, bevel, depth — is
/// new; hue and semantics still come from `SchemeColors`.
///
/// Read this through `context.glass` (see `glass_context.dart`), which resolves
/// accessibility settings on top of these raw values. Reading the extension
/// directly bypasses Reduce Transparency.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.isDark,
    required this.card,
    required this.control,
    required this.field,
    required this.chrome,
    required this.chromeScrolled,
    required this.navBar,
    required this.navBarScrolled,
    required this.overlay,
    required this.raised,
    required this.scrim,
    required this.pillTint,
    required this.pillBorder,
    required this.navPillTint,
    required this.navPillBorder,
  });

  final bool isDark;

  /// Content surfaces — cards, stat tiles, list rows. Simulated by default.
  final GlassSpec card;

  /// Small interactive controls sitting *on* a card: chips, switch tracks,
  /// segmented backgrounds, ghost buttons. Lighter than [card] so it reads as
  /// nested rather than as a second card.
  ///
  /// Not used by the search field — see [field], which diverged so that giving the
  /// search capsule a real bevel and a visible edge would not also restyle every
  /// chip, switch track and segmented background in the app.
  final GlassSpec control;

  /// Text fields that sit directly on the page rather than nested on a card —
  /// today the search capsule.
  ///
  /// Tints *against* the page in both schemes: darker than a light background,
  /// lighter than a dark one, the way iOS fills a search field. A white tint on
  /// light would simply vanish. What separates it from [control] is that it is a
  /// standalone surface, so it carries a visible hairline, a specular bevel and a
  /// whisper of contact shadow — the things that make it read as a piece of glass
  /// laid on the page instead of a recess cut into a card.
  final GlassSpec field;

  /// Navigation chrome at rest (nothing scrolled beneath it yet).
  final GlassSpec chrome;

  /// Navigation chrome once content has scrolled underneath. More opaque and
  /// more blurred, so text stays readable over arbitrary content. The app bar
  /// and nav bar interpolate between [chrome] and this as the user scrolls.
  final GlassSpec chromeScrolled;

  /// The floating nav capsule, at rest.
  ///
  /// A separate tier from [chrome] because it wants the opposite trade-off: much
  /// more translucent, paired with a much heavier blur, so the card passing
  /// underneath stays visible. Reusing the app bar's 65%/80% tint made the capsule
  /// read as solid white.
  final GlassSpec navBar;

  /// The capsule once content has scrolled beneath it — a little more opaque, so
  /// labels keep their contrast over arbitrary content.
  final GlassSpec navBarScrolled;

  /// Modal surfaces — bottom sheets, dialogs, popup menus. High opacity,
  /// because forms and long text sit on them.
  final GlassSpec overlay;

  /// Surfaces that float above everything with no backdrop of their own —
  /// the FAB and the toast. Strongest shadow in the system.
  final GlassSpec raised;

  /// The dim layer painted behind a modal.
  final Color scrim;

  /// Fill of the segmented control's thumb — a near-opaque indicator sitting on a
  /// surface with nothing behind it to show through.
  final Color pillTint;

  /// Hairline around that thumb.
  final Color pillBorder;

  /// Fill of the nav capsule's selection pill.
  ///
  /// Separate from [pillTint] because the two solve opposite problems. The
  /// segmented thumb sits on an opaque card and must read as solid; the nav pill
  /// sits on *glass*, with real content blurring past underneath it, and the point
  /// is that the content tints it. Rendering it near-opaque like the thumb is what
  /// made it a white lozenge painted on the glass rather than a second layer of it.
  ///
  /// So this is a genuinely translucent white, layered over the capsule's own tint
  /// rather than replacing it: glass on glass, which is where the reference gets
  /// its pale green over a green book cover.
  final Color navPillTint;

  /// Hairline around the nav pill. White at low opacity in both schemes — this rim
  /// is a light catch along the lozenge's edge, not a border drawn around it.
  final Color navPillBorder;

  // ── Presets ────────────────────────────────────────────────────────────────

  /// Dark glass. The app's default scheme.
  ///
  /// Dark glass needs a *lighter* tint than the background it sits on — the
  /// material behaves like frosted acrylic catching ambient light, so it lifts
  /// rather than recedes. Tinting downward is the classic mistake that makes
  /// dark glass read as a hole in the screen.
  static const dark = GlassTokens(
    isDark: true,
    card: GlassSpec(
      // `#0F0F1A` lifted ~5% toward white, at 72% opacity.
      tint: Color(0xB81C1C27),
      borderColor: Color(0x38FFFFFF), // white @ 22% — the brief's hairline
      highlightColor: Color(0x47FFFFFF), // white @ 28%
      opaqueFill: Color(0xFF14141F),
      shadow: [
        BoxShadow(
          color: Color(0x6B000000), // black @ 42%
          blurRadius: 34,
          offset: Offset(0, 12),
          spreadRadius: -6,
        ),
      ],
    ),
    control: GlassSpec(
      tint: Color(0x1FFFFFFF), // white @ 12%
      borderColor: Color(0x24FFFFFF), // white @ 14%
      highlightColor: Color(0x33FFFFFF), // white @ 20%
      opaqueFill: Color(0xFF1E1E2C),
      shadow: [],
    ),
    field: GlassSpec(
      // A few points brighter than `control` across the board: this one stands on
      // the page with nothing behind it to borrow definition from, where `control`
      // has a card under it doing half the work. Over `#070711` this lands around
      // `#2C2C35` — an iOS dark search field.
      tint: Color(0x26FFFFFF), // white @ 15%
      borderColor: Color(0x33FFFFFF), // white @ 20%
      highlightColor: Color(0x59FFFFFF), // white @ 35%
      opaqueFill: Color(0xFF1E1E2C),
      // None: a black shadow on a near-black page is invisible, the same reason
      // the nav pill goes without one in this scheme.
      shadow: [],
    ),
    chrome: GlassSpec(
      tint: Color(0xA61A1A28), // 65%
      borderColor: Color(0x2EFFFFFF), // white @ 18%
      highlightColor: Color(0x54FFFFFF), // white @ 33% — chrome bevel is brightest
      opaqueFill: Color(0xFF131320),
      shadow: [
        BoxShadow(
          color: Color(0x80000000), // black @ 50%
          blurRadius: 40,
          offset: Offset(0, 14),
          spreadRadius: -8,
        ),
      ],
    ),
    chromeScrolled: GlassSpec(
      tint: Color(0xCC1A1A28), // 80%
      borderColor: Color(0x3DFFFFFF), // white @ 24%
      highlightColor: Color(0x5CFFFFFF), // white @ 36%
      opaqueFill: Color(0xFF131320),
      shadow: [
        BoxShadow(
          color: Color(0x99000000), // black @ 60%
          blurRadius: 44,
          offset: Offset(0, 16),
          spreadRadius: -8,
        ),
      ],
    ),
    navBar: GlassSpec(
      // 24% — see-through by design, and over a *lifted* base rather than the
      // near-black one the other tiers use. At this little alpha a near-black tint
      // only subtracts light, which reads as a smoked hole punched in the page
      // instead of as frosted acrylic sitting on it.
      tint: Color(0x3D1F1F30),
      // In dark mode the hairline is the bright rim, and with this little fill it
      // carries the whole silhouette — so both it and the specular go up.
      borderColor: Color(0x52FFFFFF), // white @ 32%
      highlightColor: Color(0x75FFFFFF), // white @ 46%
      opaqueFill: Color(0xFF131320),
      shadow: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 40,
          offset: Offset(0, 14),
          spreadRadius: -8,
        ),
      ],
    ),
    navBarScrolled: GlassSpec(
      tint: Color(0x5C1F1F30), // 36% — keeps the resting state's +12 delta
      borderColor: Color(0x5CFFFFFF), // white @ 36%
      highlightColor: Color(0x80FFFFFF), // white @ 50%
      opaqueFill: Color(0xFF131320),
      shadow: [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 44,
          offset: Offset(0, 16),
          spreadRadius: -8,
        ),
      ],
    ),
    overlay: GlassSpec(
      tint: Color(0xD91A1A28), // 85%
      borderColor: Color(0x33FFFFFF), // white @ 20%
      highlightColor: Color(0x4DFFFFFF), // white @ 30%
      opaqueFill: Color(0xFF16161f),
      shadow: [
        BoxShadow(
          color: Color(0xA6000000),
          blurRadius: 48,
          offset: Offset(0, -8),
          spreadRadius: 0,
        ),
      ],
    ),
    raised: GlassSpec(
      tint: Color(0xE01F1F30), // 88%
      borderColor: Color(0x3DFFFFFF),
      highlightColor: Color(0x54FFFFFF),
      opaqueFill: Color(0xFF1B1B29),
      shadow: [
        BoxShadow(
          color: Color(0xB3000000), // black @ 70%
          blurRadius: 38,
          offset: Offset(0, 14),
          spreadRadius: -4,
        ),
      ],
    ),
    scrim: Color(0x80000000),
    pillTint: Color(0x2EFFFFFF),
    pillBorder: Color(0x33FFFFFF),
    // Brighter than the dark thumb, because on dark glass the pill has to lift
    // itself: there is no shadow to define it (black on near-black is invisible),
    // so its own luminance is the only thing separating it from the capsule.
    // Took back the 9 points of fill the capsule gave up, for the same reason the
    // light pill did: the selected state has to stay obvious on a thinner bar.
    navPillTint: Color(0x47FFFFFF), // white @ 28%
    navPillBorder: Color(0x5CFFFFFF), // white @ 36%
  );

  /// Light glass.
  ///
  /// Light glass tints *toward white* and relies on a subtle dark hairline for
  /// its edge — a white border on a white card would be invisible, so the
  /// specular highlight does the bevel work and the border does definition.
  static const light = GlassTokens(
    isDark: false,
    card: GlassSpec(
      tint: Color(0xE6FFFFFF), // white @ 90%
      borderColor: Color(0x1A11161F), // foreground @ 10%
      highlightColor: Color(0xD9FFFFFF), // white @ 85%
      opaqueFill: Color(0xFFFFFFFF),
      shadow: [
        BoxShadow(
          color: Color(0x1A000000), // black @ 10%
          blurRadius: 28,
          offset: Offset(0, 10),
          spreadRadius: -8,
        ),
      ],
    ),
    control: GlassSpec(
      tint: Color(0x14000000), // black @ 8%
      borderColor: Color(0x0F11161F), // foreground @ 6%
      highlightColor: Color(0xB3FFFFFF),
      opaqueFill: Color(0xFFEFF2F7), // scheme.muted
      shadow: [],
    ),
    field: GlassSpec(
      // 10% of a cool near-black rather than of pure black: over the `#F9FAFC`
      // page this resolves to about `#E1E3E6`, which is where iOS puts a light
      // search field. Hue-tinted so it reads as a material sampling a cool
      // backdrop rather than as a grey hole punched in the page.
      tint: Color(0x1A0B1220),
      // 12% against `control`'s 6%: nothing sits under this capsule to define its
      // edge, so the hairline has to do it alone.
      borderColor: Color(0x1F11161F),
      // A near-white bevel is what keeps a recessed fill reading as convex glass
      // instead of as a dent in the page.
      highlightColor: Color(0xE6FFFFFF),
      opaqueFill: Color(0xFFEFF2F7), // scheme.muted
      // None, in either scheme. A drop shadow reads as an object sitting *above*
      // the page; this capsule is meant to read as a hole cut into it, with the
      // page showing through. The hairline and the blurred backdrop do all of
      // the separating.
      shadow: [],
    ),
    chrome: GlassSpec(
      tint: Color(0xA6FFFFFF), // white @ 65%
      borderColor: Color(0x1411161F),
      highlightColor: Color(0xF2FFFFFF),
      opaqueFill: Color(0xFFFBFCFE), // scheme.sidebar
      shadow: [
        BoxShadow(
          color: Color(0x1F000000), // black @ 12%
          blurRadius: 32,
          offset: Offset(0, 12),
          spreadRadius: -10,
        ),
      ],
    ),
    chromeScrolled: GlassSpec(
      tint: Color(0xD9FFFFFF), // white @ 85%
      borderColor: Color(0x2111161F),
      highlightColor: Color(0xFFFFFFFF),
      opaqueFill: Color(0xFFFBFCFE),
      shadow: [
        BoxShadow(
          color: Color(0x29000000), // black @ 16%
          blurRadius: 36,
          offset: Offset(0, 14),
          spreadRadius: -10,
        ),
      ],
    ),
    navBar: GlassSpec(
      // 25% of a cool light grey rather than of white. Grey rather than white
      // because the capsule has to sit a shade below paper white for the selection
      // pill to have something to sit *on*. Thin because at 22 sigma the frost is
      // the material now — the tint's remaining job is that contrast with the pill,
      // not hiding the page. Any more and the capsule stops filtering and starts
      // covering.
      tint: Color(0x40E9ECF3),
      // Eased from 13%: against a fill this thin the dark hairline became the
      // loudest thing on the shape. The bright rim below defines the edge instead.
      borderColor: Color(0x1C11161F),
      highlightColor: Color(0xFFFFFFFF),
      opaqueFill: Color(0xFFFBFCFE),
      shadow: [
        // Deepened with the thinner fill: with less body of its own, the shadow
        // does more of the work of lifting the capsule off the page.
        BoxShadow(
          color: Color(0x24000000),
          blurRadius: 34,
          offset: Offset(0, 14),
          spreadRadius: -12,
        ),
      ],
    ),
    navBarScrolled: GlassSpec(
      // 39%. It is the *gap* to the resting tint, not the absolute, that makes the
      // ramp legible — so it tracked the resting value down and kept its ~14-point
      // delta. That gap is what keeps labels readable once a busy page is running
      // under the capsule, while staying well short of opaque: this is the state
      // the bar is in for most of a scroll.
      tint: Color(0x63E9ECF3),
      borderColor: Color(0x2411161F),
      highlightColor: Color(0xFFFFFFFF),
      opaqueFill: Color(0xFFFBFCFE),
      shadow: [
        BoxShadow(
          color: Color(0x29000000),
          blurRadius: 36,
          offset: Offset(0, 14),
          spreadRadius: -10,
        ),
      ],
    ),
    overlay: GlassSpec(
      tint: Color(0xF2FFFFFF), // white @ 95%
      borderColor: Color(0x1A11161F),
      highlightColor: Color(0xFFFFFFFF),
      opaqueFill: Color(0xFFFFFFFF),
      shadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 44,
          offset: Offset(0, -6),
          spreadRadius: 0,
        ),
      ],
    ),
    raised: GlassSpec(
      tint: Color(0xF7FFFFFF), // white @ 97%
      borderColor: Color(0x1F11161F),
      highlightColor: Color(0xFFFFFFFF),
      opaqueFill: Color(0xFFFFFFFF),
      shadow: [
        BoxShadow(
          color: Color(0x2E000000), // black @ 18%
          blurRadius: 34,
          offset: Offset(0, 12),
          spreadRadius: -4,
        ),
      ],
    ),
    scrim: Color(0x47000000),
    pillTint: Color(0xF2FFFFFF),
    pillBorder: Color(0x1411161F),
    // 56% white *on top of* the capsule's own 25% tint — around 67% effective,
    // which is opaque enough to read as a distinct lozenge and translucent enough
    // that a coloured card blurring past underneath still tints it. It rose with
    // the capsule's fall so the pill would not weaken alongside it: coverage is
    // unchanged, but the contrast against the bare capsule goes from 28 points to
    // 42, which is what makes the selected tab obvious. The silhouette over plain
    // white content comes from the pill's shadow, not from this alpha.
    navPillTint: Color(0x8FFFFFFF), // white @ 56%
    navPillBorder: Color(0x3DFFFFFF), // white @ 24%
  );

  static GlassTokens of(bool isDark) => isDark ? dark : light;

  // ── ThemeExtension ─────────────────────────────────────────────────────────

  @override
  GlassTokens copyWith({
    bool? isDark,
    GlassSpec? card,
    GlassSpec? control,
    GlassSpec? field,
    GlassSpec? chrome,
    GlassSpec? chromeScrolled,
    GlassSpec? navBar,
    GlassSpec? navBarScrolled,
    GlassSpec? overlay,
    GlassSpec? raised,
    Color? scrim,
    Color? pillTint,
    Color? pillBorder,
    Color? navPillTint,
    Color? navPillBorder,
  }) =>
      GlassTokens(
        isDark: isDark ?? this.isDark,
        card: card ?? this.card,
        control: control ?? this.control,
        field: field ?? this.field,
        chrome: chrome ?? this.chrome,
        chromeScrolled: chromeScrolled ?? this.chromeScrolled,
        navBar: navBar ?? this.navBar,
        navBarScrolled: navBarScrolled ?? this.navBarScrolled,
        overlay: overlay ?? this.overlay,
        raised: raised ?? this.raised,
        scrim: scrim ?? this.scrim,
        pillTint: pillTint ?? this.pillTint,
        pillBorder: pillBorder ?? this.pillBorder,
        navPillTint: navPillTint ?? this.navPillTint,
        navPillBorder: navPillBorder ?? this.navPillBorder,
      );

  /// Truly interpolates, unlike the sibling `AppTokens.lerp` which snaps at the
  /// halfway point. Glass is a continuous material, so a light↔dark switch
  /// should cross-fade the translucency rather than cut between two looks.
  @override
  GlassTokens lerp(covariant GlassTokens? other, double t) {
    if (other == null) return this;
    return GlassTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      card: GlassSpec.lerp(card, other.card, t),
      control: GlassSpec.lerp(control, other.control, t),
      field: GlassSpec.lerp(field, other.field, t),
      chrome: GlassSpec.lerp(chrome, other.chrome, t),
      chromeScrolled: GlassSpec.lerp(chromeScrolled, other.chromeScrolled, t),
      navBar: GlassSpec.lerp(navBar, other.navBar, t),
      navBarScrolled: GlassSpec.lerp(navBarScrolled, other.navBarScrolled, t),
      overlay: GlassSpec.lerp(overlay, other.overlay, t),
      raised: GlassSpec.lerp(raised, other.raised, t),
      scrim: Color.lerp(scrim, other.scrim, t)!,
      pillTint: Color.lerp(pillTint, other.pillTint, t)!,
      pillBorder: Color.lerp(pillBorder, other.pillBorder, t)!,
      navPillTint: Color.lerp(navPillTint, other.navPillTint, t)!,
      navPillBorder: Color.lerp(navPillBorder, other.navPillBorder, t)!,
    );
  }
}
