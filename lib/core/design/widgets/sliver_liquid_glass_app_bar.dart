import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// A glass app bar that scrolls away as you read down and returns the moment you
/// scroll back up — the behaviour YouTube's header has.
///
/// ### Why this is a sliver
///
/// A header can only hide correctly if its height is **part of the scroll
/// extent**. The two non-sliver approaches both break:
///
/// * Translating the bar with a `Transform` leaves an empty hole where it was,
///   because the content below it is still padded clear of a bar that is no
///   longer there.
/// * Shrinking that padding instead makes the content travel at *twice* finger
///   speed — the scroll moves it up, and the shrinking padding moves it up again.
///
/// As a sliver the header simply occupies scroll space: the content moves up at
/// exactly 1:1 and fills the space the header vacates, with no hole and no
/// double-speed. `floating: true` brings it back on any upward scroll without
/// having to return to the top, and `snap: true` prevents it from being left
/// stranded half-open. Flutter's own implementation handles the fling,
/// overscroll and snap-animation edge cases.
///
/// The shell mounts this through [NestedScrollView.headerSliverBuilder], which is
/// what lets the chrome stay owned by the shell while each screen supplies an
/// ordinary [ListView] or [SingleChildScrollView] body.
class SliverLiquidGlassAppBar extends StatelessWidget {
  const SliverLiquidGlassAppBar({
    super.key,
    required this.title,
    required this.scrolledUnder,
    this.actions = const [],
    this.leading,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;

  /// Whether content currently sits beneath the bar, from
  /// [NestedScrollView.headerSliverBuilder]'s `innerBoxIsScrolled`.
  ///
  /// Drives the frosting: at rest there is nothing behind the bar to separate
  /// from, so it stays light and shows no hairline.
  final bool scrolledUnder;

  final List<Widget> actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    return SliverAppBar(
      floating: true,
      // `snap` is load-bearing inside a NestedScrollView, not a flourish. An
      // upward drag is consumed by the *inner* list first, so without a snap
      // configuration the header would only re-expand once the list had been
      // scrolled all the way back to the top — exactly the behaviour this
      // feature exists to avoid. A test pins the float-back for this reason.
      snap: true,
      pinned: false,
      toolbarHeight: GlassMetrics.appBarCompactHeight,
      automaticallyImplyLeading: false,
      // The glass surface below is the only thing that paints; Material must not
      // add a second opaque layer over it.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: GlassSpacing.md,
      leading: showBackButton
          ? _SliverBackButton(onTap: onBack)
          : leading == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: GlassSpacing.lg),
                  // `Align` is load-bearing, not cosmetic: AppBar's
                  // `NavigationToolbar` layout forces its leading slot to the
                  // full toolbar height, which overrides the avatar's own
                  // `SizedBox` and stretches it into a clipped oval. Align
                  // absorbs the tight constraint and passes the child a loose
                  // one, so the avatar keeps its intended size.
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: leading,
                  ),
                ),
      // Avatar (32) plus its leading pad; `titleSpacing` below then supplies the
      // gap to the title, so the two never touch.
      leadingWidth: leading == null && !showBackButton
          ? null
          : GlassSpacing.lg + 32,
      title: Text(
        title,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [...actions, const SizedBox(width: GlassSpacing.md)],
      // Painted behind the leading/title/actions row and spanning the status bar
      // too, so the whole bar is one continuous pane of glass.
      flexibleSpace: _GlassBarSurface(
        scrolledUnder: scrolledUnder,
        borderColor: glass.chromeScrolled.borderColor,
        foreground: scheme.foreground,
      ),
    );
  }
}

class _GlassBarSurface extends StatelessWidget {
  const _GlassBarSurface({
    required this.scrolledUnder,
    required this.borderColor,
    required this.foreground,
  });

  final bool scrolledUnder;
  final Color borderColor;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    // Animated rather than stepped: `innerBoxIsScrolled` is a bool, so without
    // this the material would snap between its two states.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: scrolledUnder ? 1.0 : 0.0),
      duration: glass.duration(GlassDurations.base),
      curve: GlassCurves.easeOutSmooth,
      builder: (context, frost, _) => LiquidGlassContainer(
        blur: GlassBlur.chrome,
        sigmaOverride: glass.chromeSigma(frost),
        spec: glass.chromeAt(frost),
        // Flush to the screen edges, so rounding or ringing it would read as a
        // floating panel rather than as chrome.
        borderRadius: BorderRadius.zero,
        showBorder: false,
        showShadow: frost > 0,
        child: Stack(
          children: [
            const SizedBox.expand(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                // Never fully transparent. A blur over the backdrop's smooth
                // gradient is mathematically invisible — blurring a gradient
                // returns the same gradient — so at rest the hairline is the only
                // thing that reads the header as a separate pane of glass rather
                // than as part of the background. It then strengthens once real
                // content is behind it and the blur can actually be seen.
                opacity: 0.45 + 0.55 * frost,
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: borderColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The iOS back affordance, sized to Apple's 44pt minimum touch target.
class _SliverBackButton extends StatelessWidget {
  const _SliverBackButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Navigator.maybePop(context),
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
