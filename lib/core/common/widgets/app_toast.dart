import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_toast.dart';
import '../../error/failures.dart';

enum ToastKind { success, error, warning }

/// Port of `src/lib/toast.lib.tsx` — a custom sonner renderer with a leading
/// icon chip and an auto-dismiss progress bar, tinted emerald / red / amber.
///
/// Uses an overlay rather than a `SnackBar` so the progress bar can animate and
/// the toast can sit above bottom navigation.
class AppToast {
  const AppToast._();

  static const _duration = Duration(seconds: 4);

  static void success(BuildContext context, String message) =>
      _show(context, message, ToastKind.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, ToastKind.error);

  static void warning(BuildContext context, String message) =>
      _show(context, message, ToastKind.warning);

  /// Shows the message a [Failure] carries, expanding a [ValidationFailure]
  /// into its `• field: message` lines.
  static void failure(BuildContext context, Failure failure) => error(
        context,
        failure is ValidationFailure ? failure.detailedMessage : failure.message,
      );

  static void _show(BuildContext context, String message, ToastKind kind) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // The theme and the glass materials must be captured from the app's context,
    // not read inside the builder — an OverlayEntry builds against the Overlay's
    // own context, which sits outside both.
    final theme = Theme.of(context);
    final glass = context.useGlass ? context.glass : null;
    final (shade, icon) = _toneFor(kind);

    late OverlayEntry entry;
    void dismiss() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => glass != null
          ? LiquidGlassToastCard(
              message: message,
              shade: shade,
              icon: icon,
              duration: _duration,
              theme: theme,
              glass: glass,
              onDismissed: dismiss,
            )
          : _ToastCard(
              message: message,
              kind: kind,
              duration: _duration,
              theme: theme,
              onDismissed: dismiss,
            ),
    );
    overlay.insert(entry);
  }

  /// The emerald / red / amber mapping, shared by both renderers so the two
  /// platforms cannot drift on what a success or an error looks like.
  static (TwShade, IconData) _toneFor(ToastKind kind) => switch (kind) {
        ToastKind.success => (TwColors.emerald, Icons.check_rounded),
        ToastKind.error => (TwColors.red, Icons.close_rounded),
        ToastKind.warning => (TwColors.amber, Icons.priority_high_rounded),
      };
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.kind,
    required this.duration,
    required this.theme,
    required this.onDismissed,
  });

  final String message;
  final ToastKind kind;
  final Duration duration;
  final ThemeData theme;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDismissed();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.theme.extension<AppTokens>()!;
    final scheme = tokens.scheme;
    final (shade, icon) = switch (widget.kind) {
      ToastKind.success => (TwColors.emerald, Icons.check_rounded),
      ToastKind.error => (TwColors.red, Icons.close_rounded),
      ToastKind.warning => (TwColors.amber, Icons.priority_high_rounded),
    };
    final tone = tokens.tone(shade);

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 24,
      child: Theme(
        data: widget.theme,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            // Fade in over the first 12% of the run, hold, fade out at the end.
            opacity: TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 76),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
            ]).animate(_controller),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.popover,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: scheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: tone.background,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Icon(icon, size: 16, color: tone.foreground),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: widget.theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: widget.onDismissed,
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: scheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The `shrink` keyframe animation on the sonner progress bar.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) => LinearProgressIndicator(
                      value: 1 - _controller.value,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(tone.foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
