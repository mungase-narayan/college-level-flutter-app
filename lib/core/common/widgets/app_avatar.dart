import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Avatar with an initials fallback, used for users, comment authors, and
/// leaderboard rows.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.imageUrl, this.name, this.size = 40});

  final String? imageUrl;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: scheme.sidebarAccent,
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          color: scheme.sidebarAccentForeground,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Port of the React `SchoolLogo` — renders the school's logo, preferring the
/// dark variant when the app is in dark mode, and falling back to the school's
/// initials when neither asset is configured.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({
    super.key,
    this.logo,
    this.logoDark,
    this.name,
    this.height = 30,
  });

  final String? logo;
  final String? logoDark;
  final String? name;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final src = tokens.isDark ? (logoDark ?? logo) : logo;

    if (src == null || src.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: height,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.scheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.school_rounded,
              size: height * 0.6,
              color: tokens.scheme.primaryForeground,
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name!,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    return CachedNetworkImage(
      imageUrl: src,
      height: height,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) =>
          SchoolLogo(name: name, height: height),
    );
  }
}
