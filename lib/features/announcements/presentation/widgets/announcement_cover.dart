import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_theme.dart';

/// The image at the top of a card or a detail page.
///
/// One widget covers three cases that must look identical: no cover set, a cover
/// still downloading, and a cover whose URL is broken or expired. `AppAvatar`
/// takes the same approach — a fallback the user cannot tell apart from an
/// absent image is better than a broken-image glyph.
///
/// It also owns the dark scrim along the top, which is what keeps the type and
/// priority badges legible over an arbitrary photograph.
class AnnouncementCover extends StatelessWidget {
  const AnnouncementCover({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.iconSize = 40,
    this.overlay,
  });

  final String? url;
  final double aspectRatio;
  final double iconSize;

  /// Badges drawn over the image, positioned by the caller.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final url = this.url;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.primary.withValues(alpha: 0.10),
            scheme.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: iconSize,
          color: scheme.primary.withValues(alpha: 0.4),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null || url.isEmpty)
            fallback
          else
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
          if (overlay case final overlay?) ...[
            // Only under the badges, so a photograph is not dimmed overall.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 64,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: overlay),
          ],
        ],
      ),
    );
  }
}
