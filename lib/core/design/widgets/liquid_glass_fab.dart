import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// A floating action button in glass.
///
/// One of the few content-adjacent surfaces that earns a real [BackdropFilter]:
/// it floats over scrolling content with nothing of its own behind it, so the
/// content genuinely passes underneath and there is something worth blurring.
///
/// Set [label] for the extended form, which iOS uses for a primary action that
/// needs naming.
class LiquidGlassFAB extends StatelessWidget {
  const LiquidGlassFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.tinted = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// When set, renders an extended capsule with the label beside the icon.
  final String? label;

  final String? tooltip;

  /// Fills with the brand colour. Clear this for a neutral glass FAB that sits
  /// more quietly over busy content.
  final bool tinted;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final label = this.label;

    final spec = tinted
        ? glass.raised.copyWith(
            tint: scheme.primary.withValues(alpha: 0.88),
            borderColor: Colors.white.withValues(alpha: 0.32),
            highlightColor: Colors.white.withValues(alpha: 0.48),
          )
        : glass.raised;

    final foreground = tinted ? scheme.primaryForeground : scheme.foreground;

    final content = label == null
        ? Icon(icon, size: 24, color: foreground)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: GlassSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          );

    // The only control in the app that genuinely floats over live content, so
    // it is the only one that gets the real refracting renderer rather than
    // [GlassSurface]'s fake one. Everything else sits on a card or an opaque
    // footer, where there is nothing behind to bend.
    //
    // Reduce Transparency drops to the in-house container, which resolves to an
    // opaque fill with no filter at all.
    final glassBody = Center(child: content);
    final padded = Padding(
      padding: label == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: GlassSpacing.xl),
      child: glassBody,
    );

    final button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: _size, minHeight: _size),
      child: glass.reduceTransparency
          ? LiquidGlassContainer(
              spec: spec,
              radius: GlassRadius.capsule,
              child: padded,
            )
          : LiquidGlass.withOwnLayer(
              shape: const LiquidRoundedSuperellipse(
                borderRadius: _size / 2,
              ),
              settings: LiquidGlassSettings(
                // The tint is high-opacity, so the lensing reads only at the
                // rim — but that is exactly where it matters for a floating
                // control.
                glassColor: spec.tint,
                thickness: _size * 0.25,
                blur: 8,
                chromaticAberration: 0.02,
                refractiveIndex: 1.25,
                lightIntensity: 0.6,
                ambientStrength: 0.15,
                saturation: 1.2,
              ),
              child: padded,
            ),
    );

    final pressable = GlassPressable(
      onTap: onPressed,
      glowColor: tinted ? scheme.primary : null,
      borderRadius: BorderRadius.circular(GlassRadius.capsule),
      pressedScale: 0.92,
      // See LiquidGlassButton: an opacity layer would blank the refraction.
      pressedOpacity: 1.0,
      semanticLabel: tooltip ?? label,
      child: button,
    );

    return tooltip == null
        ? pressable
        : Tooltip(message: tooltip!, child: pressable);
  }
}
