import 'package:flutter/material.dart';

import '../theme/glass_specs.dart';
import '../theme/glass_tokens.dart';

/// [GlassTokens] with the user's accessibility settings already applied.
///
/// Widgets never read the raw theme extension; they read this. That way Reduce
/// Transparency and Reduce Motion are honoured in exactly one place instead of
/// being re-implemented (and inevitably forgotten) in fifteen widgets.
@immutable
class ResolvedGlass {
  const ResolvedGlass({
    required this.tokens,
    required this.reduceTransparency,
    required this.reduceMotion,
  });

  final GlassTokens tokens;

  /// When true, every glass surface becomes opaque and all blur is dropped.
  ///
  /// Flutter exposes no direct signal for iOS's "Reduce Transparency" toggle, so
  /// this is driven by an in-app setting (see `ReduceTransparencyCubit`, surfaced
  /// on the Settings screen) OR-ed with [MediaQueryData.highContrast], which maps
  /// from `UIAccessibilityDarkerSystemColorsEnabled` and is the closest system
  /// signal available.
  final bool reduceTransparency;

  /// Mirrors [MediaQueryData.disableAnimations] — iOS "Reduce Motion".
  final bool reduceMotion;

  bool get isDark => tokens.isDark;

  // ── Specs, accessibility-resolved ──────────────────────────────────────────

  GlassSpec get card => _resolve(tokens.card);
  GlassSpec get control => _resolve(tokens.control);
  GlassSpec get field => _resolve(tokens.field);
  GlassSpec get chrome => _resolve(tokens.chrome);
  GlassSpec get chromeScrolled => _resolve(tokens.chromeScrolled);
  GlassSpec get overlay => _resolve(tokens.overlay);
  GlassSpec get raised => _resolve(tokens.raised);

  GlassSpec _resolve(GlassSpec spec) =>
      reduceTransparency ? spec.toOpaque() : spec;

  GlassSpec get navBar => _resolve(tokens.navBar);
  GlassSpec get navBarScrolled => _resolve(tokens.navBarScrolled);

  /// Interpolates chrome between its resting and scrolled states.
  ///
  /// [progress] is 0 at rest and 1 once content has scrolled beneath the bar.
  GlassSpec chromeAt(double progress) {
    if (progress <= 0) return chrome;
    if (progress >= 1) return chromeScrolled;
    return GlassSpec.lerp(chrome, chromeScrolled, progress);
  }

  /// The floating nav capsule's material at a given scroll [progress].
  GlassSpec navBarAt(double progress) {
    if (progress <= 0) return navBar;
    if (progress >= 1) return navBarScrolled;
    return GlassSpec.lerp(navBar, navBarScrolled, progress);
  }

  /// Blur for the capsule — deliberately lighter than the app bar's, because the
  /// capsule is a small object floating over the page and has to keep showing what
  /// it sits on. Its thin tint is what makes that possible. See
  /// [GlassMetrics.navBarBlurSigma].
  double navBarSigma(double progress) => sigmaOf(
        GlassMetrics.navBarBlurSigma +
            (GlassMetrics.navBarBlurSigmaScrolled -
                    GlassMetrics.navBarBlurSigma) *
                progress.clamp(0.0, 1.0),
      );

  /// The dim layer behind a modal. Deepened under Reduce Transparency, where the
  /// sheet itself is opaque and the scrim carries all of the separation.
  Color get scrim => reduceTransparency
      ? tokens.scrim.withValues(alpha: isDark ? 0.72 : 0.42)
      : tokens.scrim;

  Color get pillTint => reduceTransparency
      ? Color.alphaBlend(tokens.pillTint, tokens.card.opaqueFill)
      : tokens.pillTint;

  Color get pillBorder => tokens.pillBorder;

  /// The nav capsule's selection pill — translucent by design, so that the blurred
  /// content passing under the capsule tints it too.
  ///
  /// Under Reduce Transparency it collapses onto the capsule's own opaque fill —
  /// that surface, not the card's, is what is actually behind it once the blur is
  /// gone.
  ///
  /// The result is a *faint* fill in the light scheme, because an opaque near-white
  /// pill on an opaque near-white bar has nowhere to go. That is why
  /// [navPillBorder] switches to a hairline there rather than a light catch: with
  /// no translucency left to distinguish the two surfaces, the outline has to. The
  /// selected tab is in any case carried by the accent-coloured glyph, the heavier
  /// label and the `selected` semantics flag, none of which depend on the pill.
  Color get navPillTint => reduceTransparency
      ? Color.alphaBlend(tokens.navPillTint, tokens.navBar.opaqueFill)
      : tokens.navPillTint;

  /// A white light-catch normally; the solid indicator hairline under Reduce
  /// Transparency, where it is the only thing outlining the pill.
  Color get navPillBorder =>
      reduceTransparency ? tokens.pillBorder : tokens.navPillBorder;

  // ── Blur, accessibility-resolved ───────────────────────────────────────────

  /// Sigma for a named blur level — always 0 under Reduce Transparency, which is
  /// what makes that setting genuinely cheaper as well as more legible.
  double sigma(GlassBlur blur) => reduceTransparency ? 0 : blur.sigma;

  /// Sigma for an interpolated value (the chrome ramps its blur while scrolling).
  double sigmaOf(double value) => reduceTransparency ? 0 : value;

  /// Blur for chrome at a given scroll [progress]: ramps up as content passes
  /// underneath, so the bar frosts over exactly when it needs to.
  double chromeSigma(double progress) => sigmaOf(
        GlassBlur.regular.sigma +
            (GlassBlur.thick.sigma + 4 - GlassBlur.regular.sigma) *
                progress.clamp(0.0, 1.0),
      );

  // ── Motion, accessibility-resolved ─────────────────────────────────────────

  /// Collapses to [Duration.zero] under Reduce Motion, so animated widgets snap
  /// to their target state instead of travelling.
  Duration duration(Duration value) => reduceMotion ? Duration.zero : value;

  /// Under Reduce Motion a spring's overshoot is exactly the kind of movement the
  /// setting exists to suppress, so curves flatten to linear.
  Curve curve(Curve value) => reduceMotion ? Curves.linear : value;

  /// Scale factor for press feedback — 1.0 (no movement) under Reduce Motion.
  double pressScale(double value) => reduceMotion ? 1.0 : value;

  @override
  bool operator ==(Object other) =>
      other is ResolvedGlass &&
      other.tokens == tokens &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(tokens, reduceTransparency, reduceMotion);
}

/// Resolves [GlassTokens] against the theme and the platform's accessibility
/// settings, then publishes the result to the subtree.
///
/// Mounted once, from `MaterialApp.builder` in `lib/app.dart`.
class GlassScope extends StatelessWidget {
  const GlassScope({
    super.key,
    required this.child,
    this.reduceTransparency = false,
  });

  final Widget child;

  /// The in-app "Reduce transparency" preference. OR-ed with the system's
  /// high-contrast signal.
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    // Fall back to the preset matching the current brightness when the theme
    // carries no glass extension — which is the case on Android, and in tests
    // that pump a bare MaterialApp.
    final tokens = theme.extension<GlassTokens>() ??
        GlassTokens.of(theme.brightness == Brightness.dark);

    return _GlassScopeData(
      data: ResolvedGlass(
        tokens: tokens,
        reduceTransparency: reduceTransparency || media.highContrast,
        reduceMotion: media.disableAnimations,
      ),
      child: child,
    );
  }
}

class _GlassScopeData extends InheritedWidget {
  const _GlassScopeData({required this.data, required super.child});

  final ResolvedGlass data;

  static ResolvedGlass? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassScopeData>()?.data;

  @override
  bool updateShouldNotify(_GlassScopeData oldWidget) => data != oldWidget.data;
}

/// Internal accessor used by the `context.glass` extension.
///
/// Resolves from the nearest [GlassScope] when one exists, and otherwise derives
/// a correct value straight from the ambient theme and [MediaQuery]. That
/// fallback is what lets every glass widget be used standalone — in a test, in a
/// preview, or on a drill-down screen mounted above the shell — without a scope
/// wrapper.
ResolvedGlass resolveGlass(BuildContext context) {
  final scoped = _GlassScopeData.maybeOf(context);
  if (scoped != null) return scoped;

  final theme = Theme.of(context);
  final media = MediaQuery.maybeOf(context);

  return ResolvedGlass(
    tokens: theme.extension<GlassTokens>() ??
        GlassTokens.of(theme.brightness == Brightness.dark),
    reduceTransparency: media?.highContrast ?? false,
    reduceMotion: media?.disableAnimations ?? false,
  );
}
