import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/attendance_session.dart';
import '../bloc/attendance_tab_cubit.dart';
import '../pages/roster_page.dart';
import 'create_session_sheet.dart';

/// Port of `.../detail/attendance/index.tsx`.
///
/// Scoped by the course and the section chosen in the detail shell; it has no
/// selector of its own.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  @override
  void initState() {
    super.initState();
    context.read<AttendanceTabCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttendanceTabCubit>();

    return Column(
      children: [
        _Toolbar(cubit: cubit),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<AttendanceTabCubit, AttendanceTabData>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.all(16),
                child: AppListSkeleton(rows: 4, lines: 2),
              ),
              builder: (context, data) {
                if (data.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No attendance sessions',
                    description:
                        'Create a session to start marking attendance for '
                        'this division.',
                    action: AppButton(
                      label: 'Create session',
                      variant: AppButtonVariant.outline,
                      onPressed: () => _create(cubit),
                    ),
                  );
                }

                return RefreshableScroll(
                  onRefresh: () => cubit.load(refresh: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.analytics != null) ...[
                        _AnalyticsStrip(analytics: data.analytics!),
                        const SizedBox(height: 12),
                      ],
                      // Pending slots sit above the real sessions: they are
                      // today's work, and the list below is history.
                      for (final slot in data.pendingSlots) ...[
                        _PendingSlotCard(
                          slot: slot,
                          onCreate: () => _createFromSlot(cubit, slot),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (var i = 0; i < data.page.items.length; i++) ...[
                        StaggeredEntrance(
                          index: i,
                          child: _SessionCard(
                            session: data.page.items[i],
                            onOpen: () => _open(cubit, data.page.items[i].id),
                            onDelete: data.page.items[i].isEditable
                                ? () => _delete(cubit, data.page.items[i])
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (data.page.pagination.totalPages > 1)
                        AppPaginator(
                          pagination: data.page.pagination,
                          onPageChanged: cubit.setPage,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(AttendanceTabCubit cubit, String sessionId) async {
    await RosterPage.push(context, sessionId: sessionId);
    // Marking changes the counts on the row that was just tapped.
    if (mounted) await cubit.load(refresh: true);
  }

  Future<void> _create(AttendanceTabCubit cubit) async {
    final created = await showCreateSessionSheet(
      context,
      courseId: cubit.courseId,
      divisionId: cubit.divisionId,
    );
    if (created == null || !mounted) return;
    await _open(cubit, created);
  }

  /// One tap, no dialog — the slot already carries the course, division, time
  /// and title, so asking again would be busywork.
  Future<void> _createFromSlot(AttendanceTabCubit cubit, TodaySlot slot) async {
    final created = await createSessionFromSlot(context, slot: slot);
    if (created == null || !mounted) return;
    await _open(cubit, created);
  }

  Future<void> _delete(
    AttendanceTabCubit cubit,
    AttendanceSession session,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete attendance session?',
      message: 'This permanently removes the session and any marked '
          'attendance. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final failure = await cubit.deleteSession(session.id);
    if (!mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Session deleted.');
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.cubit});

  final AttendanceTabCubit cubit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppSelect<String?>(
              dense: true,
              value: cubit.status,
              hint: 'All statuses',
              items: [
                const AppSelectItem<String?>(
                  value: null,
                  label: 'All statuses',
                ),
                for (final status in AttendanceStatus.options)
                  AppSelectItem<String?>(
                    value: status,
                    label: AttendanceStatus.label(status),
                  ),
              ],
              onChanged: cubit.setStatus,
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            label: 'Create',
            icon: Icons.add_rounded,
            size: AppButtonSize.sm,
            onPressed: () async {
              final created = await showCreateSessionSheet(
                context,
                courseId: cubit.courseId,
                divisionId: cubit.divisionId,
              );
              if (created == null || !context.mounted) return;
              await RosterPage.push(context, sessionId: created);
              if (context.mounted) await cubit.load(refresh: true);
            },
          ),
        ],
      ),
    );
  }
}

/// Sessions · Present · Absent · Late+Leave · Avg present.
class _AnalyticsStrip extends StatelessWidget {
  const _AnalyticsStrip({required this.analytics});

  final AttendanceAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final percent = analytics.presentPercent;

    return AppStatGrid(
      tiles: [
        AppStatTile(
          label: 'Sessions',
          value: Fmt.number(analytics.totalSessions),
          icon: Icons.event_note_outlined,
          shade: TwColors.blue,
        ),
        AppStatTile(
          label: 'Present',
          value: Fmt.number(analytics.present),
          icon: Icons.check_circle_outline_rounded,
          shade: TwColors.emerald,
        ),
        AppStatTile(
          label: 'Absent',
          value: Fmt.number(analytics.absent),
          icon: Icons.cancel_outlined,
          shade: TwColors.rose,
        ),
        AppStatTile(
          label: 'Late / leave',
          value: Fmt.number(analytics.late + analytics.leave),
          icon: Icons.schedule_rounded,
          shade: TwColors.amber,
        ),
        AppStatTile(
          label: 'Avg. present',
          // Null, not 0%, when nothing is marked — 0% would read as everyone
          // absent rather than as no data.
          value: percent == null ? '—' : '$percent%',
          icon: Icons.percent_rounded,
          shade: TwColors.violet,
        ),
      ],
    );
  }
}

/// Today's timetable slot with no session yet.
class _PendingSlotCard extends StatelessWidget {
  const _PendingSlotCard({required this.slot, required this.onCreate});

  final TodaySlot slot;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        // Dashed is not a Flutter border style; a tinted outline reads the same
        // way — provisional, not yet a real row.
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  "Today's session",
                  shade: TwColors.violet,
                  dense: true,
                ),
                const SizedBox(height: 6),
                Text(
                  slot.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _clock(slot.startTime),
                    if (slot.endTime != null) _clock(slot.endTime),
                    if ((slot.roomCode ?? slot.roomName) != null)
                      slot.roomCode ?? slot.roomName!,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            label: 'Create',
            size: AppButtonSize.sm,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }

  /// Slot times are `"HH:MM:SS"` clock strings with no date, unlike a session's
  /// ISO timestamps — so they are trimmed, not parsed.
  static String? _clock(String? value) {
    if (value == null || value.length < 5) return value;
    return value.substring(0, 5);
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onOpen,
    this.onDelete,
  });

  final AttendanceSession session;
  final VoidCallback onOpen;

  /// Absent once finalized — the API refuses the delete then.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      AttendanceStatus.label(session.status),
                      shade: AttendanceStatus.shade(session.status),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    Fmt.dmy(session.sessionDate),
                    AttendanceType.label(session.type),
                    if (session.startTime != null) Fmt.time(session.startTime),
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  // Marked-of-roster is what says whether work is left.
                  '${session.markedCount} / ${session.rosterSize} marked',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete session',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: scheme.destructive,
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: scheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}
