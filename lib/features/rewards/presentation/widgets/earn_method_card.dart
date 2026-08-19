import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/rewards.dart';

/// One way to earn points, and what it pays.
///
/// The "Earn Points" tab is static on the web too — these amounts mirror the
/// backend's `POINTS` constants rather than coming from an endpoint.
class EarnMethodCard extends StatelessWidget {
  const EarnMethodCard({super.key, required this.method});

  final EarnMethod method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(method.shade);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(method.icon, size: 20, color: tone.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(method.description, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppBadge(
            '+${method.points}',
            shade: TwColors.amber,
            // Stacked coins. Material Icons has no coin that isn't stamped
            // with a currency symbol, and these are points, not money.
            icon: AppIcons.coins,
          ),
        ],
      ),
    );
  }
}
