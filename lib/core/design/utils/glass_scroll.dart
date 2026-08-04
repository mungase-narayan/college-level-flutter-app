import 'package:flutter/widgets.dart';

/// Carries the current scroll offset of the active screen so the floating
/// chrome can react to it — frosting up, deepening its shadow, and collapsing
/// its large title as content slides underneath.
///
/// This exists because the app has no slivers: screens use
/// [SingleChildScrollView] and [ListView.separated], and rewriting all of them
/// as [CustomScrollView] would be a large, risky change for a purely cosmetic
/// gain. A single [NotificationListener] at the shell catches the bubbling
/// [ScrollNotification] from whatever scrollable the current route happens to
/// use, which works uniformly for all of them.
class GlassScrollNotifier extends ValueNotifier<double> {
  GlassScrollNotifier() : super(0);

  /// Sub-pixel changes are ignored so a fling doesn't rebuild the chrome on
  /// every one of its ~120 frames' worth of tiny deltas.
  static const _epsilon = 0.5;

  /// Direction-consistent travel required before the bottom chrome tucks away or
  /// comes back. Without a threshold the capsule would flicker on every jitter.
  static const _directionThreshold = 28.0;

  /// Below this offset the capsule is always shown — near the top of a list there
  /// is nothing to gain from hiding it.
  static const _alwaysVisibleOffset = 40.0;

  /// Whether the floating bottom capsule should be tucked off-screen so the
  /// content reads full-bleed.
  ///
  /// A separate notifier rather than part of [value] so that only the nav bar
  /// rebuilds when it flips; the app bar's frost is driven by [value] alone and
  /// must not be dirtied by it.
  ///
  /// Only the *bottom* chrome is driven this way. The top header cannot be: it is
  /// a sliver whose height is part of the scroll extent, and translating it would
  /// leave a hole. The capsule genuinely floats above the content — content
  /// already scrolls underneath it — so sliding it away reveals content, not a
  /// gap.
  final ValueNotifier<bool> chromeHidden = ValueNotifier<bool>(false);

  double _lastPixels = 0;
  double _directionTravel = 0;

  void update(double pixels) {
    // Overscroll (negative on iOS's bouncing physics) must not push the chrome
    // *below* its resting state, or a pull-to-refresh would un-frost it.
    final next = pixels < 0 ? 0.0 : pixels;

    _updateChromeHidden(next);

    if ((next - value).abs() < _epsilon) return;
    value = next;
  }

  void _updateChromeHidden(double next) {
    final delta = next - _lastPixels;
    _lastPixels = next;

    if (next <= _alwaysVisibleOffset) {
      _directionTravel = 0;
      chromeHidden.value = false;
      return;
    }

    // Reset the tally whenever the direction reverses, so the threshold measures
    // sustained travel one way rather than net drift over a whole session.
    if (delta.isNegative != _directionTravel.isNegative) {
      _directionTravel = 0;
    }
    _directionTravel += delta;

    if (_directionTravel > _directionThreshold) {
      chromeHidden.value = true;
      _directionTravel = 0;
    } else if (_directionTravel < -_directionThreshold) {
      chromeHidden.value = false;
      _directionTravel = 0;
    }
  }

  /// Called when a new route takes over the shell body, so the incoming screen
  /// starts with chrome at rest rather than inheriting the previous scroll.
  void reset() {
    _lastPixels = 0;
    _directionTravel = 0;
    chromeHidden.value = false;
    value = 0;
  }

  @override
  void dispose() {
    chromeHidden.dispose();
    super.dispose();
  }
}

/// Publishes a [GlassScrollNotifier] to the subtree.
///
/// Deliberately a plain [InheritedWidget] rather than an [InheritedNotifier]:
/// dependents rebuild only if the *notifier instance* changes, not when it
/// notifies. Widgets subscribe to the value through [ValueListenableBuilder],
/// which keeps scroll-driven rebuilds confined to the app bar and nav bar
/// instead of dirtying the whole subtree on every frame of a scroll.
class GlassScrollScope extends InheritedWidget {
  const GlassScrollScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final GlassScrollNotifier notifier;

  /// The nearest notifier, or null when used outside a glass shell (a
  /// standalone [LiquidGlassAppBar] on a drill-down screen, or a widget test).
  static GlassScrollNotifier? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassScrollScope>()
      ?.notifier;

  @override
  bool updateShouldNotify(GlassScrollScope oldWidget) =>
      notifier != oldWidget.notifier;
}

/// Feeds the scroll offset of its subtree into [notifier].
///
/// Only depth-0 notifications are consumed. Nested scrollables — the horizontal
/// heatmap strip, a chart's internal scroller, a `TabBarView`'s page scroll —
/// report at depth ≥ 1 and would otherwise fight the vertical offset the chrome
/// cares about.
class GlassScrollObserver extends StatelessWidget {
  const GlassScrollObserver({
    super.key,
    required this.notifier,
    required this.child,
  });

  final GlassScrollNotifier notifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification.metrics.axis != Axis.vertical) return false;
        notifier.update(notification.metrics.pixels);
        // Never absorb the notification — RefreshIndicator, InfiniteScroll and
        // Scrollbar all depend on it continuing to bubble.
        return false;
      },
      child: child,
    );
  }
}

/// Maps a scroll offset onto a 0→1 progress value over [distance].
double glassScrollProgress(double offset, double distance) {
  if (distance <= 0) return offset > 0 ? 1 : 0;
  final t = offset / distance;
  return t < 0 ? 0 : (t > 1 ? 1 : t);
}
