import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/teacher_dashboard.dart';

/// Port of `src/pages/teacher/dashboard/components/today-sessions.tsx`.
///
/// A vertical timeline of today's timetable: dot + connector, the server's
/// pre-formatted time, a status pill, and the room/division context.
class TodaySessionsTimeline extends StatelessWidget {
  const TodaySessionsTimeline({super.key, required this.sessions});

  final List<TeacherTodaySession> sessions;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: "Today's Sessions",
      subtitle: 'Your schedule for today',
      icon: Icons.schedule_rounded,
      trailing: const _DateChip(),
      child: sessions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppEmptyState(
                title: 'No sessions scheduled for today.',
                icon: Icons.event_busy_outlined,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < sessions.length; i++)
                  StaggeredEntrance(
                    index: i,
                    child: _SessionRow(
                      session: sessions[i],
                      isLast: i == sessions.length - 1,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Today's date, as the web card shows it (`en-GB`, "18 Aug").
class _DateChip extends StatelessWidget {
  const _DateChip();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        DateFormat('d MMM').format(DateTime.now()),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.isLast});

  final TeacherTodaySession session;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final tone = tokens.tone(TeacherSessionStatus.shade(session.status));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The timeline rail: a tinted dot per row, joined by a hairline that
          // stops at the last one.
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 15),
                  decoration: BoxDecoration(
                    color: tone.foreground,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: scheme.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                // The live row is tinted so it reads first — `bg-emerald-500/[0.04]`.
                color: session.isLive ? tone.background : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        session.time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppBadge(
                        TeacherSessionStatus.label(session.status),
                        shade: TeacherSessionStatus.shade(session.status),
                        dense: true,
                      ),
                      const Spacer(),
                      if (session.roomOrNull != null)
                        Flexible(
                          child: Text(
                            session.roomOrNull!,
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      // A finished class is struck through, as on the web.
                      decoration:
                          session.isCompleted ? TextDecoration.lineThrough : null,
                      color: session.isCompleted
                          ? scheme.mutedForeground
                          : scheme.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (session.divisionOrNull != null)
                        'Division ${session.divisionOrNull}',
                      '${session.students} students',
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
