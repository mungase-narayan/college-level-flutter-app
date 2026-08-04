import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../extensions/glass_context.dart';
import '../animations/glass_press.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// Glass button variants, one-to-one with `AppButtonVariant` so the adaptive
/// branch in `app_button.dart` is a direct mapping — plus [glass], which has no
/// Material equivalent and is used inside chrome and sheets.
enum GlassButtonVariant { primary, outline, ghost, destructive, glass }

/// Glass button sizes. Heights match `AppButtonSize` exactly (38 / 48 / 54) so
/// swapping in the glass branch never reflows a screen.
enum GlassButtonSize {
  sm(38, 16, 15),
  md(48, 20, 17),
  lg(54, 24, 17);

  const GlassButtonSize(this.height, this.horizontalPadding, this.iconSize);

  final double height;
  final double horizontalPadding;
  final double iconSize;
}

/// The iOS counterpart to `AppButton`.
///
/// A prominent iOS 26 button is *tinted glass*, not flat fill: the brand colour
/// sits at high but not full opacity, with a specular top edge and a glow that
/// blooms on press, so light appears to pass through the control. [primary] and
/// [destructive] render that; [outline], [ghost] and [glass] are progressively
/// quieter.
///
/// Press feedback (scale, opacity, glow, haptics) comes from [GlassPressable], so
/// it is identical to every other tappable glass surface.
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.size = GlassButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final IconData? icon;

  /// Shows a spinner and blocks the tap, so a busy button cannot fire twice.
  final bool isLoading;

  final bool expand;

  /// Defaults to a capsule when compact and to [GlassRadius.md] when expanded —
  /// matching iOS, which capsules small controls but uses a continuous rounded
  /// rect for full-width calls to action.
  final double? radius;

  /// Replaces the label row entirely, for buttons whose content is not text.
  final Widget? child;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    final resolvedRadius =
        radius ?? (expand ? GlassRadius.md : GlassRadius.capsule);

    final (spec, foreground, glow) = switch (variant) {
      GlassButtonVariant.primary => (
          glass.card.copyWith(
            // Not fully opaque: the backdrop bleeding through at 6% is what
            // separates tinted glass from flat paint.
            tint: scheme.primary.withValues(alpha: 0.94),
            borderColor: Colors.white.withValues(alpha: 0.30),
            highlightColor: Colors.white.withValues(alpha: 0.45),
          ),
          scheme.primaryForeground,
          scheme.primary,
        ),
      GlassButtonVariant.destructive => (
          glass.card.copyWith(
            tint: scheme.destructive.withValues(alpha: 0.94),
            borderColor: Colors.white.withValues(alpha: 0.28),
            highlightColor: Colors.white.withValues(alpha: 0.42),
          ),
          Colors.white,
          scheme.destructive,
        ),
      GlassButtonVariant.outline => (
          glass.control.copyWith(
            tint: const Color(0x00000000),
            borderColor: glass.card.borderColor,
          ),
          scheme.foreground,
          null,
        ),
      GlassButtonVariant.ghost => (
          glass.control.copyWith(
            tint: const Color(0x00000000),
            borderColor: const Color(0x00000000),
            highlightColor: const Color(0x00000000),
          ),
          scheme.foreground,
          null,
        ),
      GlassButtonVariant.glass => (glass.control, scheme.foreground, null),
    };

    // A disabled button loses its glow and most of its presence, but keeps its
    // shape so the layout does not shift.
    final opacity = _enabled ? 1.0 : 0.45;

    final content = child ??
        DefaultTextStyle.merge(
          style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: size.iconSize,
                  height: size.iconSize,
                  child: CupertinoActivityIndicator(
                    radius: size.iconSize / 2,
                    color: foreground,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: size.iconSize, color: foreground),
              if (isLoading || icon != null)
                const SizedBox(width: GlassSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );

    Widget button = LiquidGlassContainer(
      spec: spec,
      radius: resolvedRadius,
      // Ghost and outline buttons sit inline in content; a drop shadow there
      // would read as a floating card rather than as a button.
      showShadow: variant == GlassButtonVariant.primary ||
          variant == GlassButtonVariant.destructive,
      constraints: BoxConstraints(minHeight: size.height),
      padding: EdgeInsets.symmetric(horizontal: size.horizontalPadding),
      child: Center(
        // `widthFactor: 1` keeps a non-expanding button hugging its content
        // instead of stretching to the parent's width.
        widthFactor: expand ? null : 1.0,
        child: content,
      ),
    );

    if (opacity < 1) {
      button = Opacity(opacity: opacity, child: button);
    }

    button = GlassPressable(
      onTap: _enabled ? onPressed : null,
      glowColor: glow,
      borderRadius: BorderRadius.circular(resolvedRadius),
      pressedScale: 0.955,
      semanticLabel: label,
      child: button,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
