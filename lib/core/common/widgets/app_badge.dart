import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_chip.dart';

/// The status pill used throughout the React app. The Tailwind idiom it ports
/// is `bg-<c>-500/15 text-<c>-700 dark:bg-<c>-400/15 dark:text-<c>-300`
/// (`src/constants/course-type.constants.ts`).
class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.shade, this.icon, this.dense = false});

  /// Colours the badge from a status string using [statusShade].
  AppBadge.status(String status, {Key? key, IconData? icon, bool dense = false})
      : this(
          _humanize(status),
          key: key,
          shade: statusShade(status),
          icon: icon,
          dense: dense,
        );

  final String label;
  final TwShade? shade;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassChip(
        label: label,
        icon: icon,
        dense: dense,
        tone: shade ?? TwColors.slate,
      );
    }

    final tokens = context.tokens;
    final tone = tokens.tone(shade ?? TwColors.slate);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.foreground,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// `in_progress` → `In progress`.
  static String _humanize(String raw) {
    if (raw.isEmpty) return raw;
    final spaced = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }

  /// The semantic palette the React app applies by hand across every status
  /// enum in the schema (assessment, enrollment, attendance, question, order,
  /// contest, announcement, admission…).
  static TwShade statusShade(String status) => switch (status.toLowerCase()) {
        // Positive / complete / correct
        'active' ||
        'approved' ||
        'present' ||
        'correct' ||
        'accepted' ||
        'completed' ||
        'evaluated' ||
        'published' ||
        'finalized' ||
        'solved' ||
        'fulfilled' ||
        'verified' ||
        'registered' ||
        'attended' =>
          TwColors.emerald,

        // In-flight / needs attention
        'pending' ||
        'pending_review' ||
        'draft' ||
        'in_progress' ||
        'started' ||
        'submitted' ||
        'late' ||
        'medium' ||
        'upcoming' ||
        'review_required' ||
        'suspended' ||
        'unused' =>
          TwColors.amber,

        // Negative / terminal
        'archived' ||
        'rejected' ||
        'cancelled' ||
        'blocked' ||
        'disqualified' ||
        'absent' ||
        'incorrect' ||
        'wrong_answer' ||
        'compile_error' ||
        'runtime_error' ||
        'time_limit_exceeded' ||
        'error' ||
        'failed' ||
        'hard' =>
          TwColors.red,

        // Neutral
        'inactive' || 'dropped' || 'not_attempted' || 'none' || 'leave' => TwColors.slate,

        // Difficulty / miscellaneous
        'easy' => TwColors.teal,
        'running' || 'live' => TwColors.violet,
        _ => TwColors.slate,
      };
}
