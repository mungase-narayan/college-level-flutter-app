import 'package:flutter/material.dart';

import '../../common/widgets/app_card.dart';
import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// The iOS counterpart to `AppCard` — the surface almost every screen sits on.
///
/// Mirrors `AppCard`'s API so the adaptive branch in `app_card.dart` is a
/// straight hand-off and no call site has to change.
///
/// Renders simulated glass by default (see [LiquidGlassContainer] on blur cost).
/// Pass `blur: GlassBlur.regular` for a card that genuinely overlaps imagery,
/// such as one laid over a course thumbnail.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.radius = GlassRadius.lg,
    this.blur = GlassBlur.none,
    this.margin,
    this.color,
    this.borderColor,
    this.selected = false,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final GlassBlur blur;
  final EdgeInsetsGeometry? margin;

  /// Overrides the glass tint. Maps from `AppCard.color`.
  final Color? color;

  /// Overrides the hairline. Maps from `AppCard.borderColor`.
  final Color? borderColor;

  /// Lifts the card with a primary-tinted edge and highlight — for the active
  /// item in a list, or a selected option in a picker.
  final bool selected;

  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final scheme = context.scheme;

    final base = borderColor == null
        ? glass.card
        : glass.card.copyWith(borderColor: borderColor);

    // Selecting a card brightens its edge rather than filling it, so a list of
    // them stays scannable — the same restraint iOS shows on a checked row.
    final selectedSpec = glass.card.copyWith(
      borderColor: scheme.primary.withValues(alpha: 0.55),
      highlightColor: scheme.primary.withValues(alpha: 0.40),
    );

    Widget surface;
    if (borderColor != null) {
      // An explicit border wins outright; nothing to interpolate.
      surface = _surface(base);
    } else {
      // The edge is drawn by a CustomPainter, so there is no implicit animation
      // to lean on — interpolate the spec itself and let the painter follow.
      surface = TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1.0 : 0.0),
        duration: glass.duration(GlassDurations.base),
        curve: GlassCurves.easeOutSmooth,
        builder: (context, t, _) => _surface(
          t == 0 ? base : GlassSpec.lerp(base, selectedSpec, t),
        ),
      );
    }

    if (onTap != null || onLongPress != null) {
      surface = GlassPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        // Large surfaces travel less under the finger than small ones do, or the
        // movement reads as the whole screen shifting.
        pressedScale: 0.985,
        pressedOpacity: 0.92,
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      );
    }

    return margin == null ? surface : Padding(padding: margin!, child: surface);
  }

  Widget _surface(GlassSpec spec) => LiquidGlassContainer(
        blur: blur,
        spec: spec,
        radius: radius,
        padding: padding,
        tintOverride: color,
        showShadow: showShadow,
        child: child,
      );
}

/// A card with a title row and optional trailing action — the glass counterpart
/// to `AppSectionCard`, the shape most dashboard panels take.
class LiquidGlassSectionCard extends StatelessWidget {
  const LiquidGlassSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shared with the Material variant so the two platforms cannot drift
          // on where the icon sits relative to the heading.
          SectionCardHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            trailing: trailing,
            gap: GlassSpacing.sm,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
