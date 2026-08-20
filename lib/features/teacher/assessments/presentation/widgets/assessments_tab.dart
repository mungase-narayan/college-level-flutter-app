import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../bloc/assessments_list_cubit.dart';
import '../pages/assessment_results_page.dart';
import 'assessment_card.dart';
import 'assessment_form_sheet.dart';
import 'assessment_view_sheet.dart';

/// Port of `.../detail/assignments/index.tsx` and `.../detail/quiz/index.tsx`.
///
/// One widget for both: the pages are identical apart from which half of the
/// payload they keep and the noun in their copy, so the cubit carries both and
/// this reads them.
class AssessmentsTab extends StatefulWidget {
  const AssessmentsTab({super.key});

  @override
  State<AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends State<AssessmentsTab> {
  @override
  void initState() {
    super.initState();
    context.read<AssessmentsListCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssessmentsListCubit>();

    return Column(
      children: [
        _Toolbar(
          cubit: cubit,
          onSearch: (value) => setState(() => cubit.setSearch(value)),
          onCreate: () => _create(cubit),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<AssessmentsListCubit, List<TeacherAssessment>>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.all(16),
                child: AppListSkeleton(rows: 4, lines: 3),
              ),
              builder: (context, _) {
                final rows = cubit.visible;
                if (rows.isEmpty) return _Empty(cubit: cubit);

                final start = (cubit.page.clamp(1, cubit.totalPages) - 1) *
                    AssessmentsListCubit.pageSize;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      StaggeredEntrance(
                        index: i,
                        child: AssessmentCard(
                          assessment: rows[i],
                          number: start + i + 1,
                          onTap: () => _view(rows[i]),
                          onActions: () => _actions(cubit, rows[i]),
                        ),
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

  Future<void> _view(TeacherAssessment assessment) =>
      showAssessmentViewSheet(context, assessmentId: assessment.id);

  Future<void> _actions(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    final action = await showAppOptionSheet<String>(
      context,
      title: assessment.title,
      options: const [
        AppSheetOption(
          value: 'view',
          label: 'View details',
          icon: Icons.visibility_outlined,
        ),
        AppSheetOption(
          value: 'edit',
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        AppSheetOption(
          value: 'results',
          label: 'Submissions',
          icon: Icons.groups_outlined,
        ),
        AppSheetOption(
          value: 'delete',
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'view':
        await _view(assessment);
      case 'edit':
        await _edit(cubit, assessment);
      case 'results':
        await _results(cubit, assessment);
      case 'delete':
        await _delete(cubit, assessment);
    }
  }

  /// Opens the form, and refetches only when something was actually saved.
  Future<void> _edit(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    final saved = await showAssessmentFormSheet(
      context,
      courseId: cubit.courseId,
      divisionId: cubit.divisionId,
      quiz: cubit.quizzes,
      assessmentId: assessment.id,
    );
    if (saved && mounted) await cubit.load(refresh: true);
  }

  /// The results screen can write grades back, so the list refetches on the
  /// way out — the Evaluated count on each card comes from it.
  Future<void> _results(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentResultsPage(
          assessmentId: assessment.id,
          quiz: cubit.quizzes,
        ),
      ),
    );
    if (mounted) await cubit.load(refresh: true);
  }

  Future<void> _create(AssessmentsListCubit cubit) async {
    final saved = await showAssessmentFormSheet(
      context,
      courseId: cubit.courseId,
      divisionId: cubit.divisionId,
      quiz: cubit.quizzes,
    );
    if (saved && mounted) await cubit.load(refresh: true);
  }

  Future<void> _delete(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      // The web hardcodes "Assignment" here even in the Quiz tab.
      title: 'Delete ${cubit.noun}?',
      message: '"${assessment.title}" will be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final failure = await cubit.delete(assessment.id);
    if (!mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, '"${assessment.title}" deleted.');
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.cubit,
    required this.onSearch,
    required this.onCreate,
  });

  final AssessmentsListCubit cubit;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;

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
              hint: 'Search ${cubit.nounPlural}',
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Create',
            icon: Icons.add_rounded,
            size: AppButtonSize.sm,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

/// The empty state, which distinguishes "none at all" from "none matching".
class _Empty extends StatelessWidget {
  const _Empty({required this.cubit});

  final AssessmentsListCubit cubit;

  @override
  Widget build(BuildContext context) {
    // Tested against this tab's own half of the payload, not the whole list —
    // the web tests the whole one, so a course with only quizzes tells the
    // teacher "no matches" on the Assignments tab instead of offering to
    // create the first one.
    final nothingYet = cubit.isEmptyCategory;

    return AppEmptyState(
      icon: cubit.quizzes
          ? Icons.checklist_outlined
          : Icons.assignment_outlined,
      title: nothingYet
          ? 'No ${cubit.nounPlural} yet'
          : 'No matching ${cubit.nounPlural}',
      description: nothingYet
          ? 'Create your first ${cubit.noun} for this course.'
          : 'Try adjusting your search.',
    );
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
