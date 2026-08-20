import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../assessments/domain/entities/student_assessment.dart';
import '../../../assessments/presentation/widgets/assessment_board.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../bloc/course_tabs_cubit.dart';

/// The Assignments tab of the material page — the assignments published against
/// this one material, matching `useStudentAssignments(courseId, materialId)`.
///
/// The cubit is created with a `courseMaterialId`, so this reuses the course
/// Assignments tab's whole data path with one extra query parameter.
class MaterialAssignmentsTab extends StatefulWidget {
  const MaterialAssignmentsTab({super.key});

  @override
  State<MaterialAssignmentsTab> createState() => _MaterialAssignmentsTabState();
}

class _MaterialAssignmentsTabState extends State<MaterialAssignmentsTab> {
  @override
  void initState() {
    super.initState();
    context.read<CourseAssessmentsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourseAssessmentsCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.load(refresh: true),
      child: RemoteView<CourseAssessmentsCubit, List<StudentAssessment>>(
        onRetry: cubit.load,
        loading: const Padding(
          padding: EdgeInsets.all(16),
          child: AppListSkeleton(rows: 2),
        ),
        builder: (context, items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 28),
                AppEmptyState(
                  title: 'No assignments',
                  description:
                      'No assignments have been published for this material.',
                  icon: Icons.assignment_outlined,
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AssessmentBoard(
                items: items,
                kind: 'Assignment',
                onOpen: (item) async {
                  await context.push(StudentRoutes.assignmentDetail(item.id));
                  // The row's status may have changed while it was open.
                  if (context.mounted) await cubit.load(refresh: true);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
