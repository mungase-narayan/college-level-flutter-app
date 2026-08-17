import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../design/platform/app_platform.dart';

/// The launcher artwork, drawn as the rounded tile the OS shows on the home
/// screen.
///
/// The asset is full-bleed — the purple field is part of the image — so this
/// only supplies the corner rounding, never a background colour. Callers that
/// need it to line up with a nearby chip pass that chip's [radius].
///
/// Warmed into the image cache during startup (see `_precacheAppLogo` in
/// `main.dart`), so the boot splash can paint it on its very first frame.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 38, this.radius});

  /// The flat mark, used on every platform whose launcher icon it still
  /// matches.
  static const materialAsset = 'assets/images/app_logo.png';

  /// The dimensional mark cut from the iOS app icon set, so the boot splash
  /// shows the same tile the user just tapped on the home screen.
  static const iosAsset = 'assets/images/app_logo_ios.png';

  /// The artwork matching the launcher icon this build actually installs.
  static String get asset =>
      AppPlatform.isIOS ? iosAsset : materialAsset;

  final double size;

  /// Corner radius. Defaults to [AppTheme.radiusMd], which matches the chips
  /// this tile usually sits beside.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusMd),
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
    );
  }
}
