import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../theme/glass_typography.dart';
import '../utils/glass_haptics.dart';
import '../utils/glass_scroll.dart';
import 'liquid_glass_container.dart';

/// One destination in a [LiquidGlassNavigationBar].
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The floating Liquid Glass navigation bar: a frosted capsule inset from the
/// screen edges, with a selection pill that springs between destinations.
///
/// The bar is deliberately *not* full-width. A floating capsule is what makes
/// content visibly continue past it on all sides — the effect that sells the
/// glass — whereas a bar pinned to the screen edges reads as an opaque strip no
/// matter how translucent it is.
///
/// Frosting intensifies as content scrolls beneath it (sigma 24 → 38, tint
/// 65% → 80%), driven by the shell's [GlassScrollNotifier] through a
/// [ValueListenableBuilder] so only this widget rebuilds during a scroll.
class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.scrollOffset,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Ambient source is used when null.
  final ValueListenable<double>? scrollOffset;

  @override
  Widget build(BuildContext context) {
    final notifier = GlassScrollScope.maybeOf(context);
    final listenable = scrollOffset ?? notifier;

    if (listenable == null) {
      return _NavBarSurface(
        items: items,
        currentIndex: currentIndex,
        onSelected: onSelected,
        frost: 0,
      );
    }

    final surface = ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, offset, _) => _NavBarSurface(
        items: items,
        currentIndex: currentIndex,
        onSelected: onSelected,
        frost: glassScrollProgress(offset, GlassMetrics.chromeScrollRamp),
      ),
    );

    // Tucks the capsule away while reading downward, so the content reads
    // full-bleed, and brings it back the moment the user scrolls up.
    //
    // A translate is legitimate here in a way it never was for the top header:
    // the capsule already floats *above* the content (which is padded clear of it
    // and scrolls underneath), so sliding it off-screen reveals content rather
    // than the hole a translated header would leave.
    if (notifier == null) return surface;

    return ValueListenableBuilder<bool>(
      valueListenable: notifier.chromeHidden,
      builder: (context, hidden, child) {
        final glass = context.glass;
        return AnimatedSlide(
          offset: Offset(0, hidden ? 1.4 : 0),
          duration: glass.duration(GlassDurations.base),
          curve: GlassCurves.easeOutExpo,
          child: IgnorePointer(
            // Unreachable once tucked away, so a tap in the vacated strip hits
            // the content beneath instead of an invisible tab.
            ignoring: hidden,
            child: child,
          ),
        );
      },
      child: surface,
    );
  }
}

class _NavBarSurface extends StatelessWidget {
  const _NavBarSurface({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.frost,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final double frost;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final media = MediaQuery.of(context);

    if (items.isEmpty) return const SizedBox.shrink();

    // Dynamic Type must grow the capsule rather than clip its labels. Clamped
    // because the icon+label stack stops being the right layout well before the
    // largest accessibility sizes, and an unbounded height would eat the screen.
    final textScale = media.textScaler.scale(1.0).clamp(1.0, 1.6);
    final height = GlassMetrics.navBarHeight * (1 + (textScale - 1) * 0.5);

    return Padding(
      padding: const EdgeInsets.only(
        left: GlassMetrics.navBarSideMargin,
        right: GlassMetrics.navBarSideMargin,
        // Measured from the physical screen edge, not from the safe area: adding
        // the full 34pt `viewPadding.bottom` on top of a gap parked the capsule
        // 44pt up and left an obvious empty band beneath it. See
        // `GlassMetrics.navBarBottomInset`.
        bottom: GlassMetrics.navBarBottomInset,
      ),
      child: LiquidGlassContainer(
        blur: GlassBlur.chrome,
        // A capsule-specific material, not the app bar's: heavy blur (60) paired
        // with a translucent tint (44%), so the card scrolling underneath reads
        // through it as blurred glass instead of disappearing behind flat white.
        sigmaOverride: glass.navBarSigma(frost),
        spec: glass.navBarAt(frost),
        // Real glass is a lens, not just frosted film: the content behind the
        // capsule is bent and colour-split at the rim. That edge distortion is what
        // separates this from a blurred rectangle. Falls back to plain blur where
        // the shader is unavailable.
        refract: true,
        radius: GlassRadius.capsule,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;

              return Stack(
                children: [
                  // The selection pill, sliding on a spring so it settles with a
                  // slight overshoot — the "snap" of an iOS control.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: currentIndex.toDouble()),
                    duration: glass.duration(GlassDurations.base),
                    curve: GlassCurves.spring,
                    builder: (context, position, _) => Positioned(
                      left: position * itemWidth + 4,
                      top: 5,
                      bottom: 5,
                      width: itemWidth - 8,
                      child: LiquidGlassContainer(
                        spec: glass.card.copyWith(
                          tint: glass.pillTint,
                          borderColor: glass.pillBorder,
                        ),
                        radius: GlassRadius.capsule,
                        // No shadow: the pill is embedded *in* the glass, not
                        // floating above it. A shadow here would read as a second
                        // floating object inside the capsule.
                        showShadow: false,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, item) in items.indexed)
                        Expanded(
                          child: _NavDestination(
                            item: item,
                            selected: i == currentIndex,
                            onTap: () {
                              // Fires even when re-tapping the active tab, since
                              // that is a meaningful action (scroll to top, or
                              // re-open the menu sheet).
                              GlassHaptics.selection();
                              onSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    final color = selected ? scheme.sidebarPrimary : scheme.sidebarForeground;
    final duration = glass.duration(GlassDurations.base);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Only the visual is excluded, not the gesture. Putting
        // `excludeSemantics` on the Semantics above would also drop the
        // GestureDetector's tap action, leaving VoiceOver a label it cannot
        // activate — the label is announced above, so just silence the Text.
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cross-fading the two glyphs is smoother than swapping them,
              // which reads as a flicker at 60fps.
              AnimatedSwitcher(
                duration: duration,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: GlassCurves.easeOutSmooth,
                style: GlassTypography.navLabel(color, selected: selected),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
