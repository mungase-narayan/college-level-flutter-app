import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'liquid_glass_button.dart';
import 'liquid_glass_container.dart';

/// A glass alert — the iOS counterpart to `showAppConfirmDialog`.
///
/// Unlike a bottom sheet, an alert covers the whole screen, so it gets a
/// full-screen **blurred** barrier rather than a flat dim. That blur is the
/// signature of an iOS alert: the app behind is pushed out of focus rather than
/// merely darkened.
///
/// `showGeneralDialog` is used instead of `showDialog` because only it grants
/// control of the barrier's own subtree, which is where a [BackdropFilter] has to
/// live to blur what is behind it.
Future<T?> showLiquidGlassDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final glass = context.glass;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Painted by the animated blur below instead, so it can ramp with the route.
    barrierColor: Colors.transparent,
    transitionDuration: glass.duration(GlassDurations.base),
    pageBuilder: (context, animation, secondaryAnimation) =>
        Builder(builder: builder),
    transitionBuilder: (context, animation, secondary, child) {
      final t = GlassCurves.easeOutSmooth.transform(
        animation.value.clamp(0.0, 1.0),
      );

      return Stack(
        children: [
          Positioned.fill(child: _BlurredBarrier(progress: t)),
          // An iOS alert scales up from just under full size as it fades in — a
          // small movement that reads as the alert arriving from behind the glass.
          Center(
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.94 + 0.06 * GlassCurves.spring.transform(t),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The confirmation alert used before deletes, submissions and log-out.
///
/// Signature and return semantics match `showAppConfirmDialog` exactly — `true`
/// when confirmed, `false` otherwise — so all of its call sites are unaffected.
Future<bool> showLiquidGlassConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showLiquidGlassDialog<bool>(
    context,
    builder: (context) => LiquidGlassDialog(
      title: title,
      message: message,
      actions: [
        LiquidGlassDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        LiquidGlassDialogAction(
          label: confirmLabel,
          isDefault: true,
          isDestructive: destructive,
          onPressed: () {
            // A destructive commit deserves to be felt, not just seen.
            if (destructive) {
              GlassHaptics.heavy();
            } else {
              GlassHaptics.light();
            }
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );
  return result ?? false;
}

/// One button in a [LiquidGlassDialog]'s action row.
class LiquidGlassDialogAction {
  const LiquidGlassDialogAction({
    required this.label,
    required this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Rendered prominently. At most one action should set this.
  final bool isDefault;

  final bool isDestructive;
}

/// The alert surface itself. Use [showLiquidGlassDialog] to present it.
class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const [],
  });

  final String title;
  final String? message;

  /// Replaces [message] with arbitrary content, for dialogs that host a form.
  final Widget? content;

  final List<LiquidGlassDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = context.glass;
    final message = this.message;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.xxl),
      child: ConstrainedBox(
        // iOS alerts are narrow — around 270pt — and do not stretch to fill a
        // wide screen.
        constraints: const BoxConstraints(maxWidth: 300),
        child: LiquidGlassContainer(
          blur: GlassBlur.thick,
          spec: glass.overlay,
          radius: GlassRadius.lg,
          padding: const EdgeInsets.fromLTRB(
            GlassSpacing.xl,
            GlassSpacing.xl,
            GlassSpacing.xl,
            GlassSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: GlassSpacing.sm),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.scheme.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: GlassSpacing.lg),
                content!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: GlassSpacing.xl),
                _Actions(actions: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions});

  final List<LiquidGlassDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    // Three or more actions cannot fit side by side at 300pt without truncating,
    // so they stack — the same threshold iOS uses.
    final stacked = actions.length > 2;

    final buttons = [
      for (final action in actions)
        LiquidGlassButton(
          label: action.label,
          onPressed: action.onPressed,
          expand: stacked,
          size: GlassButtonSize.sm,
          variant: switch ((action.isDefault, action.isDestructive)) {
            (_, true) => GlassButtonVariant.destructive,
            (true, false) => GlassButtonVariant.primary,
            (false, false) => GlassButtonVariant.glass,
          },
        ),
    ];

    if (stacked) {
      return Column(
        children: [
          for (final (i, button) in buttons.indexed) ...[
            if (i > 0) const SizedBox(height: GlassSpacing.sm),
            button,
          ],
        ],
      );
    }

    return Row(
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: GlassSpacing.sm),
          Expanded(child: button),
        ],
      ],
    );
  }
}

/// A barrier that blurs as well as dims, ramping with the route's animation so
/// the app behind appears to recede out of focus.
class _BlurredBarrier extends StatelessWidget {
  const _BlurredBarrier({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    if (progress <= 0) return const SizedBox.shrink();

    Widget barrier = ColoredBox(
      color: glass.scrim.withValues(alpha: glass.scrim.a * progress),
    );

    final sigma = glass.sigmaOf(12 * progress);
    if (sigma > 0) {
      barrier = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: barrier,
      );
    }

    // The barrier animates every frame of the transition, so isolating it keeps
    // the rest of the screen from re-rasterising along with it.
    return RepaintBoundary(child: barrier);
  }
}
