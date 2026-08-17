import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/attendance.dart';

/// The headline percentage, with the ≥75 / ≥50 colour rule and a bar.
class AttendancePercentCard extends StatelessWidget {
  const AttendancePercentCard({
    super.key,
    required this.percentage,
    this.label = 'Attendance',
    this.caption,
    this.hasSessions = true,
  });

  final int percentage;
  final String label;

  /// A muted line under the bar, for anything the number alone implies wrongly.
  final String? caption;

  /// When false the card reads `—` rather than `0%`.
  ///
  /// The server sends `percentage: 0` for a course that has not met yet, which
  /// is indistinguishable from a student who attended nothing — and painting it
  /// red says the second when it means the first.
  final bool hasSessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final shade = AttendanceMeta.percentShade(percentage);
    final tone = context.tokens.tone(shade);
    final valueColor = hasSessions ? tone.foreground : scheme.mutedForeground;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelSmall)),
              Text(
                hasSessions ? '$percentage%' : '—',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: valueColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hasSessions ? (percentage / 100).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: scheme.muted,
              valueColor: AlwaysStoppedAnimation(
                hasSessions
                    ? AttendanceMeta.percentColor(percentage)
                    : scheme.muted,
              ),
            ),
          ),
          if (caption case final caption? when caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(caption, style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}
