import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens Material's [ThemeData] has no slot for — the sidebar ramp, the
/// chart ramp, and the raw scheme so widgets can reach `muted`/`accent`
/// directly the way the React components reach the CSS variables.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.scheme, required this.isDark});

  final SchemeColors scheme;
  final bool isDark;

  /// Status badge tones, ported from the ad-hoc Tailwind palette the React app
  /// uses on badges (`emerald` = active/present/correct, `amber` =
  /// pending/draft/late/medium, `red` = archived/rejected/hard, and so on).
  StatusTone tone(TwShade shade) => StatusTone.of(shade, isDark: isDark);

  StatusTone get success => tone(TwColors.emerald);
  StatusTone get warning => tone(TwColors.amber);
  StatusTone get danger => tone(TwColors.red);
  StatusTone get neutral => tone(TwColors.slate);
  StatusTone get info => tone(TwColors.blue);
  StatusTone get brand => tone(TwColors.violet);

  @override
  AppTokens copyWith({SchemeColors? scheme, bool? isDark}) =>
      AppTokens(scheme: scheme ?? this.scheme, isDark: isDark ?? this.isDark);

  /// The scheme is a discrete light/dark pair, so snap at the halfway point
  /// rather than interpolating into an in-between palette.
  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience access: `context.tokens.scheme.muted`.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  SchemeColors get scheme => tokens.scheme;
}

class AppTheme {
  const AppTheme._();

  /// `--radius` is 0.1rem in the CSS, but real UI overrides it with literal
  /// `rounded-xl` / `rounded-2xl` almost everywhere — so those are the values
  /// worth porting.
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(SchemeColors s, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: s.primary,
      onPrimary: s.primaryForeground,
      secondary: s.secondary,
      onSecondary: s.secondaryForeground,
      error: s.destructive,
      onError: isDark ? const Color(0xFF1A0508) : Colors.white,
      surface: s.background,
      onSurface: s.foreground,
      surfaceContainerLowest: s.background,
      surfaceContainerLow: s.sidebar,
      surfaceContainer: s.card,
      surfaceContainerHigh: s.muted,
      surfaceContainerHighest: s.accent,
      onSurfaceVariant: s.mutedForeground,
      outline: s.border,
      outlineVariant: s.border,
      tertiary: s.accent,
      onTertiary: s.accentForeground,
    );

    final textTheme = _textTheme(s);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: s.background,
      canvasColor: s.background,
      dividerColor: s.border,
      textTheme: textTheme,
      extensions: [AppTokens(scheme: s, isDark: isDark)],

      appBarTheme: AppBarTheme(
        backgroundColor: s.background,
        foregroundColor: s.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),

      cardTheme: CardThemeData(
        color: s.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          // `border-border/60` — the React card border is 60% opacity.
          side: BorderSide(color: s.border.withValues(alpha: 0.6)),
        ),
      ),

      dividerTheme: DividerThemeData(color: s.border, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? s.card : s.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: s.mutedForeground),
        border: _inputBorder(s.input),
        enabledBorder: _inputBorder(s.input),
        focusedBorder: _inputBorder(s.ring, width: 1.5),
        errorBorder: _inputBorder(s.destructive),
        focusedErrorBorder: _inputBorder(s.destructive, width: 1.5),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: s.primary,
          foregroundColor: s.primaryForeground,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.foreground,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: s.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: s.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: s.muted,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: s.sidebar,
        selectedItemColor: s.sidebarPrimary,
        unselectedItemColor: s.sidebarForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.sidebar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: s.sidebarAccent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? s.sidebarPrimary
                : s.sidebarForeground,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? s.sidebarPrimary
                : s.sidebarForeground,
          ),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: s.sidebar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: s.popover,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: s.mutedForeground),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.popover,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: s.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: s.primary,
        unselectedLabelColor: s.mutedForeground,
        indicatorColor: s.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: s.border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.muted,
        circularTrackColor: s.muted,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? s.primaryForeground : s.mutedForeground,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? s.primary : s.muted,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.popover,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: s.mutedForeground,
        textColor: s.foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),

      iconTheme: IconThemeData(color: s.foreground, size: 20),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );

  /// The CSS forces `Figtree Variable` globally (`--font-sans`) with
  /// `JetBrains Mono Variable` re-forced onto code blocks (`.markdown-code`).
  ///
  /// Neither font file ships with the repo, so no `fontFamily` is set on the
  /// theme — the app renders in the platform sans. Drop the variable TTFs into
  /// `assets/fonts/`, declare them in `pubspec.yaml`, then set
  /// `fontFamily: sans` on the theme and `fontFamily: mono` on code styles.
  static const sans = 'Figtree';
  static const mono = 'JetBrainsMono';

  /// The custom type scale from `index.css`, which sits ~1–2px above the
  /// Tailwind defaults:
  /// `xs 13 / sm 15 / base 17 / lg 19 / xl 21 / 2xl 26 / 3xl 32 / 4xl 40`.
  static TextTheme _textTheme(SchemeColors s) => TextTheme(
        displayLarge: TextStyle(fontSize: 40, height: 2.9 / 2.5, fontWeight: FontWeight.w700, color: s.foreground),
        displayMedium: TextStyle(fontSize: 32, height: 2.4 / 2, fontWeight: FontWeight.w700, color: s.foreground),
        displaySmall: TextStyle(fontSize: 26, height: 2.1 / 1.625, fontWeight: FontWeight.w700, color: s.foreground),
        headlineMedium: TextStyle(fontSize: 26, height: 2.1 / 1.625, fontWeight: FontWeight.w600, color: s.foreground),
        headlineSmall: TextStyle(fontSize: 21, height: 1.85 / 1.3125, fontWeight: FontWeight.w600, color: s.foreground),
        titleLarge: TextStyle(fontSize: 19, height: 1.8 / 1.1875, fontWeight: FontWeight.w600, color: s.foreground),
        titleMedium: TextStyle(fontSize: 17, height: 1.625 / 1.0625, fontWeight: FontWeight.w600, color: s.foreground),
        titleSmall: TextStyle(fontSize: 15, height: 1.375 / 0.9375, fontWeight: FontWeight.w600, color: s.foreground),
        bodyLarge: TextStyle(fontSize: 17, height: 1.625 / 1.0625, color: s.foreground),
        bodyMedium: TextStyle(fontSize: 15, height: 1.375 / 0.9375, color: s.foreground),
        bodySmall: TextStyle(fontSize: 13, height: 1.125 / 0.8125, color: s.mutedForeground),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.foreground),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.foreground),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: s.mutedForeground),
      );
}
