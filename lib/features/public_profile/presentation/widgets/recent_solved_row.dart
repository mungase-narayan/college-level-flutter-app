import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/math_text.dart';
import '../../domain/entities/public_profile.dart';

/// One recently solved question.
///
/// The title runs full width and the difficulty and date sit beneath it. An
/// earlier version floated the chip at the top right, which left a ragged gap
/// under it whenever the title wrapped — which, for question text, is almost
/// always.
class RecentSolvedRow extends StatelessWidget {
  const RecentSolvedRow({super.key, required this.item, this.isLast = false});

  final RecentSolved item;
  final bool isLast;

  /// The web's `DIFFICULTY_COLOR` — emerald, amber, rose, muted fallback.
  static TwShade? _shade(String difficulty) => switch (difficulty.toLowerCase()) {
        'easy' => TwColors.emerald,
        'medium' => TwColors.amber,
        'hard' => TwColors.rose,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = _shade(item.difficulty) == null
        ? null
        : context.tokens.tone(_shade(item.difficulty)!);
    final solvedAt = item.solvedAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: scheme.border.withValues(alpha: 0.5)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: context.tokens.tone(TwColors.emerald).foreground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Question text carries caret exponents (`x^2`), which read
                  // as a typo until they are raised.
                  MathText.pretty(item.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tone?.background ?? scheme.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.difficulty,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tone?.foreground ?? scheme.mutedForeground,
                        ),
                      ),
                    ),
                    if (solvedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        // `Fmt.longDate` takes an ISO string; this row already
                        // holds a parsed DateTime, so it builds the same
                        // "18 Aug 2026" shape without re-serialising.
                        '${solvedAt.day} ${Fmt.monthShort(solvedAt)} '
                        '${solvedAt.year}',
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ],
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
