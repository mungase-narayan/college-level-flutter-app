import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/constants/user_constants.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../domain/entities/course_enrollment.dart';
import '../bloc/enrollments_cubit.dart';
import 'enroll_students_sheet.dart';

/// Port of `TeacherCourseEnrollmentsPage`.
///
/// Not division-scoped — enrolment is against the course, so this ignores the
/// section chosen in the shell.
class EnrollmentsTab extends StatefulWidget {
  const EnrollmentsTab({super.key});

  @override
  State<EnrollmentsTab> createState() => _EnrollmentsTabState();
}

class _EnrollmentsTabState extends State<EnrollmentsTab> {
  @override
  void initState() {
    super.initState();
    context.read<EnrollmentsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EnrollmentsCubit>();

    // `/course-enrollments` is guarded `school_admin` + `teacher` only, so a
    // class_teacher or hod 403s on every verb — including the list. The web
    // ships the buttons anyway and lets each call fail; here they are gated,
    // and the reason is stated rather than surfaced as a bare error.
    final canManage =
        context.select((AuthBloc bloc) => bloc.state.hasRole(UserRole.teacher));

    return Column(
      children: [
        _Toolbar(
          cubit: cubit,
          canManage: canManage,
          // The search term lives on the cubit rather than in its state, so
          // the tab rebuilds itself to pick up the new page.
          onSearch: (value) => setState(() => cubit.setSearch(value)),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<EnrollmentsCubit, List<CourseEnrollmentRow>>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.all(16),
                child: AppListSkeleton(rows: 5, lines: 2),
              ),
              builder: (context, _) {
                if (!canManage) return const _NoPermission();

                final rows = cubit.visible;
                if (rows.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.group_outlined,
                    title: cubit.search.isEmpty
                        ? 'No students enrolled'
                        : 'No matching students',
                    description: cubit.search.isEmpty
                        ? 'Enrol students to give them access to this course.'
                        : 'Try a different name, roll number, or email.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _EnrollmentCard(
                        row: rows[i],
                        onStatus: (status) => _setStatus(cubit, rows[i], status),
                        onRemove: () => _remove(cubit, rows[i]),
                      ),
                    ],
                    if (cubit.totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _Paginator(
                          page: cubit.page,
                          totalPages: cubit.totalPages,
                          onChanged: (value) =>
                              setState(() => cubit.setPage(value)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setStatus(
    EnrollmentsCubit cubit,
    CourseEnrollmentRow row,
    String status,
  ) async {
    final failure = await cubit.setStatus(id: row.id, status: status);
    if (!mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(
      context,
      '${row.fullName} marked as ${EnrollmentStatus.label(status).toLowerCase()}',
    );
  }

  Future<void> _remove(EnrollmentsCubit cubit, CourseEnrollmentRow row) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Unenrol ${row.fullName}?',
      message: 'They lose access to this course and its materials.',
      confirmLabel: 'Unenrol',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final failure = await cubit.remove(row.id);
    if (!mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, '${row.fullName} unenrolled from course');
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.cubit,
    required this.canManage,
    required this.onSearch,
  });

  final EnrollmentsCubit cubit;
  final bool canManage;
  final ValueChanged<String> onSearch;

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
            child: AppSearchField(
              dense: true,
              hint: 'Search students',
              onChanged: onSearch,
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            AppButton(
              label: 'Enrol',
              icon: Icons.person_add_alt_1_rounded,
              size: AppButtonSize.sm,
              onPressed: () => showEnrollStudentsSheet(context, cubit: cubit),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown to a class_teacher or hod, who the API refuses outright.
class _NoPermission extends StatelessWidget {
  const _NoPermission();

  @override
  Widget build(BuildContext context) => const AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Enrolment is limited to course teachers',
        description:
            'Your role can view the course but not manage who is enrolled on '
            'it. A teacher or a school admin can make changes here.',
      );
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({
    required this.row,
    required this.onStatus,
    required this.onRemove,
  });

  final CourseEnrollmentRow row;
  final ValueChanged<String> onStatus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppAvatar(imageUrl: row.avatar, name: row.fullName, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.fullName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      EnrollmentStatus.label(row.status),
                      shade: EnrollmentStatus.shade(row.status),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((row.rollNumber ?? '').isNotEmpty) row.rollNumber!,
                    // The web's table gives the PRN its own column; on a card
                    // it joins the identity line rather than being dropped.
                    if ((row.prnNumber ?? '').isNotEmpty)
                      'PRN ${row.prnNumber!}',
                    if ((row.email ?? '').isNotEmpty) row.email!,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.divisionName != null || row.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (row.divisionName != null) 'Div ${row.divisionName}',
                      if (row.createdAt != null)
                        'Enrolled ${Fmt.dmy(row.createdAt)}',
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actions',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: scheme.mutedForeground,
            ),
            onPressed: () => _openActions(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final action = await showAppOptionSheet<String>(
      context,
      title: row.fullName,
      options: [
        // Only the statuses this row is not already in.
        for (final status in EnrollmentStatus.options)
          if (status != row.status)
            AppSheetOption(
              value: status,
              label: switch (status) {
                EnrollmentStatus.active => 'Set active',
                EnrollmentStatus.archived => 'Archive',
                _ => 'Drop',
              },
              icon: switch (status) {
                EnrollmentStatus.active => Icons.play_circle_outline_rounded,
                EnrollmentStatus.archived => Icons.archive_outlined,
                _ => Icons.remove_circle_outline_rounded,
              },
            ),
        const AppSheetOption(
          value: 'remove',
          label: 'Unenrol',
          icon: Icons.person_remove_alt_1_outlined,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    action == 'remove' ? onRemove() : onStatus(action);
  }
}

class _Paginator extends StatelessWidget {
  const _Paginator({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          'Page $page of $totalPages',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        IconButton(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
