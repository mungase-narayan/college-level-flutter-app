import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder, NoDefaultCupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../config/theme/app_theme.dart';
import 'glass_specs.dart';
import 'glass_tokens.dart';
import 'glass_typography.dart';

/// The iOS [ThemeData], built by layering glass onto the existing Material theme
/// rather than by rebuilding it.
///
/// `LiquidGlassTheme.dark` is `AppTheme.dark.copyWith(...)`, which matters for
/// two reasons:
///
/// * **Android cannot regress.** `app_theme.dart` is not modified at all, so
///   `AppTheme.light` / `AppTheme.dark` still emit exactly what they emitted
///   before this design layer existed.
/// * **One source of truth for colour.** The `ColorScheme`, the palette, the
///   status tones and the type scale keep coming from `AppTheme`; only the
///   *material* — translucency, blur, bevel, depth, motion — is added here.
///
/// The component-level overrides below all point the same direction: strip the
/// Material chrome that the glass widgets replace, so a stray `Card`,
/// `AppBar` or `BottomSheet` cannot paint an opaque Material surface on top of
/// the glass one.
abstract final class LiquidGlassTheme {
  static ThemeData get light => _build(AppTheme.light, GlassTokens.light);
  static ThemeData get dark => _build(AppTheme.dark, GlassTokens.dark);

  static ThemeData _build(ThemeData base, GlassTokens glass) {
    final textTheme = GlassTypography.refine(base.textTheme);

    return base.copyWith(
      platform: TargetPlatform.iOS,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // `GlassBackdrop`, mounted once from `MaterialApp.builder`, owns the base
      // colour now. Every Scaffold must therefore be transparent or it would
      // paint an opaque rectangle over the gradient the glass samples — and the
      // chrome's blur would resolve to flat grey.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,

      // Preserve `AppTokens` — every existing screen reads `context.scheme`
      // through it, so dropping it here would throw at the first build.
      //
      // Left unannotated deliberately: `ThemeExtension` is F-bounded
      // (`T extends ThemeExtension<T>`), so writing the element type out as
      // `ThemeExtension<dynamic>` resolves to its bound and fails to compile.
      extensions: [...base.extensions.values, glass],

      // ── Motion ──────────────────────────────────────────────────────────────
      // iOS has no ink ripple. Press feedback is scale + opacity + haptics,
      // applied by `GlassPressable`, so the ripple is removed rather than
      // restyled — an InkWell splash inside a translucent surface also smears
      // visibly against the blur.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ── Chrome the glass widgets draw themselves ────────────────────────────
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true, // iOS centres compact titles
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: glass.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // `showModalBottomSheet` and `showDialog` are still the presentation
      // mechanism; the glass widget is the *content*. Making the Material
      // container transparent lets the glass surface own the whole visual.
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        modalElevation: 0,
        elevation: 0,
        // The glass sheet draws its own grabber, positioned over the blur.
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: GlassRadius.sheetTop),
      ),

      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassRadius.all(GlassRadius.lg),
        ),
      ),

      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassRadius.all(GlassRadius.md),
        ),
      ),

      cardTheme: base.cardTheme.copyWith(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassRadius.all(GlassRadius.lg),
        ),
      ),

      // The Material `NavigationBar` is not used on iOS — the floating capsule
      // replaces it — but a transparent theme keeps any stray instance from
      // punching an opaque strip through the glass.
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
      ),

      drawerTheme: base.drawerTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // Inputs are wrapped in a glass container that draws the fill and the
      // hairline, so the Material decoration contributes nothing but layout and
      // the error/focus text.
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GlassSpacing.lg,
          vertical: 14,
        ),
      ),

      // iOS uses a thinner separator than Material's 1dp at full opacity.
      dividerTheme: base.dividerTheme.copyWith(
        color: glass.card.borderColor,
        thickness: 0.5,
        space: 0.5,
      ),

      // Cupertino's own widgets (`CupertinoActivityIndicator`, the text
      // selection handles, the scroll bounce) should match the resolved scheme.
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: glass.isDark ? Brightness.dark : Brightness.light,
        primaryColor: base.colorScheme.primary,
      ),
    );
  }
}
