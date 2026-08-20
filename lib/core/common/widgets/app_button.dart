import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_button.dart';

enum AppButtonVariant { primary, outline, ghost, destructive }

enum AppButtonSize { xs, sm, md, lg }

/// The shared button, covering the shadcn variants the React app uses
/// (`default`, `outline`, `ghost`, `destructive`) plus a built-in busy state so
/// callers don't hand-roll a spinner for every mutation.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      // Heights are identical across the two enums (30 / 38 / 48 / 54), so swapping
      // in the glass branch never reflows a screen. The Material branch below
      // needs `shrinkWrap` to hold to that — its default tap-target padding
      // silently floors every button at 48.
      return LiquidGlassButton(
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        expand: expand,
        variant: switch (variant) {
          AppButtonVariant.primary => GlassButtonVariant.primary,
          AppButtonVariant.outline => GlassButtonVariant.outline,
          AppButtonVariant.ghost => GlassButtonVariant.ghost,
          AppButtonVariant.destructive => GlassButtonVariant.destructive,
        },
        size: switch (size) {
          AppButtonSize.xs => GlassButtonSize.xs,
          AppButtonSize.sm => GlassButtonSize.sm,
          AppButtonSize.md => GlassButtonSize.md,
          AppButtonSize.lg => GlassButtonSize.lg,
        },
      );
    }

    final scheme = context.scheme;
    final height = switch (size) {
      AppButtonSize.xs => AppTheme.controlHeightXs,
      AppButtonSize.sm => AppTheme.controlHeightSm,
      AppButtonSize.md => AppTheme.controlHeightMd,
      AppButtonSize.lg => AppTheme.controlHeightLg,
    };
    // A busy button must not fire again mid-flight.
    final enabled = onPressed != null && !isLoading;
    // `xs` is the badge size: the Material default padding and label would keep
    // it visually large even once its height is 30, so both come down with it.
    final compact = size == AppButtonSize.xs;
    final compactPadding =
        compact ? const EdgeInsets.symmetric(horizontal: 12) : null;
    final compactTextStyle =
        compact ? Theme.of(context).textTheme.labelMedium : null;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: switch (size) {
            AppButtonSize.xs => 14.0,
            AppButtonSize.sm => 16.0,
            _ => 18.0,
          }),
        if (isLoading || icon != null) const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: compactPadding,
            textStyle: compactTextStyle,
          ),
          child: child,
        ),
      AppButtonVariant.destructive => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: compactPadding,
            textStyle: compactTextStyle,
            backgroundColor: scheme.destructive,
            foregroundColor: Colors.white,
          ),
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: compactPadding,
            textStyle: compactTextStyle,
          ),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: scheme.foreground,
            textStyle: compactTextStyle,
            padding: compactPadding ?? const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: child,
        ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
