import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../platform/glass_scope.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_insets.dart';
import 'liquid_glass_container.dart';

/// The glass toast card — the iOS counterpart to `AppToast`'s `_ToastCard`.
///
/// Two things about this widget are load-bearing:
///
/// **It receives [theme] and [glass] explicitly** rather than reading them from
/// `context`. It is built inside an [OverlayEntry], whose builder context sits at
/// the `Overlay` itself; passing them down is how the existing Material toast
/// already solves this, and the same reason applies here.
///
/// **It lifts itself above the floating nav capsule.** The root overlay sits
/// *above* the shell, so it cannot see the shell's published insets — the
/// capsule's height is therefore read from the [GlassMetrics] constants, which
/// exist precisely for consumers that cannot measure the chrome.
class LiquidGlassToastCard extends StatefulWidget {
  const LiquidGlassToastCard({
    super.key,
    required this.message,
    required this.shade,
    required this.icon,
    required this.duration,
    required this.theme,
    required this.glass,
    required this.onDismissed,
  });

  final String message;
  final TwShade shade;
  final IconData icon;
  final Duration duration;
  final ThemeData theme;
  final ResolvedGlass glass;
  final VoidCallback onDismissed;

  @override
  State<LiquidGlassToastCard> createState() => _LiquidGlassToastCardState();
}

class _LiquidGlassToastCardState extends State<LiquidGlassToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Set once the user swipes or taps it away, so the auto-dismiss timer cannot
  /// fire a second removal on an already-removed entry.
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final glass = widget.glass;
    final tokens = theme.extension<AppTokens>()!;
    final scheme = tokens.scheme;
    final tone = tokens.tone(widget.shade);

    return Positioned(
      left: GlassSpacing.lg,
      right: GlassSpacing.lg,
      // Clears the floating capsule rather than sitting behind it.
      bottom: GlassInsetsMath.navBarTopFromBottom() + GlassSpacing.md,
      child: Theme(
        data: theme,
        child: FadeTransition(
          // Fade in over the first 12% of the run, hold, fade out at the end —
          // the same envelope as the Material toast, so timing is unchanged.
          opacity: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
            TweenSequenceItem(tween: ConstantTween(1.0), weight: 76),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
          ]).animate(_controller),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _controller,
                // Rises into place over the same 12% window as the fade-in, then
                // holds — `Interval` clamps it there for the rest of the run.
                curve: const Interval(0, 0.12, curve: GlassCurves.easeOutExpo),
              ),
            ),
            child: Dismissible(
              key: const ValueKey('glass-toast'),
              // Flicking a notification away is the native gesture; iOS has no
              // equivalent of tapping a tiny close target.
              direction: DismissDirection.horizontal,
              onDismissed: (_) => _dismiss(),
              child: LiquidGlassContainer(
                blur: GlassBlur.thick,
                spec: glass.raised,
                radius: GlassRadius.md,
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
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: tone.foreground.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 16,
                              color: tone.foreground,
                            ),
                          ),
                          const SizedBox(width: GlassSpacing.md),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: GlassSpacing.sm),
                          GestureDetector(
                            onTap: _dismiss,
                            behavior: HitTestBehavior.opaque,
                            child: Semantics(
                              button: true,
                              label: 'Dismiss',
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: scheme.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The auto-dismiss countdown, matching the web app's sonner
                    // progress bar.
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) => LinearProgressIndicator(
                        value: 1 - _controller.value,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(
                          tone.foreground.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
