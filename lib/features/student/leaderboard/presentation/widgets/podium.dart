import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart' show AppTokensX;
import '../../domain/entities/leaderboard.dart';

/// The top three, arranged 2‑1‑3 with the winner raised.
///
/// The web hides this below its `sm` breakpoint and folds the top three into the
/// table instead. On a phone-only client that would mean never showing a podium
/// at all, so it is kept here and sized for a narrow screen.
class Podium extends StatelessWidget {
  const Podium({super.key, required this.rows, this.onTap});

  /// Up to three rows, in rank order. Fewer is fine — an early-term leaderboard
  /// can have one or two students on it.
  final List<LeaderboardRow> rows;

  /// Opens a student's public showcase. The top three are the most likely names
  /// to be tapped, so they get the same affordance as the rows below.
  final ValueChanged<LeaderboardRow>? onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Second place on the left, winner centre, third on the right — the shape
    // an actual podium has. With fewer than three the present places keep their
    // positions rather than re-centring.
    final ordered = <_Place>[
      if (rows.length > 1) _Place(rows[1], 2),
      _Place(rows[0], 1),
      if (rows.length > 2) _Place(rows[2], 3),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: StaggeredEntrance(
                index: i,
                child: _PodiumCard(place: ordered[i], onTap: onTap),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Place {
  const _Place(this.row, this.place);

  final LeaderboardRow row;
  final int place;
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.place, this.onTap});

  final _Place place;
  final ValueChanged<LeaderboardRow>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final row = place.row;
    final isFirst = place.place == 1;
    final tone = context.tokens.tone(rankShade(place.place));
    final avatarSize = isFirst ? 56.0 : 46.0;

    final tap = onTap;
    return AppCard(
      onTap: tap == null || row.username == null ? null : () => tap(row),
      // The winner's card is taller and tinted; the others stay neutral so the
      // difference reads at a glance.
      padding: EdgeInsets.fromLTRB(8, isFirst ? 14 : 20, 8, 12),
      color: isFirst ? tone.background : null,
      borderColor: isFirst ? tone.foreground.withValues(alpha: 0.35) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 20,
                color: tone.foreground,
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.foreground, width: 2),
                ),
                child: AppAvatar(
                  imageUrl: row.avatar,
                  name: row.fullName,
                  size: avatarSize,
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.foreground,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.card, width: 2),
                  ),
                  child: Text(
                    '${place.place}',
                    style: TextStyle(
                      color: scheme.card,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            row.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (row.isMe)
            Text(
              '(You)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: context.tokens.warning.foreground,
                ),
                const SizedBox(width: 3),
                Text(
                  '${row.points}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            row.accuracy == null
                ? '${row.solved} solved'
                : '${row.solved} solved · ${row.accuracy}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Rank pill for a list row — medal-tinted for the top three, muted below.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isMedal = rank <= 3;
    final tone = context.tokens.tone(rankShade(rank));

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isMedal ? tone.background : scheme.muted,
        shape: BoxShape.circle,
        border: Border.all(
          color: isMedal
              ? tone.foreground.withValues(alpha: 0.40)
              : scheme.border,
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: isMedal ? tone.foreground : scheme.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
