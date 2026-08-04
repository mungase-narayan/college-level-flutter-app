import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'liquid_glass_container.dart';

/// One row in a [LiquidGlassPopupMenu].
class GlassMenuEntry<T> {
  const GlassMenuEntry({
    required this.label,
    this.value,
    this.icon,
    this.description,
    this.destructive = false,
    this.enabled = true,
  });

  /// A non-selectable header — used for the account name/email block at the top
  /// of the profile menu.
  const GlassMenuEntry.header({required this.label, this.description})
      : value = null,
        icon = null,
        destructive = false,
        enabled = false;

  final String label;
  final T? value;
  final IconData? icon;
  final String? description;
  final bool destructive;
  final bool enabled;

  bool get isHeader => value == null && !enabled;
}

/// An iOS context menu in glass — the counterpart to Material's
/// [PopupMenuButton], used for the app bar's profile dropdown.
///
/// Presented through [showMenu]'s route machinery for correct focus trapping and
/// barrier dismissal, but with the Material surface stripped away so the glass
/// panel is the only thing drawn. iOS menus grow from the anchor rather than
/// fading in place, so the transition scales from the corner nearest the anchor.
class LiquidGlassPopupMenu<T> extends StatelessWidget {
  const LiquidGlassPopupMenu({
    super.key,
    required this.entries,
    required this.child,
    this.onSelected,
    this.offset = const Offset(0, 8),
    this.tooltip,
    this.menuWidth = 240,
  });

  final List<GlassMenuEntry<T>> entries;
  final Widget child;
  final ValueChanged<T>? onSelected;
  final Offset offset;
  final String? tooltip;
  final double menuWidth;

  Future<void> _open(BuildContext context) async {
    final anchor = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null) return;

    GlassHaptics.light();

    final anchorTopLeft = anchor.localToGlobal(
      offset,
      ancestor: overlay,
    );
    final anchorBottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero) + offset,
      ancestor: overlay,
    );

    final selected = await Navigator.of(context).push<T>(
      _GlassMenuRoute<T>(
        entries: entries,
        menuWidth: menuWidth,
        position: RelativeRect.fromLTRB(
          anchorTopLeft.dx,
          anchorBottomRight.dy,
          overlay.size.width - anchorBottomRight.dx,
          overlay.size.height - anchorBottomRight.dy,
        ),
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );

    if (selected != null) onSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final button = GlassPressable(
      onTap: () => _open(context),
      pressedScale: 0.92,
      // Haptics fire in `_open` so they land with the menu, not with the tap.
      enableHaptics: false,
      semanticLabel: tooltip,
      child: child,
    );

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

/// The menu's route: a transparent barrier plus a glass panel positioned under
/// the anchor.
class _GlassMenuRoute<T> extends PopupRoute<T> {
  _GlassMenuRoute({
    required this.entries,
    required this.position,
    required this.menuWidth,
    required this.barrierLabel,
  });

  final List<GlassMenuEntry<T>> entries;
  final RelativeRect position;
  final double menuWidth;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => GlassDurations.base;

  @override
  Duration get reverseTransitionDuration => GlassDurations.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Builder(
      builder: (context) => CustomSingleChildLayout(
        delegate: _GlassMenuLayout(position: position, menuWidth: menuWidth),
        child: _GlassMenuPanel<T>(entries: entries, menuWidth: menuWidth),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final glass = context.glass;
    if (glass.reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }

    final t = GlassCurves.easeOutExpo.transform(animation.value.clamp(0.0, 1.0));

    return FadeTransition(
      opacity: animation,
      child: Transform.scale(
        // Grows from the top-trailing corner, where the anchor sits — the menu
        // appears to unfold out of the button rather than materialise over it.
        alignment: Alignment.topRight,
        scale: 0.86 + 0.14 * t,
        child: child,
      ),
    );
  }
}

/// Places the panel under the anchor, flipping to the other side when it would
/// otherwise run off the screen.
class _GlassMenuLayout extends SingleChildLayoutDelegate {
  const _GlassMenuLayout({required this.position, required this.menuWidth});

  final RelativeRect position;
  final double menuWidth;

  static const _screenPadding = 10.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(
        const EdgeInsets.all(_screenPadding),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Prefer trailing-aligned under the anchor, as iOS does for an avatar menu.
    var x = size.width - position.right - childSize.width;
    var y = position.top;

    if (x < _screenPadding) x = _screenPadding;
    if (x + childSize.width > size.width - _screenPadding) {
      x = size.width - _screenPadding - childSize.width;
    }
    // Not enough room below — flip above the anchor rather than overflow.
    if (y + childSize.height > size.height - _screenPadding) {
      y = size.height - _screenPadding - childSize.height;
    }
    if (y < _screenPadding) y = _screenPadding;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_GlassMenuLayout oldDelegate) =>
      position != oldDelegate.position || menuWidth != oldDelegate.menuWidth;
}

class _GlassMenuPanel<T> extends StatelessWidget {
  const _GlassMenuPanel({required this.entries, required this.menuWidth});

  final List<GlassMenuEntry<T>> entries;
  final double menuWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    return SizedBox(
      width: menuWidth,
      child: LiquidGlassContainer(
        blur: GlassBlur.thick,
        spec: glass.overlay,
        radius: GlassRadius.md,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, entry) in entries.indexed) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: glass.overlay.borderColor,
                ),
              if (entry.isHeader)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GlassSpacing.lg,
                    vertical: GlassSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label, style: theme.textTheme.titleSmall),
                      if (entry.description != null)
                        Text(
                          entry.description!,
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                )
              else
                _MenuRow<T>(
                  entry: entry,
                  onTap: entry.enabled && entry.value != null
                      ? () => Navigator.of(context).pop(entry.value)
                      : null,
                  foreground: entry.destructive
                      ? scheme.destructive
                      : scheme.foreground,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.entry,
    required this.onTap,
    required this.foreground,
  });

  final GlassMenuEntry<T> entry;
  final VoidCallback? onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GlassSpacing.lg,
        vertical: 13,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
          if (entry.icon != null) ...[
            const SizedBox(width: GlassSpacing.md),
            Icon(entry.icon, size: 18, color: foreground),
          ],
        ],
      ),
    );

    if (onTap == null) return Opacity(opacity: 0.45, child: row);

    // Menu rows are joined into one panel, so they dim on press rather than
    // scaling away from their neighbours.
    return GlassPressable(
      onTap: onTap,
      pressedScale: 1.0,
      pressedOpacity: 0.5,
      semanticLabel: entry.label,
      child: row,
    );
  }
}
