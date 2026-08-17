import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/network/api_response.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/attendance.dart';
import '../bloc/attendance_overview_cubit.dart';
import '../bloc/attendance_sessions_cubit.dart';
import '../widgets/attendance_percent_card.dart';
import '../widgets/attendance_session_tile.dart';
import '../widgets/course_attendance_card.dart';

/// Port of `src/pages/student/attendance/index.tsx`.
///
/// The web lays this out as five stat cards, a grid of per-course cards, and a
/// numbered-paginated table. Here the stats and the breakdown become the header
/// of one scroll view and the table becomes an infinite list of cards — the same
/// arrangement Quizzes and Practice use, so the app has one way to read a long
/// list rather than two. The web's `1–10 of 42 sessions` label survives as the
/// total beside the "All Sessions" heading.
///
/// The header is deliberately outside the sessions [RemoteView]: filtering down
/// to a status with no records must not blank the stats, which is what the web
/// does too — its empty state lives inside the sessions panel alone.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  /// What the open filter sheet has staged so far. Owned by the page so the
  /// sheet's actions can read it, and never disposed mid-animation.
  final _filterDraft = ValueNotifier(const _AttendanceFilters());

  @override
  void initState() {
    super.initState();
    context.read<AttendanceOverviewCubit>().load();
    context.read<AttendanceSessionsCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  /// Runs a query change, then rebuilds — the filter badge and the empty copy
  /// are read off `cubit.query`, which is deliberately not part of the state.
  Future<void> _apply(Future<void> Function() change) async {
    await change();
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<AttendanceOverviewCubit>().load(refresh: true),
      context.read<AttendanceSessionsCubit>().load(refresh: true),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _openFilters(AttendanceSessionsCubit cubit) async {
    // Read off the overview rather than fetched: the analytics payload already
    // carries the course list, so the sheet costs no request. If that load
    // failed the group is simply omitted.
    final overview = context.read<AttendanceOverviewCubit>().state.data;
    final courses = overview?.courses ?? const <CourseAttendanceSummary>[];

    _filterDraft.value = _AttendanceFilters(
      courseId: cubit.query.courseId,
      status: cubit.query.status,
    );
    final applied = await showAppSheet<_AttendanceFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(
        draft: _filterDraft,
        courses: courses,
        cappedNote: (overview?.isCourseListCapped ?? false) ? _cappedNote : null,
      ),
    );
    if (applied == null || !mounted) return;

    await _apply(
      () => cubit.setFilters(courseId: applied.courseId, status: applied.status),
    );
  }

  /// Said the same way in both places it appears. Worded to be true whether the
  /// list was actually truncated or the student simply has exactly ten courses —
  /// the server sends no total, so the two are indistinguishable.
  static const _cappedNote =
      'Showing 10 courses. Overall totals include every enrolled course.';

  @override
  Widget build(BuildContext context) {
    final sessions = context.read<AttendanceSessionsCubit>();
    final glassInsets = context.glassContentInsets;
    final hasFilters = sessions.query.hasFilters;

    return StudentScaffold(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: InfiniteScroll(
          onLoadMore: sessions.loadMore,
          child: BlocBuilder<AttendanceSessionsCubit,
              RemoteState<Paginated<AttendanceSession>>>(
            builder: (context, state) {
              final items = state.data?.items ?? const <AttendanceSession>[];
              final total = state.data?.pagination.total;

              // The list stays lazy while there are rows; when there are none
              // the single slot renders whichever of loading / error / empty
              // applies.
              final bodyCount = items.isEmpty ? 1 : items.length;

              return ListView.builder(
                // No controller: the list must stay on the
                // PrimaryScrollController so it coordinates with the shell's
                // collapsing header.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + glassInsets.bottom),
                itemCount: 1 + bodyCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Header(
                      total: total,
                      activeFilters: sessions.query.activeFilterCount,
                      onOpenFilters: () => _openFilters(sessions),
                    );
                  }

                  if (index == 1 + bodyCount) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppLoadMoreFooter(
                        isLoading: sessions.isLoadingMore || sessions.hasMore,
                        hasMore: sessions.hasMore,
                        endLabel: 'No more sessions',
                      ),
                    );
                  }

                  if (items.isEmpty) {
                    return RemoteView<AttendanceSessionsCubit,
                        Paginated<AttendanceSession>>(
                      onRetry: sessions.load,
                      loading: const AppListSkeleton(rows: 4),
                      isEmpty: (page) => page.items.isEmpty,
                      // A filtered-empty list is a different problem from an
                      // empty one, and only one of them is the student's to fix.
                      emptyTitle: hasFilters
                          ? 'No sessions match your filters'
                          : 'No attendance records',
                      emptyDescription: hasFilters
                          ? 'Try adjusting your filters.'
                          : 'Your attendance will appear here once your '
                              'teachers mark it.',
                      emptyIcon: Icons.event_available_outlined,
                      builder: (context, page) => const SizedBox.shrink(),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AttendanceSessionTile(
                      session: items[index - 1],
                      showCourseCode: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Stats, the course breakdown, and the "All Sessions" heading.
class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.activeFilters,
    required this.onOpenFilters,
  });

  final int? total;
  final int activeFilters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AttendanceOverviewCubit, RemoteState<AttendanceOverview>>(
      builder: (context, state) {
        final overview = state.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isInitialLoading)
              const _StatsSkeleton()
            else if (overview != null) ...[
              _Stats(overview: overview),
              if (overview.courses.isNotEmpty) ...[
                const SizedBox(height: 16),
                _CourseBreakdown(overview: overview),
              ],
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Text('All Sessions', style: theme.textTheme.titleSmall),
                if (total != null) ...[
                  const SizedBox(width: 8),
                  // Carries the web paginator's "of 42 sessions" count, which
                  // infinite scroll would otherwise drop.
                  Text('$total', style: theme.textTheme.labelSmall),
                ],
                const Spacer(),
                _FilterButton(
                  activeCount: activeFilters,
                  onPressed: onOpenFilters,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.overview});

  final AttendanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final overall = overview.overall;
    final counts = overall.counts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStatGrid(
          tiles: [
            AppStatTile(
              label: 'Total Sessions',
              value: '${overall.totalSessions}',
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
        AttendancePercentCard(
          label: 'Overall %',
          percentage: overall.percentage,
          hasSessions: overall.totalSessions > 0,
          // Pre-empts the obvious "this is wrong" reading: the server's
          // numerator is `present` alone.
          caption: 'Late and leave are not counted as present.',
        ),
      ],
    );
  }
}

class _CourseBreakdown extends StatelessWidget {
  const _CourseBreakdown({required this.overview});

  final AttendanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Course-wise Attendance', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        for (final summary in overview.courses)
          Padding(
            key: ValueKey(summary.key),
            padding: const EdgeInsets.only(bottom: 10),
            child: CourseAttendanceCard(summary: summary),
          ),
        if (overview.isCourseListCapped)
          Text(
            _AttendancePageState._cappedNote,
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Same grid geometry as the loaded state, so nothing jumps when the
          // numbers arrive.
          AppStatGrid(
            tiles: [
              AppSkeleton(height: 118, radius: AppTheme.radiusLg),
              AppSkeleton(height: 118, radius: AppTheme.radiusLg),
              AppSkeleton(height: 118, radius: AppTheme.radiusLg),
              AppSkeleton(height: 118, radius: AppTheme.radiusLg),
            ],
          ),
          SizedBox(height: 12),
          AppSkeleton(height: 76, radius: AppTheme.radiusLg),
        ],
      );
}

/// The filter entry point: an icon that carries a count when filters are on.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);
    final isActive = activeCount > 0;

    return IconButton(
      tooltip: isActive ? 'Filters ($activeCount applied)' : 'Filters',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune_rounded,
            // Tinted while filtered, so the list never looks unexpectedly short
            // with no visible reason why.
            color: isActive ? scheme.primary : null,
          ),
          if (isActive)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 15,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primaryForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two filters the sheet can change, as one value so they can be staged and
/// applied atomically.
@immutable
class _AttendanceFilters {
  const _AttendanceFilters({this.courseId, this.status});

  final String? courseId;
  final String? status;

  int get activeCount => (courseId != null ? 1 : 0) + (status != null ? 1 : 0);
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.draft,
    required this.courses,
    this.cappedNote,
  });

  final ValueNotifier<_AttendanceFilters> draft;
  final List<CourseAttendanceSummary> courses;

  /// Explains why a course the student is enrolled in might not be listed.
  final String? cappedNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<_AttendanceFilters>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (courses.isNotEmpty) ...[
            AppOptionGroup<String?>(
              header: 'Course',
              selected: value.courseId,
              onSelected: (courseId) => draft.value =
                  _AttendanceFilters(courseId: courseId, status: value.status),
              options: [
                const AppOptionItem(
                  value: null,
                  label: 'All courses',
                  icon: Icons.apps_rounded,
                ),
                for (final course in courses)
                  AppOptionItem(
                    value: course.courseId,
                    label: course.courseName,
                    description:
                        course.courseCode.isEmpty ? null : course.courseCode,
                    icon: Icons.menu_book_outlined,
                  ),
              ],
            ),
            if (cappedNote case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(note, style: theme.textTheme.labelSmall),
              ),
          ],
          AppOptionGroup<String?>(
            header: 'Status',
            selected: value.status,
            onSelected: (status) => draft.value =
                _AttendanceFilters(courseId: value.courseId, status: status),
            options: [
              const AppOptionItem(
                value: null,
                label: 'All statuses',
                icon: Icons.apps_rounded,
              ),
              for (final status in AttendanceMeta.statuses)
                AppOptionItem(
                  value: status,
                  label: AttendanceMeta.statusLabel(status),
                  icon: _statusIcon(status),
                ),
            ],
          ),
          AppFilterActions(
            // Disabled at defaults, so the button never implies there is
            // something to clear when there is not.
            onReset: value.activeCount == 0
                ? null
                : () => draft.value = const _AttendanceFilters(),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }

  static IconData _statusIcon(String status) => switch (status) {
        'present' => Icons.check_circle_outline_rounded,
        'absent' => Icons.cancel_outlined,
        'late' => Icons.schedule_rounded,
        'leave' => Icons.event_busy_outlined,
        _ => Icons.circle_outlined,
      };
}
