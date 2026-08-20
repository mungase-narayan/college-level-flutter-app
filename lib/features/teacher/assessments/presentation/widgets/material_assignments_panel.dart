import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../bloc/assessments_list_cubit.dart';
import '../pages/assessment_results_page.dart';
import 'assessment_card.dart';
import 'assessment_form_sheet.dart';
import 'assessment_view_sheet.dart';

/// Port of `.../learning-plan/components/material-assignments.tsx`.
///
/// The same list as the course Assignments tab, scoped to one material rather
/// than one section — an assignment published against a material reaches every
/// section, so no division is passed. There is no search and no paging here:
/// a single material holds few enough assignments to show at once, and the web
/// does the same.
class MaterialAssignmentsPanel extends StatefulWidget {
  const MaterialAssignmentsPanel({
    super.key,
    required this.courseMaterialId,
    this.divisionId,
  });

  final String courseMaterialId;

  /// The section the teacher is viewing. The list ignores it — a material
  /// assignment reaches every section — but a newly created one is scoped to
  /// it unless the teacher marks it semester-wide.
  final String? divisionId;

  @override
  State<MaterialAssignmentsPanel> createState() =>
      _MaterialAssignmentsPanelState();
}

class _MaterialAssignmentsPanelState extends State<MaterialAssignmentsPanel> {
  @override
  void initState() {
    super.initState();
    context.read<AssessmentsListCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssessmentsListCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.load(refresh: true),
      child: RemoteView<AssessmentsListCubit, List<TeacherAssessment>>(
        onRetry: cubit.load,
        loading: const Padding(
          padding: EdgeInsets.all(16),
          child: AppListSkeleton(rows: 3, lines: 3),
        ),
        builder: (context, _) {
          final rows = cubit.owned;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(count: rows.length, onCreate: () => _create(cubit)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const AppEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No assignments yet',
                  description: 'Create the first assignment for this material.',
                )
              else
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  StaggeredEntrance(
                    index: i,
                    child: AssessmentCard(
                      assessment: rows[i],
                      number: i + 1,
                      onTap: () => _view(rows[i]),
                      onActions: () => _actions(cubit, rows[i]),
                    ),
                  ),
                ],
            ],
          );
        },
      ),
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
        await _openForm(cubit, assessmentId: assessment.id);
      case 'results':
        await _results(cubit, assessment);
      case 'delete':
        await _delete(cubit, assessment);
    }
  }

  Future<void> _results(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        // Never a quiz: one cannot be attached to a material.
        builder: (_) => AssessmentResultsPage(
          assessmentId: assessment.id,
          quiz: false,
        ),
      ),
    );
    if (mounted) await cubit.load(refresh: true);
  }

  Future<void> _create(AssessmentsListCubit cubit) =>
      _openForm(cubit);

  /// Always the assignment variant, and always scoped to this material — a
  /// quiz cannot be attached to one.
  Future<void> _openForm(
    AssessmentsListCubit cubit, {
    String? assessmentId,
  }) async {
    final saved = await showAssessmentFormSheet(
      context,
      courseId: cubit.courseId,
      quiz: false,
      divisionId: widget.divisionId,
      courseMaterialId: widget.courseMaterialId,
      assessmentId: assessmentId,
    );
    if (saved && mounted) await cubit.load(refresh: true);
  }

  Future<void> _delete(
    AssessmentsListCubit cubit,
    TeacherAssessment assessment,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete assignment?',
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

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onCreate});

  final int count;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count == 0 ? 'Assignments' : 'Assignments ($count)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Scoped to this material',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppButton(
          label: 'Create',
          icon: Icons.add_rounded,
          size: AppButtonSize.sm,
          onPressed: onCreate,
        ),
      ],
    );
  }
}
