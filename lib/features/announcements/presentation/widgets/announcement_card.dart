import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/announcement.dart';
import 'announcement_cover.dart';

/// One announcement in the feed — the port of `announcement-card.tsx`.
///
/// Renders nothing about registration: the web's card doesn't either, which is
/// why registering from the detail screen leaves this list alone.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final description = announcement.description ?? '';
    final date = announcement.startDate;
    // The web keys this chip off the id, not the resolved room — the list
    // payload has no room to name.
    final hasVenue = announcement.isEvent && announcement.roomId != null;
    final hasMeta = date != null || hasVenue;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnnouncementCover(
            url: announcement.coverImageUrl,
            overlay: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverBadge(
                    label: AnnouncementMeta.typeLabel(announcement.type),
                    shade: AnnouncementMeta.typeShade(announcement.type),
                  ),
                  const Spacer(),
                  // Only HIGH earns a pill here; the detail screen spells out
                  // every priority.
                  if (announcement.priority == 'HIGH')
                    _CoverBadge(
                      label: 'High',
                      shade: AnnouncementMeta.priorityShade('HIGH'),
                      // The web fills this one at 90% with white text rather
                      // than tinting it — it is meant to shout.
                      filled: true,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasMeta) ...[
                  Row(
                    children: [
                      if (date != null) ...[
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: theme.textTheme.labelSmall?.color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          Fmt.longDate(date),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                      if (date != null && hasVenue) const SizedBox(width: 12),
                      if (hasVenue) ...[
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: theme.textTheme.labelSmall?.color,
                        ),
                        const SizedBox(width: 5),
                        // The word, not the room: the feed payload has no room.
                        Text('Venue', style: theme.textTheme.labelSmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  announcement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'View details',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A badge that has to stay readable on top of an arbitrary photograph.
///
/// `AppBadge` tints its background at 10–15% alpha, which is right on a solid
/// card and unreadable over an image — the photo simply shows through the label.
/// This composites the same tint over the card colour, so it looks identical to
/// every other badge in the app while being fully opaque, and adds a small
/// shadow so it lifts off a busy cover.
class _CoverBadge extends StatelessWidget {
  const _CoverBadge({
    required this.label,
    required this.shade,
    this.filled = false,
  });

  final String label;
  final TwShade shade;

  /// Fills with the shade itself and prints white, for a badge that must carry
  /// over any background rather than blend with it.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tone = context.tokens.tone(shade);

    final background = filled
        ? shade.s500
        // The exact colour this badge has when it sits on a card — just opaque,
        // so nothing behind it bleeds through.
        : Color.alphaBlend(tone.background, scheme.card);
    final foreground = filled ? Colors.white : tone.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
