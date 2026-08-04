/// The Liquid Glass design system — Apple's iOS 26 material language, applied
/// on iOS only.
///
/// One import for the whole library, mirroring `core/common/widgets/widgets.dart`.
///
/// ## How it plugs in
///
/// Nothing in this library is wired into screens directly. Instead the app's
/// existing shared widgets (`AppCard`, `AppButton`, `AppInput`, `showAppSheet`,
/// `AppToast`, …) branch internally on `context.useGlass`:
///
/// ```dart
/// if (context.useGlass) return LiquidGlassCard(...);
/// return /* the original Material tree, untouched */;
/// ```
///
/// Because every screen already renders through those widgets, the entire iOS UI
/// converts without a single screen file being edited — and Android is provably
/// unchanged, since its branch is the original code verbatim.
///
/// ## The one platform seam
///
/// `AppPlatform.useGlass`, read everywhere through `context.useGlass`. No other
/// platform check exists in the codebase.
///
/// ## Where blur is spent
///
/// `GlassBlur.none` is the default and renders *simulated* glass — layered tint,
/// specular highlight, hairline and shadow, with no `BackdropFilter`. Real blur is
/// reserved for chrome and overlays, where content genuinely passes underneath.
/// See `LiquidGlassContainer` for the full reasoning; it is the most important
/// performance decision in the system.
library;

// ── Platform ────────────────────────────────────────────────────────────────
export 'platform/app_platform.dart';
export 'platform/glass_scope.dart';

// ── Theme ───────────────────────────────────────────────────────────────────
export 'theme/glass_specs.dart';
export 'theme/glass_tokens.dart';
export 'theme/glass_typography.dart';
export 'theme/liquid_glass_theme.dart';

// ── Animation ───────────────────────────────────────────────────────────────
export 'animations/glass_curves.dart';
export 'animations/glass_press.dart';

// ── Extensions & utilities ──────────────────────────────────────────────────
export 'extensions/glass_context.dart';
export 'utils/glass_haptics.dart';
export 'utils/glass_insets.dart';
export 'utils/glass_refraction.dart';
export 'utils/glass_scroll.dart';

// ── Widgets ─────────────────────────────────────────────────────────────────
export 'widgets/glass_backdrop.dart';
export 'widgets/liquid_glass_app_bar.dart';
export 'widgets/liquid_glass_bottom_sheet.dart';
export 'widgets/liquid_glass_button.dart';
export 'widgets/liquid_glass_card.dart';
export 'widgets/liquid_glass_chip.dart';
export 'widgets/liquid_glass_container.dart';
export 'widgets/liquid_glass_dialog.dart';
export 'widgets/liquid_glass_fab.dart';
export 'widgets/liquid_glass_input.dart';
export 'widgets/liquid_glass_list_tile.dart';
export 'widgets/liquid_glass_menu.dart';
export 'widgets/liquid_glass_navigation_bar.dart';
export 'widgets/liquid_glass_search_bar.dart';
export 'widgets/liquid_glass_segmented_control.dart';
export 'widgets/liquid_glass_switch.dart';
export 'widgets/liquid_glass_toast.dart';
export 'widgets/sliver_liquid_glass_app_bar.dart';
