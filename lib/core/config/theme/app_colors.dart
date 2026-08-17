import 'package:flutter/material.dart';

/// The design tokens from `college-level-frontend/src/index.css`.
///
/// The CSS declares every token in OKLCH; these are the exact sRGB values a
/// browser computes for them. (The hand-written comment in that file —
/// `bg #14111e < sidebar #1a1724 < card #201c2d` — describes the *intent* of
/// the dark elevation ladder, not the values the OKLCH triples actually
/// resolve to; the numbers below are the ones that render.)
class AppColors {
  const AppColors._();

  /// `:root` — the light scheme.
  static const light = SchemeColors(
    background: Color(0xFFF9FAFC),
    foreground: Color(0xFF11161F),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF11161F),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF11161F),
    primary: Color(0xFF6E41DB),
    primaryForeground: Color(0xFFFBFBFF),
    secondary: Color(0xFFEFF2F7),
    secondaryForeground: Color(0xFF252E3D),
    muted: Color(0xFFEFF2F7),
    mutedForeground: Color(0xFF5D646F),
    accent: Color(0xFFDFECFF),
    accentForeground: Color(0xFF112D55),
    destructive: Color(0xFFE7000B),
    border: Color(0xFFE1E5EA),
    input: Color(0xFFE1E5EA),
    ring: Color(0xFF6E41DB),
    sidebar: Color(0xFFFBFCFE),
    sidebarForeground: Color(0xFF50565E),
    sidebarPrimary: Color(0xFF6E41DB),
    sidebarPrimaryForeground: Color(0xFFFBFBFF),
    sidebarAccent: Color(0xFFEAE7FF),
    sidebarAccentForeground: Color(0xFF2F215B),
    sidebarBorder: Color(0xFFE4E4EA),
    chart: [
      Color(0xFF6E41DB), // violet
      Color(0xFFD79800), // amber
      Color(0xFF00945A), // teal
      Color(0xFFC33DBD), // pink
      Color(0xFFF04C5A), // orange
    ],
  );

  /// `.dark` — the app's default scheme (React ships
  /// `<ThemeProvider defaultTheme="dark">`).
  static const dark = SchemeColors(
    background: Color(0xFF070711),
    foreground: Color(0xFFE7E7ED),
    card: Color(0xFF0F0F1A),
    cardForeground: Color(0xFFE7E7ED),
    popover: Color(0xFF0F0F1A),
    popoverForeground: Color(0xFFE7E7ED),
    primary: Color(0xFF8A63FE),
    primaryForeground: Color(0xFFF8F8FC),
    secondary: Color(0xFF191926),
    secondaryForeground: Color(0xFFD6D7DE),
    muted: Color(0xFF191926),
    mutedForeground: Color(0xFF7E7E92),
    accent: Color(0xFF252437),
    accentForeground: Color(0xFFE7E7ED),
    destructive: Color(0xFFF83E54),
    // The dark CSS uses `oklch(1 0 0 / 9%)` and `/ 11%` — white at low alpha.
    border: Color(0x17FFFFFF),
    input: Color(0x1CFFFFFF),
    ring: Color(0xFF8A63FE),
    sidebar: Color(0xFF0B0B15),
    sidebarForeground: Color(0xFF8D8D9E),
    sidebarPrimary: Color(0xFF8A63FE),
    sidebarPrimaryForeground: Color(0xFFF8F8FC),
    sidebarAccent: Color(0xFF191926),
    sidebarAccentForeground: Color(0xFFE7E7ED),
    sidebarBorder: Color(0x17FFFFFF),
    chart: [
      Color(0xFF8A63FE),
      Color(0xFFEBAB00),
      Color(0xFF00AF67),
      Color(0xFFD961D2),
      Color(0xFFF83E54),
    ],
  );
}

/// One complete colour scheme (`:root` or `.dark`).
class SchemeColors {
  const SchemeColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.border,
    required this.input,
    required this.ring,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.chart,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color border;
  final Color input;
  final Color ring;
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final List<Color> chart;
}

/// The Tailwind utility colours the React app reaches for directly on status
/// badges (`src/constants/course-type.constants.ts` and friends), rather than
/// going through the semantic tokens.
///
/// The badge idiom is
/// `bg-<c>-500/15 text-<c>-700 dark:bg-<c>-400/15 dark:text-<c>-300`, which
/// [StatusTone] reproduces.
class TwColors {
  const TwColors._();

  static const blue = TwShade(Color(0xFF93C5FD), Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF1D4ED8));
  static const emerald = TwShade(Color(0xFF6EE7B7), Color(0xFF34D399), Color(0xFF10B981), Color(0xFF047857));
  static const amber = TwShade(Color(0xFFFCD34D), Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFB45309));
  static const red = TwShade(Color(0xFFFCA5A5), Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFB91C1C));
  static const rose = TwShade(Color(0xFFFDA4AF), Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFBE123C));
  static const slate = TwShade(Color(0xFFCBD5E1), Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF334155));
  static const teal = TwShade(Color(0xFF5EEAD4), Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E));
  static const purple = TwShade(Color(0xFFD8B4FE), Color(0xFFC084FC), Color(0xFFA855F7), Color(0xFF7E22CE));
  static const indigo = TwShade(Color(0xFFA5B4FC), Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFF4338CA));
  static const orange = TwShade(Color(0xFFFDBA74), Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFC2410C));
  static const violet = TwShade(Color(0xFFC4B5FD), Color(0xFFA78BFA), Color(0xFF8B5CF6), Color(0xFF6D28D9));
  static const cyan = TwShade(Color(0xFF67E8F9), Color(0xFF22D3EE), Color(0xFF06B6D4), Color(0xFF0E7490));
  static const pink = TwShade(Color(0xFFF9A8D4), Color(0xFFF472B6), Color(0xFFEC4899), Color(0xFFBE185D));
}

/// Parses a `#rrggbb` colour as the API sends it — a course's `colorCode`, a
/// rating tier's tint — returning null when it is absent or malformed.
///
/// The API's colours are free-form strings set by a teacher, so anything from
/// an empty field to `rgb(1,2,3)` can arrive; every caller wants the same
/// "usable colour, or fall back to the theme" answer.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// The four Tailwind shades the badge idiom needs.
class TwShade {
  const TwShade(this.s300, this.s400, this.s500, this.s700);

  final Color s300;
  final Color s400;
  final Color s500;
  final Color s700;
}

/// Resolves a [TwShade] into the background/foreground pair for a status badge,
/// honouring the light/dark split in the Tailwind class string.
class StatusTone {
  const StatusTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  factory StatusTone.of(TwShade shade, {required bool isDark}) => StatusTone(
        // `bg-<c>-500/15` light, `dark:bg-<c>-400/15` dark.
        (isDark ? shade.s400 : shade.s500).withValues(alpha: 0.15),
        // `text-<c>-700` light, `dark:text-<c>-300` dark.
        isDark ? shade.s300 : shade.s700,
      );
}
