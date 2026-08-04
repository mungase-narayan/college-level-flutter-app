import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../attendance/domain/entities/attendance.dart';
import '../bloc/course_tabs_cubit.dart';

/// Port of `courses/detail/attendance/index.tsx`.
///
/// Five stat tiles over a status-filtered session list. Percentages come from
/// the API — the client never recomputes them.
class CourseAttendanceTab extends StatefulWidget {
  const CourseAttendanceTab({super.key});

  @override
  State<CourseAttendanceTab> createState() => _CourseAttendanceTabState();
}

class _CourseAttendanceTabState extends State<CourseAttendanceTab> {
  @override
  void initState() {
    super.initState();
    context.read<CourseAttendanceCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourseAttendanceCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.load(refresh: true),
      child: RemoteView<CourseAttendanceCubit, CourseAttendanceData>(
        onRetry: cubit.load,
        loading: const Padding(
          padding: EdgeInsets.all(16),
          child: AppListSkeleton(rows: 4),
        ),
        builder: (context, data) {
          final counts = data.analytics.counts;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AppStatGrid(
                tiles: [
                  AppStatTile(
                    label: 'Sessions',
                    value: '${data.analytics.totalSessions}',
                    icon: Icons.calendar_month_outlined,
                    shade: TwColors.violet,
                  ),
                  AppStatTile(
                    label: 'Present',
                    value: '${counts.present}',
                    icon: Icons.check_circle_outline_rounded,
                    shade: TwColors.emerald,
                  ),
                  AppStatTile(
                    label: 'Absent',
                    value: '${counts.absent}',
                    icon: Icons.cancel_outlined,
                    shade: TwColors.rose,
                  ),
                  AppStatTile(
                    label: 'Late / Leave',
                    value: '${counts.lateAndLeave}',
                    icon: Icons.schedule_rounded,
                    shade: TwColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PercentageCard(percentage: data.analytics.percentage),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All sessions',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final status = await showAppOptionSheet<String>(
                        context,
                        title: 'Filter by status',
                        selected: cubit.statusFilter ?? '',
                        options: [
                          const AppSheetOption(value: '', label: 'All statuses'),
                          for (final status in AttendanceMeta.statuses)
                            AppSheetOption(
                              value: status,
                              label: AttendanceMeta.statusLabel(status),
                            ),
                        ],
                      );
                      if (status == null) return;
                      await cubit.setStatus(status.isEmpty ? null : status);
                    },
                    icon: const Icon(Icons.filter_list_rounded, size: 17),
                    label: Text(
                      cubit.statusFilter == null
                          ? 'All statuses'
                          : AttendanceMeta.statusLabel(cubit.statusFilter!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (data.sessions.items.isEmpty)
                const AppEmptyState(
                  title: 'No attendance records',
                  description:
                      'Your attendance will appear here once your teachers mark '
                      'it for this course.',
                  icon: Icons.event_available_outlined,
                )
              else ...[
                for (final session in data.sessions.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionRow(session: session),
                  ),
                AppPaginator(
                  pagination: data.sessions.pagination,
                  onPageChanged: cubit.setPage,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The overall-percentage card, using the ≥75 / ≥50 colour rule.
class _PercentageCard extends StatelessWidget {
  const _PercentageCard({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AttendanceMeta.percentColor(percentage);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Attendance', style: theme.textTheme.labelSmall),
              ),
              Text(
                '$percentage%',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.scheme.muted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(AttendanceMeta.statusShade(session.status));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: context.scheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.dmy(session.sessionDate),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    AttendanceMeta.typeLabel(session.type),
                    if ((session.topic ?? '').isNotEmpty) session.topic!,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              AttendanceMeta.statusLabel(session.status),
              style: TextStyle(
                color: tone.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
