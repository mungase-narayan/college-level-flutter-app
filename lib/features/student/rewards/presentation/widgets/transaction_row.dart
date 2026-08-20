import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/rewards.dart';

/// One ledger row: what happened, why, and how many points moved.
class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.transaction});

  final PointTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isCredit = transaction.isCredit;
    final tone = isCredit ? tokens.success : tokens.tone(TwColors.rose);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${transaction.reason} · ${Fmt.dmy(transaction.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            // A debit's amount already carries its minus — only credits need a
            // sign added, or a spend would render as "--70".
            isCredit ? '+${transaction.amount}' : '${transaction.amount}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
