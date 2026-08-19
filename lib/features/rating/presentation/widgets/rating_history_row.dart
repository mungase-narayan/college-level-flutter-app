import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/contest_rating.dart';
import 'delta_pill.dart';

/// One rated contest: what it was, what it cost or paid, and where you placed.
class RatingHistoryRow extends StatelessWidget {
  const RatingHistoryRow({super.key, required this.entry, this.onTap});

  final RatingHistoryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.contestTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              DeltaPill(delta: entry.ratingDelta ?? 0),
            ],
          ),
          const SizedBox(height: 3),
          Text(Fmt.dmy(entry.endAt), style: theme.textTheme.labelSmall),
          const SizedBox(height: 10),
          // Rank and resulting rating, side by side — the web's split strip.
          Container(
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Cell(
                    label: 'RANK',
                    value: entry.rank == null
                        ? '—'
                        : '${entry.rank}'
                            '${entry.participants == null ? '' : ' / ${entry.participants}'}',
                  ),
                ),
                Container(width: 1, height: 30, color: scheme.border),
                Expanded(
                  child: _Cell(
                    label: 'RATING',
                    value: '${entry.ratingAfter ?? '—'}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
