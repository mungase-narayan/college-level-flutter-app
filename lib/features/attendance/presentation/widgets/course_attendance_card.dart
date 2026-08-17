import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/attendance.dart';

/// One course in the "Course-wise Attendance" breakdown.
class CourseAttendanceCard extends StatelessWidget {
  const CourseAttendanceCard({super.key, required this.summary});

  final CourseAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final held = summary.hasSessions;
    final percentage = summary.percentage;
    final tone = context.tokens.tone(AttendanceMeta.percentShade(percentage));

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (summary.courseCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.muted,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          summary.courseCode,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: AppTheme.mono,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                // A course that has not met yet comes back as 0%, which would
                // otherwise be painted as a failing grade.
                held ? '$percentage%' : '—',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: held ? tone.foreground : scheme.mutedForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: held ? (percentage / 100).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: scheme.muted,
              valueColor: AlwaysStoppedAnimation(
                held ? AttendanceMeta.percentColor(percentage) : scheme.muted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            held
                ? '${summary.counts.present}/${summary.totalSessions} present '
                    '· ${summary.counts.absent} absent'
                : 'No sessions yet',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
