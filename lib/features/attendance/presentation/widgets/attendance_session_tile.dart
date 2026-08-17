import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/attendance.dart';

/// One marked session: the date, what kind of class it was, and how the student
/// was marked.
///
/// Shared by the Attendance screen and the in-course attendance tab, which the
/// web renders identically. `remark`, `startTime` and `endTime` come back from
/// the API but neither web page shows them, so neither does this.
class AttendanceSessionTile extends StatelessWidget {
  const AttendanceSessionTile({
    super.key,
    required this.session,
    this.showCourseCode = false,
  });

  final AttendanceSession session;

  /// The course screen is already scoped to one course; the standalone
  /// Attendance screen spans all of them and needs to say which is which.
  final bool showCourseCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final code = session.courseCode ?? '';
    final subtitle = [
      if (showCourseCode && code.isNotEmpty) code,
      AttendanceMeta.typeLabel(session.type),
    ].join(' · ');

    final topic = session.topic ?? '';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.dmyLong(session.sessionDate),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.labelSmall),
                if (topic.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    topic,
                    style: theme.textTheme.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppBadge(
            AttendanceMeta.statusLabel(session.status),
            // Not `AppBadge.status`, which reads `leave` as slate — attendance
            // has its own vocabulary and maps it to cyan.
            shade: AttendanceMeta.statusShade(session.status),
            dense: true,
          ),
        ],
      ),
    );
  }
}
