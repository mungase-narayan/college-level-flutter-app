import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
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
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
}

/// The sheet chrome: grabber, title block, hairline, scrollable body.
class _GlassSheetShell extends StatelessWidget {
  const _GlassSheetShell({
    required this.title,
    required this.subtitle,
    required this.showHandle,
    required this.heightFactor,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final bool showHandle;
  final double heightFactor;
  final Widget child;

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
