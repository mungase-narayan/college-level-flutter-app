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
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget> actions;

  /// A [TabBar], typically. Contributes its height to [preferredSize] on both
  /// platforms, matching [AppBar.bottom].
  final PreferredSizeWidget? bottom;

  final bool automaticallyImplyLeading;

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
        actions: actions,
        bottom: bottom,
        // Drill-downs are pushed, so they always need a way back — and iOS wants
        // a chevron rather than Material's arrow.
        showBackButton:
            automaticallyImplyLeading && Navigator.of(context).canPop(),
      );
    }

    return AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
