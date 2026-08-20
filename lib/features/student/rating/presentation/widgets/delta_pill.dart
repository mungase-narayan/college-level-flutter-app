import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';

/// A signed rating change — `+43` green, `-12` red.
///
/// Zero counts as a gain, matching the web's `delta >= 0`: a contest that left
/// you where you started is not a loss. Negative values already carry their own
/// minus sign, so only `+` is ever prepended.
///
/// The arrow is not decoration — it is what keeps the pill readable without
/// colour, so it stays even though the sign says the same thing.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.delta, this.dense = false});

  final int delta;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGain = delta >= 0;
    final tone =
        context.tokens.tone(isGain ? TwColors.emerald : TwColors.rose);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGain
                ? Icons.arrow_outward_rounded
                : Icons.south_east_rounded,
            size: dense ? 10 : 12,
            color: tone.foreground,
          ),
          const SizedBox(width: 2),
          Text(
            '${isGain ? '+' : ''}$delta',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
