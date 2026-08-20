import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../attendance/domain/entities/attendance.dart';
import '../../../attendance/presentation/widgets/attendance_percent_card.dart';
import '../../../attendance/presentation/widgets/attendance_session_tile.dart';
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
              AttendancePercentCard(percentage: data.analytics.percentage),

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
                    child: AttendanceSessionTile(session: session),
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
