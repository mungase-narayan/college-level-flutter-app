import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../theme/glass_typography.dart';
import '../utils/glass_scroll.dart';
import 'liquid_glass_container.dart';

/// A floating glass app bar with an iOS large title that collapses on scroll.
///
/// Content passes *underneath* it, which is the whole point — so it is one of the
/// surfaces that earns a real [BackdropFilter], and that blur ramps up as content
/// arrives beneath it (sigma 24 → 38, tint 65% → 80%).
///
/// ### How the scroll reactivity works
///
/// The app has no slivers — screens use [SingleChildScrollView] and
/// [ListView.separated] — so this does not use [SliverAppBar]. Instead the shell
/// installs one [GlassScrollObserver] which feeds offsets into a
/// [GlassScrollNotifier], and this widget subscribes through a
/// [ValueListenableBuilder]. The consequence matters: only this bar and the nav
/// bar rebuild while scrolling, never the content.
///
/// Pass [scrollOffset] explicitly to drive it from a screen's own controller (a
/// drill-down page outside the shell); otherwise it finds the shell's notifier,
/// and failing that stays permanently at rest.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.largeTitle = false,
    this.scrollOffset,
    this.showBackButton = false,
    this.onBack,
    this.bottom,
  });

  final String title;

  /// A second line under the compact title. Suppressed while a large title is
  /// expanded, where it would compete with it.
  final String? subtitle;

  final List<Widget> actions;
  final Widget? leading;

  /// Renders the iOS 34pt large title below the toolbar row, collapsing into the
  /// compact title over the first 52 logical pixels of scroll.
  final bool largeTitle;

  /// Overrides the ambient scroll source.
  final ValueListenable<double>? scrollOffset;

  final bool showBackButton;
  final VoidCallback? onBack;

  /// Rendered below the toolbar row, inside the glass — a [TabBar], typically.
  /// Its height is added to [preferredSize], the way [AppBar.bottom] behaves.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        (largeTitle
                ? GlassMetrics.appBarLargeHeight
                : GlassMetrics.appBarCompactHeight) +
            (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final listenable = scrollOffset ?? GlassScrollScope.maybeOf(context);

    if (listenable == null) {
      // No scroll source: render permanently at rest rather than failing.
      return _AppBarSurface(
        title: title,
        subtitle: subtitle,
        actions: actions,
        leading: leading,
        largeTitle: largeTitle,
        showBackButton: showBackButton,
        onBack: onBack,
        bottom: bottom,
        offset: 0,
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, offset, _) => _AppBarSurface(
        title: title,
        subtitle: subtitle,
        actions: actions,
        leading: leading,
        largeTitle: largeTitle,
        showBackButton: showBackButton,
        onBack: onBack,
        bottom: bottom,
        offset: offset,
      ),
    );
  }
}

class _AppBarSurface extends StatelessWidget {
  const _AppBarSurface({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.leading,
    required this.largeTitle,
    required this.showBackButton,
    required this.onBack,
    required this.bottom,
    required this.offset,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool largeTitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final statusBar = MediaQuery.paddingOf(context).top;
    final subtitle = this.subtitle;

    // How frosted the bar is. Ramps over a deliberately short distance so the
    // material reacts the instant content starts moving under it.
    final frost = glassScrollProgress(offset, GlassMetrics.chromeScrollRamp);

    // How far the large title has collapsed into the compact one.
    final collapse = largeTitle
        ? glassScrollProgress(offset, GlassMetrics.largeTitleCollapseDistance)
        : 1.0;

    // The compact title fades in only over the *second* half of the collapse, so
    // the two titles never both read at full strength.
    final compactTitleOpacity =
        largeTitle ? glassScrollProgress(collapse - 0.5, 0.5) : 1.0;

    return LiquidGlassContainer(
      blur: GlassBlur.chrome,
      sigmaOverride: glass.chromeSigma(frost),
      spec: glass.chromeAt(frost),
      // Square corners and no surrounding hairline: the bar is flush to the
      // screen edges, so rounding it or ringing it would read as a floating
      // panel rather than as chrome.
      borderRadius: BorderRadius.zero,
      showBorder: false,
      showShadow: frost > 0,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: statusBar),
              SizedBox(
                height: GlassMetrics.appBarCompactHeight,
                child: Row(
                  children: [
                    if (showBackButton)
                      _BackButton(onTap: onBack)
                    else if (leading != null)
                      Padding(
                        // Padded on both sides: without the trailing gap the
                        // title butts straight up against the avatar, which reads
                        // as one crowded blob rather than as two elements.
                        padding: const EdgeInsets.only(
                          left: GlassSpacing.lg,
                          right: GlassSpacing.md,
                        ),
                        child: leading!,
                      )
                    else
                      const SizedBox(width: GlassSpacing.xl),
                    Expanded(
                      child: largeTitle
                          // While expanded there is nothing in the toolbar row —
                          // the title lives below it and rises into this slot as
                          // it collapses.
                          ? Opacity(
                              opacity: compactTitleOpacity,
                              child: Center(
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle,
                                    style: theme.textTheme.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                    ),
                    ...actions,
                    const SizedBox(width: GlassSpacing.md),
                  ],
                ),
              ),
              if (largeTitle)
                // Collapsing the height rather than translating the title keeps
                // the content below moving in lockstep, with no gap opening up.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: 1 - collapse,
                    child: SizedBox(
                      height: GlassMetrics.appBarLargeHeight -
                          GlassMetrics.appBarCompactHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: GlassSpacing.xl,
                          right: GlassSpacing.xl,
                          bottom: GlassSpacing.xs,
                        ),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Opacity(
                            // Fades out ahead of the height, so the title is gone
                            // before it would be visually cropped.
                            opacity: 1 - glassScrollProgress(collapse, 0.7),
                            child: Text(
                              title,
                              style:
                                  GlassTypography.largeTitle(scheme.foreground),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Inside the glass rather than below it, so a TabBar frosts with
              // the rest of the bar instead of sitting on an opaque strip.
              ?bottom,
            ],
          ),
          // Positioned rather than appended to the Column: Scaffold budgets the
          // bar exactly `preferredSize.height + statusBar`, so a 0.5px hairline
          // in the layout flow overflows that budget by 0.5px.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              // Appears only once content is genuinely behind the bar — there is
              // nothing to separate at rest.
              opacity: frost,
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: glass.chromeScrolled.borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The iOS back affordance: a chevron, tappable well beyond its own glyph.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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
        child: SizedBox(
          width: 44, // Apple's minimum touch target.
          height: double.infinity,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// An icon button sized and styled for the glass app bar's action row.
class LiquidGlassAppBarAction extends StatelessWidget {
  const LiquidGlassAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 21,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final button = Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: Icon(icon, size: size, color: scheme.foreground)),
        ),
      ),
    );

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}
