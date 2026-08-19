import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../domain/entities/contest_rating.dart';
import 'delta_pill.dart';

/// Rating, peak, contests played and school rank.
///
/// Hand-built rather than `AppStatGrid`: the Rating tile tints its value with
/// the student's tier colour and carries a [DeltaPill] in its footer, neither of
/// which `AppStatTile` can express — it takes a `TwShade` and a plain caption.
class RatingStatTiles extends StatelessWidget {
  const RatingStatTiles({
    super.key,
    required this.rating,
    this.myRank,
    this.ratedTotal,
  });

  final ContestRating rating;

  /// Null until the student has been in a rated contest.
  final int? myRank;
  final int? ratedTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = rating.history.isEmpty ? null : rating.history.last.ratingDelta;
    final best = rating.bestGain;
    final toPeak = rating.peakRating - rating.rating;

    return Column(
      children: [
        Row(
          // Not `stretch`: a Row's cross axis is vertical, and inside a scroll
          // view that resolves to an infinite height. Every tile is the same
          // fixed structure — label, value, an 18px footer slot — so they line
          // up without being stretched.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Tile(
                label: 'RATING',
                value: '${rating.rating}',
                valueColor: rating.color,
                footer: Row(
                  children: [
                    Flexible(
                      child: Text(
                        rating.tier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: rating.color,
                        ),
                      ),
                    ),
                    if (last != null) ...[
                      const SizedBox(width: 6),
                      DeltaPill(delta: last, dense: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'PEAK',
                value: '${rating.peakRating}',
                footerText: toPeak <= 0 ? 'At your best' : '$toPeak to go',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          // Not `stretch`: a Row's cross axis is vertical, and inside a scroll
          // view that resolves to an infinite height. Every tile is the same
          // fixed structure — label, value, an 18px footer slot — so they line
          // up without being stretched.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Tile(
                label: 'CONTESTS',
                value: '${rating.contestsPlayed}',
                footerText: best == null ? null : 'Best gain +$best',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'SCHOOL RANK',
                // An unranked student is not "#0".
                value: myRank == null ? '—' : '#$myRank',
                footerText: ratedTotal == null ? null : 'of $ratedTotal rated',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    this.valueColor,
    this.footer,
    this.footerText,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? footer;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 18,
            child: footer ??
                (footerText == null
                    ? null
                    : Text(
                        footerText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      )),
          ),
        ],
      ),
    );
  }
}
