import 'package:flutter/widgets.dart';

import '../platform/app_platform.dart';
import '../theme/glass_specs.dart';

/// Extra padding a scroll view needs so its content clears the floating chrome.
///
/// The glass shell sets `extendBody` and `extendBodyBehindAppBar`, which is what
/// lets content slide *under* the translucent bars — the effect the whole design
/// depends on. The trade-off is that the first and last items would otherwise be
/// permanently hidden beneath them, so scroll views add this on top of their own
/// padding:
///
/// ```dart
/// padding: const EdgeInsets.fromLTRB(16, 12, 16, 28).add(context.glassContentInsets)
/// ```
///
/// A [SafeArea] would be the obvious alternative but is wrong here: it *clips*
/// the viewport instead of padding it, so content would stop at the bar's edge
/// rather than scrolling beneath it.
///
/// Off iOS this is always [EdgeInsets.zero], so the `.add()` above is a no-op and
/// Android's layout is bit-for-bit unchanged.
class GlassInsetsScope extends InheritedWidget {
  const GlassInsetsScope({
    super.key,
    required this.contentInsets,
    required super.child,
  });

  /// Padding to add to scroll views in this subtree.
  final EdgeInsets contentInsets;

  static EdgeInsets of(BuildContext context) {
    if (!AppPlatform.useGlass) return EdgeInsets.zero;

    final scope =
        context.dependOnInheritedWidgetOfExactType<GlassInsetsScope>();
    if (scope != null) return scope.contentInsets;

    // No shell above us — a drill-down screen with its own Scaffold. Reserve
    // only the bottom safe area, since there is no floating capsule here.
    return EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
  }

  @override
  bool updateShouldNotify(GlassInsetsScope oldWidget) =>
      contentInsets != oldWidget.contentInsets;
}

/// Computes the insets the glass shell should publish.
///
/// There is deliberately no top inset. The shell's header is a sliver inside a
/// [NestedScrollView], so it occupies real scroll space and the body rises to
/// fill whatever it vacates — padding the body clear of it as well would
/// double-count and leave a permanent gap. Only the nav capsule needs reserving,
/// because it genuinely floats above the content rather than scrolling with it.
abstract final class GlassInsetsMath {
  /// Space to reserve at the bottom so a scroll view's last item clears the
  /// floating nav capsule.
  ///
  /// No `viewPaddingBottom` term: [GlassMetrics.navBarBottomInset] is measured
  /// from the physical screen edge and already accounts for the home indicator, so
  /// adding the safe area again would double-count it — which is exactly what left
  /// an empty band under the capsule.
  static double bottomInset() => GlassMetrics.navBarReservedHeight;

  /// Where the floating nav capsule's top edge sits, measured up from the bottom
  /// of the screen. Used by the toast so it floats above the capsule rather than
  /// behind it.
  static double navBarTopFromBottom() => GlassMetrics.navBarTopFromBottom;
}
