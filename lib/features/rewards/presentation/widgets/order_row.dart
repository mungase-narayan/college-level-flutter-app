import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/rewards.dart';

/// One purchase.
///
/// Two different badges can appear. The effect badge tracks a ticket's
/// lifecycle; the fulfillment badge tracks whether the school has handed over a
/// physical reward. They are mutually exclusive in practice — a ticket takes
/// effect in the app and is never "fulfilled" — so only one is shown per row.
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order, required this.onTrack});

  final RewardOrder order;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final effect = RewardsMeta.effectLabel(order.effectStatus);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              order.isTicket
                  ? Icons.hourglass_bottom_rounded
                  : Icons.redeem_rounded,
              size: 20,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The price sits beside the title rather than in a trailing
                // column of its own: on a narrow card that column starved the
                // Track-order row below into overflowing.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.productTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      AppIcons.coins,
                      size: 13,
                      color: tokens.warning.foreground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${order.pointsSpent}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tokens.warning.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (effect != null)
                      AppBadge(
                        effect,
                        shade: RewardsMeta.effectShade(order.effectStatus),
                        dense: true,
                      ),
                    // Only physical goods are fulfilled by hand, so a ticket
                    // never shows a processing state it can't leave.
                    if (!order.isTicket)
                      AppBadge(
                        order.isFulfilled ? 'Completed' : 'Processing',
                        shade: order.isFulfilled
                            ? TwColors.emerald
                            : TwColors.amber,
                        dense: true,
                      ),
                    Text(
                      Fmt.dmy(order.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                if (order.canChat) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: AppButton(
                          label: 'Track order',
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.outline,
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: onTrack,
                        ),
                      ),
                      if (order.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadPill(count: order.unreadCount),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tone = context.tokens.tone(TwColors.rose);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.foreground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: context.scheme.card,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
