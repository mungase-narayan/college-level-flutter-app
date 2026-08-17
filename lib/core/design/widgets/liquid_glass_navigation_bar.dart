import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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
/// Frosting intensifies as content scrolls beneath it (sigma 22 → 28, tint
/// 25% → 39%), driven by the shell's [GlassScrollNotifier] through a
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

  /// Anchors for the geometry tests.
  ///
  /// They used to locate these two by position among the bar's glass containers
  /// — `.first` for the capsule, `.last` for the pill — which silently pointed at
  /// the wrong widget the moment the capsule stopped being one of them. Keys say
  /// which is which.
  @visibleForTesting
  static const capsuleKey = ValueKey<String>('nav-capsule');

  @visibleForTesting
  static const pillKey = ValueKey<String>('nav-pill');

  @override
  Widget build(BuildContext context) {
    final notifier = GlassScrollScope.maybeOf(context);
    final listenable = scrollOffset ?? notifier;

    // Measured here rather than inside the surface, which rebuilds on every
    // frame of a scroll as the frost ramps: laying out five TextPainters per
    // frame to compute a value that only changes with the labels or the text
    // scale would be pure waste.
    final labelWidths = _measureLabelWidths(context, items);

    if (listenable == null) {
      return _NavBarSurface(
        items: items,
        currentIndex: currentIndex,
        onSelected: onSelected,
        labelWidths: labelWidths,
        frost: 0,
      );
    }

    final surface = ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, offset, _) => _NavBarSurface(
        items: items,
        currentIndex: currentIndex,
        onSelected: onSelected,
        labelWidths: labelWidths,
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

/// Laid-out width of each destination's label, in logical pixels.
///
/// The selection pill is sized from these rather than from its slot, so it can
/// keep a constant breathing space around whatever word it is behind — see
/// [_SelectionPill].
///
/// Measured at the *selected* weight, which is the heavier of the two: sizing to
/// the unselected width would leave the pill a hair too tight for the very label
/// it ends up sitting behind.
List<double> _measureLabelWidths(BuildContext context, List<GlassNavItem> items) {
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  // Colour is irrelevant to metrics; the weight and size are not.
  final style = GlassTypography.navLabel(
    const Color(0xFF000000),
    selected: true,
  );

  return [
    for (final item in items)
      (TextPainter(
        text: TextSpan(text: item.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout())
          .width,
  ];
}

class _NavBarSurface extends StatelessWidget {
  const _NavBarSurface({
    required this.items,
    required this.labelWidths,
    required this.currentIndex,
    required this.onSelected,
    required this.frost,
  });

  final List<GlassNavItem> items;
  final List<double> labelWidths;
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

    final contents = SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;

          return Stack(
            children: [
              _SelectionPill(
                index: currentIndex,
                itemWidth: itemWidth,
                trackWidth: constraints.maxWidth,
                labelWidths: labelWidths,
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
    );

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
      child: glass.reduceTransparency
          // No lensing, no blur, no translucency — the whole point of the
          // setting. The in-house container already resolves to an opaque fill,
          // so this path stays exactly what it has always been.
          ? LiquidGlassContainer(
              key: LiquidGlassNavigationBar.capsuleKey,
              spec: glass.navBarAt(frost),
              radius: GlassRadius.capsule,
              child: contents,
            )
          : _RefractingCapsule(
              key: LiquidGlassNavigationBar.capsuleKey,
              spec: glass.navBarAt(frost),
              height: height,
              frost: frost,
              child: contents,
            ),
    );
  }
}

/// The capsule surface, rendered by `liquid_glass_renderer`.
///
/// The in-house [LiquidGlassContainer] fakes a lens by displacing a blurred
/// backdrop at the rim. This is the real thing: a raymarched surface with a
/// refractive index and a thickness, so content passing underneath bends around
/// the edge and splits into colour the way it does on iOS 26. That difference is
/// the whole reason the package is here — nothing else in the app uses it.
///
/// The tint still comes from [GlassTokens], at roughly half its alpha: the token
/// was tuned for a surface whose body came from frost, and this one gets its body
/// from the glass itself. Any more fill and the lensing is what gets hidden.
class _RefractingCapsule extends StatelessWidget {
  const _RefractingCapsule({
    super.key,
    required this.spec,
    required this.height,
    required this.frost,
    required this.child,
  });

  final GlassSpec spec;
  final double height;
  final double frost;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = spec.tint;

    return LiquidGlass.withOwnLayer(
      shape: LiquidRoundedSuperellipse(borderRadius: height / 2),
      settings: LiquidGlassSettings(
        // Half the token's alpha — see the class docs.
        glassColor: tint.withValues(alpha: tint.a * 0.5),
        // Thickness is what the lens is made of: it sets how far the rim bends
        // what is behind it. Sized against the capsule so the bend stays in
        // proportion when Dynamic Type grows the bar.
        thickness: height * 0.28,
        // Far less frost than the fallback's 22 sigma. The refraction is doing
        // the work of separating the bar from the page now, and a heavy blur
        // would smear away the very content the lensing is bending.
        blur: 6 + 4 * frost,
        chromaticAberration: 0.02,
        refractiveIndex: 1.25,
        lightIntensity: 0.6,
        ambientStrength: 0.15,
        saturation: GlassMetrics.navBarSaturation,
      ),
      child: child,
    );
  }
}

/// The lozenge behind the selected destination.
///
/// Two things separate this from a rectangle that slides: it re-aims from wherever
/// it currently *is* when the selection changes mid-flight, and it stretches along
/// the direction of travel and settles back — the surface-tension read that gives
/// Liquid Glass its name. A rigid block translating between slots is the tell of a
/// bar that merely looks like iOS.
class _SelectionPill extends StatefulWidget {
  const _SelectionPill({
    required this.index,
    required this.itemWidth,
    required this.trackWidth,
    required this.labelWidths,
  });

  final int index;

  /// Width of one destination slot. Positions the pill; no longer sizes it.
  final double itemWidth;

  /// Interior width of the capsule, used to keep the pill inside the rim while
  /// the spring overshoots at the first and last slots.
  final double trackWidth;

  /// Laid-out label widths, one per destination — what the pill is sized from.
  final List<double> labelWidths;

  @override
  State<_SelectionPill> createState() => _SelectionPillState();
}

class _SelectionPillState extends State<_SelectionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GlassDurations.base,
    // Starts settled: the first frame must show the pill parked under the
    // current tab, not flying in from slot zero.
    value: 1,
  );

  late double _from = widget.index.toDouble();
  late double _to = widget.index.toDouble();

  /// The resolved curve from the last build, so a selection change can locate the
  /// pill's on-screen position without reaching into an inherited widget outside
  /// of build.
  Curve _curve = GlassCurves.spring;

  @override
  void didUpdateWidget(covariant _SelectionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;

    // Re-aiming from the *current* position rather than from the previous index
    // is what keeps rapid tab-hopping continuous: interrupting mid-travel would
    // otherwise snap the pill back to the slot it had already left.
    _from = _positionAt(_controller.value);
    _to = widget.index.toDouble();
    _controller.forward(from: 0);
  }

  double _positionAt(double value) =>
      _from + (_to - _from) * _curve.transform(value.clamp(0.0, 1.0));

  /// How wide the pill wants to be behind destination [index].
  ///
  /// Sized from the label rather than from the slot, which is the fix for a pill
  /// that looked cramped behind the longer words. Five slots across a phone leave
  /// each one ~72pt, and "Courses" is ~45pt of that — a slot-width pill therefore
  /// left barely 7pt of air on either side, so the lozenge appeared to grip the
  /// text. Sizing to the word instead keeps that air constant at
  /// [GlassMetrics.navBarPillPadding] whatever the label, and lets the pill borrow
  /// the empty space between neighbouring tabs, which is exactly where the room
  /// was sitting unused.
  ///
  /// Capped so the pill stays centred on its own tab: at the first and last slots
  /// there is only half a slot of room before the rim, and growing into the rim
  /// instead would shift the lozenge off its icon.
  double _widthFor(int index) {
    final desired = math.max(
      _labelWidth(index) + GlassMetrics.navBarPillPadding * 2,
      GlassMetrics.navBarPillMinWidth,
    );

    final centre = (index + 0.5) * widget.itemWidth;

    // Room before the rim. Halved on both sides so the pill gives up width rather
    // than sliding off its own icon at the first and last slots.
    final room = 2.0 *
        math.min(
          centre - GlassMetrics.navBarPillInset,
          widget.trackWidth - GlassMetrics.navBarPillInset - centre,
        );

    // Room before the neighbouring *labels*, which is a different limit and only
    // bites under large Dynamic Type: at 160% the words grow past their slots, and
    // a pill sized to one of them would reach under the text on either side. The
    // pill loses that argument — a lozenge that is slightly tight around its label
    // still reads correctly, one sitting behind someone else's label does not.
    var neighbour = double.infinity;
    for (final other in [index - 1, index + 1]) {
      if (other < 0 || other >= widget.labelWidths.length) continue;
      final gap = (other - index).abs() * widget.itemWidth;
      neighbour = math.min(
        neighbour,
        2.0 * (gap - _labelWidth(other) / 2 - GlassMetrics.navBarPillInset),
      );
    }

    var width = math.min(desired, math.min(room, neighbour));

    // The first and last slots have a rim to sit against, and that gap is the one
    // the eye can compare directly with the band above and below the pill. A short
    // label such as "Home" asks for less width than the rim allows, which leaves
    // the pill a few points shy of it — and a 5pt crescent beside a 4pt band reads
    // as a mistake rather than as a margin.
    //
    // So a pill that lands within a padding's reach of the rim closes the rest.
    // The bound matters: on a layout wide enough that the label is nowhere near
    // the rim, the pill stays snug around its word instead of stretching into a
    // lozenge the width of its slot.
    final isEnd = index == 0 || index == widget.labelWidths.length - 1;
    if (isEnd && room - width <= GlassMetrics.navBarPillPadding * 2) {
      width = room;
    }

    return math.max(width, 0.0);
  }

  /// The label's drawn width — its natural width, but never more than the slot,
  /// since each destination lays out inside an `Expanded` and ellipsises there.
  /// Sizing the pill to an intrinsic width the label never actually gets would
  /// leave a lozenge with empty ends.
  double _labelWidth(int index) => index < widget.labelWidths.length
      ? math.min(widget.labelWidths[index], widget.itemWidth)
      : 0.0;

  /// The pill's width at a fractional slot position.
  ///
  /// Interpolating through the slots it passes over, rather than between only the
  /// two endpoints, is what keeps a long jump honest: travelling from "Home" to
  /// "Menu" the lozenge narrows and widens as it crosses each label instead of
  /// gliding at some average width that fits none of them.
  ///
  /// Clamped at both ends so the spring's overshoot holds the destination's width
  /// rather than extrapolating past the last slot into a width no tab has.
  double _lerpWidth(double position) {
    final last = widget.labelWidths.length - 1;
    if (last < 0) return 0;

    final clamped = position.clamp(0.0, last.toDouble());
    final lower = clamped.floor();
    final upper = clamped.ceil();
    if (lower == upper) return _widthFor(lower);

    final low = _widthFor(lower);
    return low + (_widthFor(upper) - low) * (clamped - lower);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    _curve = glass.curve(GlassCurves.spring);

    // Reduce Motion collapses every glass duration to zero, which an
    // AnimationController cannot run — a single frame is the equivalent, and it
    // also zeroes the stretch below since the pill is never mid-flight for long
    // enough to show it.
    final duration = glass.duration(GlassDurations.base);
    _controller.duration =
        duration == Duration.zero ? const Duration(milliseconds: 1) : duration;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = _positionAt(_controller.value);
        final travel = (_to - _from).abs();

        // Peaks at the midpoint of the travel and is gone by the time the pill
        // settles. Capped so a four-slot jump does not smear the pill across the
        // whole capsule.
        final stretch = travel == 0
            ? 0.0
            : math.sin(math.pi * _controller.value) *
                math.min(travel * 14, 24.0);

        const inset = GlassMetrics.navBarPillInset;

        // Width travels with the pill, so moving from a short label to a long one
        // morphs the lozenge rather than resizing it on arrival. `position` is
        // already curved and may overshoot past `_to`, which widens the pill a
        // touch beyond its target and settles back — the same overshoot the
        // movement has, applied to the shape.
        final width = _lerpWidth(position) + stretch;
        final centre = (position + 0.5) * widget.itemWidth;

        // Both the spring's overshoot and the stretch push the pill past the slot
        // it is heading for. In the middle of the bar that is the whole point; at
        // the two ends it would drive the pill under the capsule's rounded rim,
        // where the clip would shear its end flat. Clamping instead lets it squash
        // against the wall, which is what a liquid lozenge would actually do.
        final left = math.max(centre - width / 2, inset);
        final right = math.min(centre + width / 2, widget.trackWidth - inset);

        return Positioned(
          left: left,
          top: inset,
          bottom: inset,
          width: math.max(right - left, 0),
          child: child!,
        );
      },
      child: LiquidGlassContainer(
        key: LiquidGlassNavigationBar.pillKey,
        spec: glass.card.copyWith(
          // Nav-specific, and deliberately translucent: this pill sits on glass
          // with real content blurring past underneath, so the content should tint
          // it. The segmented control's near-opaque `pillTint` sits on a solid card
          // instead and would render this as a lozenge painted *on* the glass
          // rather than made of it.
          tint: glass.navPillTint,
          borderColor: glass.navPillBorder,
          // A tight, low shadow — the embossing under a segmented control's
          // thumb, not the drop shadow of a floating card. It is doing more work
          // now than it was: a 56%-white pill on a 25%-tinted capsule over white
          // content has little tonal separation to lean on, so the shadow is what
          // states "this is a lozenge on top" independently of tint. It firmed up
          // when the capsule thinned, for exactly that reason.
          //
          // Dark glass gets none: a black shadow on a dark capsule is invisible,
          // and there the pill's own brightness already carries the separation.
          shadow: glass.isDark
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x1F000000), // black @ 12%
                    blurRadius: 12,
                    offset: Offset(0, 3),
                    spreadRadius: -2,
                  ),
                ],
        ),
        radius: GlassRadius.capsule,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// One tab: glyph over label, with an iOS press response.
///
/// The press is a scale-down on the *contents*, not on the capsule — pressing a
/// tab must not appear to squash the bar it lives in.
class _NavDestination extends StatefulWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavDestination> createState() => _NavDestinationState();
}

class _NavDestinationState extends State<_NavDestination>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: GlassDurations.fast,
    // Slower on release, so the finger-down is instant and the return is what
    // reads as physical — the same asymmetry `GlassPressable` uses.
    reverseDuration: GlassDurations.base,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    final color = widget.selected
        ? scheme.sidebarPrimary
        : scheme.sidebarForeground;
    final duration = glass.duration(GlassDurations.base);

    // 0.88 rather than the library's usual 0.965: a 24pt glyph has to travel
    // further than a full-width card for the press to be visible at all.
    final pressedScale = glass.pressScale(0.88);
    final pressCurve = glass.curve(GlassCurves.springSoft);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        onTap: widget.onTap,
        // Only the visual is excluded, not the gesture. Putting
        // `excludeSemantics` on the Semantics above would also drop the
        // GestureDetector's tap action, leaving VoiceOver a label it cannot
        // activate — the label is announced above, so just silence the Text.
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) => Transform.scale(
              scale: 1 +
                  (pressedScale - 1) * pressCurve.transform(_press.value),
              child: child,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cross-fading the two glyphs is smoother than swapping them,
                // which reads as a flicker at 60fps.
                AnimatedSwitcher(
                  duration: duration,
                  child: Icon(
                    widget.selected
                        ? widget.item.activeIcon
                        : widget.item.icon,
                    key: ValueKey(widget.selected),
                    size: GlassMetrics.navBarIconSize,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: GlassCurves.easeOutSmooth,
                  style: GlassTypography.navLabel(
                    color,
                    selected: widget.selected,
                  ),
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
