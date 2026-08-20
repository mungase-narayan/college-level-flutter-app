import 'package:flutter/material.dart';

import '../../design/extensions/glass_context.dart';
import '../../design/platform/app_platform.dart';
import '../../design/widgets/liquid_glass_app_bar.dart';

/// The app bar for screens that own their own [Scaffold] — the drill-downs that
/// render above the shell chrome (course detail, assessment detail,
/// set-password, the role placeholder).
///
/// These screens previously used a bare [AppBar], which does not survive the iOS
/// theme: `LiquidGlassTheme` makes `appBarTheme` transparent so the glass bar can
/// own the surface, which would leave a plain `AppBar` painting nothing at all and
/// its title floating over the backdrop with no separation from the content
/// scrolling behind it.
///
/// Off iOS this constructs exactly the [AppBar] those screens had before.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.titleTrailing,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.leading,
  });

  final String title;
  final List<Widget> actions;

  /// Sits immediately after the title, inside the title's own slot rather than
  /// out with the actions — for a status badge that belongs to the thing being
  /// named, not to the controls acting on it.
  final Widget? titleTrailing;

  /// A [TabBar], typically. Contributes its height to [preferredSize] on both
  /// platforms, matching [AppBar.bottom].
  final PreferredSizeWidget? bottom;

  final bool automaticallyImplyLeading;

  /// Replaces the automatic back affordance. Needed by screens that can be
  /// reached without a back stack — a deep link has nothing to pop, so those
  /// supply their own control rather than stranding the reader.
  final Widget? leading;

  /// Reads [AppPlatform.useGlass] directly rather than through `context`:
  /// [Scaffold] queries [preferredSize] before this widget builds, so no
  /// [BuildContext] exists yet. Safe, because the flag depends on the platform
  /// alone and not on anything inherited.
  @override
  Size get preferredSize => Size.fromHeight(
        AppPlatform.useGlass
            ? LiquidGlassAppBar(title: title, bottom: bottom)
                .preferredSize
                .height
            : kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassAppBar(
        title: title,
        titleTrailing: titleTrailing,
        actions: actions,
        bottom: bottom,
        leading: leading,
        // Drill-downs are pushed, so they always need a way back — and iOS wants
        // a chevron rather than Material's arrow.
        showBackButton: leading == null &&
            automaticallyImplyLeading &&
            Navigator.of(context).canPop(),
      );
    }

    return AppBar(
      title: titleTrailing == null
          ? Text(title)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                titleTrailing!,
              ],
            ),
      actions: actions,
      bottom: bottom,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
