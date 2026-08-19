import 'package:flutter/widgets.dart';

/// Glyphs that Material Icons does not carry.
///
/// These name codepoints in the vendored Font Awesome Free Solid face declared
/// in `pubspec.yaml`. They are plain [IconData], so they drop into `Icon`,
/// `AppBadge`, `AppStatTile` and anything else that takes an icon — no special
/// widget and no extra dependency.
class AppIcons {
  const AppIcons._();

  /// Stacked coins (`fa-coins`).
  ///
  /// The wallet's currency is points, so every Material candidate was wrong:
  /// `monetization_on` and `paid` are stamped with a dollar sign, and `toll`
  /// reads as two rings rather than money.
  static const coins = IconData(0xf51e, fontFamily: 'FontAwesomeSolid');
}
