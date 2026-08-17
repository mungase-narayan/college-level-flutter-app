import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_list_tile.dart';
import 'liquid_glass_container.dart';

/// A modal bottom sheet in glass — the iOS counterpart to `showAppSheet`.
///
/// The sheet surface earns a real [BackdropFilter]: the screen behind is
/// genuinely visible through it, which is the entire point of a sheet that only
/// partially covers.
///
/// The uncovered area above the sheet is dimmed but *not* blurred, which is what
/// iOS does for a partial sheet — the sheet itself supplies the blur where it
/// overlaps, and blurring the rest would flatten the sense that the screen behind
/// is merely set back rather than dismissed. (A full-screen blurred scrim is the
/// right treatment for an alert, and `showLiquidGlassDialog` does exactly that.)
Future<T?> showLiquidGlassSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  bool isScrollControlled = true,
  bool showHandle = true,
  double heightFactor = 0.9,
  Widget? leading,
  Widget? trailing,
}) {
  final glass = context.glass;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    // Load-bearing. Without it the sheet is pushed onto the *shell's* navigator,
    // which lives inside the shell Scaffold's body — and a Scaffold always paints
    // its `bottomNavigationBar` above its body. The floating nav capsule therefore
    // covered the sheet's lower rows and swallowed their taps, so the last option
    // in a picker could not be selected at all.
    //
    // Safe for every current caller: none of their builders read a provider that
    // lives inside a route, only theme, app-level blocs and `Navigator.pop`.
    useRootNavigator: true,
    // The sheet draws its own glass surface; the route must not paint one behind
    // it or the blur would sample an opaque rectangle.
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: glass.scrim,
    // A long, heavily decelerated glide — an iOS sheet settles under its own
    // weight rather than easing linearly into place.
    sheetAnimationStyle: AnimationStyle(
      duration: glass.duration(GlassDurations.sheet),
      reverseDuration: glass.duration(GlassDurations.base),
      curve: GlassCurves.sheet,
      reverseCurve: GlassCurves.easeOutSmooth,
    ),
    builder: (context) => _GlassSheetShell(
      title: title,
      subtitle: subtitle,
      showHandle: showHandle,
      heightFactor: heightFactor,
      leading: leading,
      trailing: trailing,
      child: Builder(builder: builder),
    ),
  );
}

/// A sheet whose body is a plain list of options — the iOS counterpart to
/// `showAppOptionSheet`, used by the filter and role pickers.
Future<T?> showLiquidGlassOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<LiquidGlassSheetOption<T>> options,
  T? selected,
  String? subtitle,
}) {
  return showLiquidGlassSheet<T>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (context) {
      final scheme = context.scheme;

      return LiquidGlassSection(
        margin: EdgeInsets.zero,
        children: [
          for (final option in options)
            LiquidGlassListTile(
              title: option.label,
              subtitle: option.description,
              leadingIcon: option.icon,
              destructive: option.destructive,
              onTap: () => Navigator.of(context).pop(option.value),
              trailing: option.value == selected
                  ? Icon(Icons.check_rounded, size: 19, color: scheme.primary)
                  : null,
            ),
        ],
      );
    },
  );
}

class LiquidGlassSheetOption<T> {
  const LiquidGlassSheetOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  /// Renders the row in the destructive colour — a delete in an action list.
  final bool destructive;
}

/// A text action in a sheet's toolbar — the `Cancel` / `Done` pair iOS puts on
/// either side of a sheet's title.
///
/// Deliberately not a [LiquidGlassButton]: a glass capsule in the toolbar would
/// compete with the sheet's own surface, which is already glass. iOS renders
/// these as bare tinted text, and the press feedback is a dip in opacity rather
/// than the scale a raised control gets.
class LiquidGlassSheetAction extends StatelessWidget {
  const LiquidGlassSheetAction({
    super.key,
    required this.label,
    this.onPressed,
    this.prominent = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The confirming action of the pair — semibold, as `Done` is on iOS.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onPressed != null;

    return GlassPressable(
      onTap: onPressed,
      // Text cannot scale on press without reflowing the row it sits in.
      pressedScale: 1.0,
      pressedOpacity: 0.4,
      semanticLabel: label,
      child: ConstrainedBox(
        // A 44pt target around type that is only ~22pt tall.
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.xs),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                height: 22 / 17,
                letterSpacing: -0.2,
                fontWeight: prominent ? FontWeight.w600 : FontWeight.w400,
                color: enabled
                    ? scheme.primary
                    : scheme.mutedForeground.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet chrome: grabber, title block, hairline, scrollable body.
class _GlassSheetShell extends StatelessWidget {
  const _GlassSheetShell({
    required this.title,
    required this.subtitle,
    required this.showHandle,
    required this.heightFactor,
    required this.child,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool showHandle;
  final double heightFactor;
  final Widget child;

  /// Toolbar actions. When either is set the title centres between them, the way
  /// a navigation bar lays out; with neither it stays left-aligned, which is how
  /// every existing form sheet reads.
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final media = MediaQuery.of(context);
    final subtitle = this.subtitle;

    return Padding(
      // Lift the sheet above the keyboard so a form's fields stay reachable.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * heightFactor,
        ),
        child: LiquidGlassContainer(
          blur: GlassBlur.thick,
          spec: glass.overlay,
          borderRadius: GlassRadius.sheetTop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(
                      top: GlassSpacing.sm,
                      bottom: GlassSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.mutedForeground.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(GlassRadius.capsule),
                    ),
                  ),
                ),
              if (leading != null || trailing != null)
                _GlassSheetToolbar(
                  title: title,
                  subtitle: subtitle,
                  leading: leading,
                  trailing: trailing,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GlassSpacing.xl,
                    GlassSpacing.sm,
                    GlassSpacing.xl,
                    GlassSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: glass.overlay.borderColor,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    GlassSpacing.xl,
                    GlassSpacing.lg,
                    GlassSpacing.xl,
                    GlassSpacing.xxl,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sheet header laid out as a navigation bar: an action at each edge with the
/// title centred between them.
///
/// The title is positioned in a [Stack] rather than as the middle cell of a
/// [Row], because a row centres the title within *whatever is left over* — so a
/// one-word action on the left and a two-word one on the right push the title
/// visibly off-centre. Stacking centres it against the bar itself, exactly as
/// `UINavigationBar` does, and the reserved side inset is what keeps a long
/// title from sliding under the actions.
class _GlassSheetToolbar extends StatelessWidget {
  const _GlassSheetToolbar({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Space held clear at each end for the actions. Two short words at 17pt.
  static const _actionInset = 88.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GlassSpacing.md, 0, GlassSpacing.md, 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _actionInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
            if (leading != null)
              Align(alignment: Alignment.centerLeft, child: leading),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}
