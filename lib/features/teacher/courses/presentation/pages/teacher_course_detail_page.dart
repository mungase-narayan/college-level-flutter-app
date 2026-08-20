import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../enrollments/domain/usecases/enrollment_usecases.dart';
import '../../../enrollments/presentation/bloc/enrollments_cubit.dart';
import '../../../enrollments/presentation/widgets/enrollments_tab.dart';
import '../../../assessments/domain/usecases/teacher_assessment_usecases.dart';
import '../../../assessments/presentation/bloc/assessments_list_cubit.dart';
import '../../../assessments/presentation/widgets/assessments_tab.dart';
import '../../../attendance/domain/usecases/attendance_usecases.dart';
import '../../../attendance/presentation/bloc/attendance_tab_cubit.dart';
import '../../../attendance/presentation/widgets/attendance_tab.dart';
import '../bloc/teacher_course_detail_cubit.dart';
import '../widgets/course_details_tab.dart';
import '../widgets/division_selector.dart';
import '../widgets/learning_plan_tab.dart';

/// Port of `src/pages/teacher/courses/detail/layout.tsx`.
///
/// Seven tabs over one course, all scoped to a single division chosen once at
/// the top. The web's layout renders no course identity above the tabs; a phone
/// app bar needs a title, so it takes the course name with the code beneath.
class TeacherCourseDetailPage extends StatefulWidget {
  const TeacherCourseDetailPage({super.key, required this.courseId});

  final String courseId;

  @override
  State<TeacherCourseDetailPage> createState() =>
      _TeacherCourseDetailPageState();
}

class _TeacherCourseDetailPageState extends State<TeacherCourseDetailPage> {
  /// Labels and order are the web's `TABS` array, verbatim. Analytics is last
  /// and locked.
  static const _tabs = <_DetailTab>[
    _DetailTab('Course Details'),
    _DetailTab('Learning Plan'),
    _DetailTab('Enrollments'),
    _DetailTab('Assignments'),
    _DetailTab('Quiz'),
    _DetailTab('Attendance'),
    _DetailTab('Analytics', locked: true),
  ];

  @override
  void initState() {
    super.initState();
    context.read<TeacherCourseDetailCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherCourseDetailCubit>();

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AdaptiveAppBar(
          // The web's layout shows no course identity at all; a phone app bar
          // needs one, and the code is already on the Details tab.
          title: _title(context),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // The locked tab is rendered but not selectable, matching the web,
            // where Analytics is a plain div rather than a link.
            onTap: (index) {
              if (!_tabs[index].locked) return;
              final controller = DefaultTabController.of(context);
              controller.index = controller.previousIndex;
              AppToast.warning(
                context,
                'Course analytics are coming soon.',
              );
            },
            tabs: [
              for (final tab in _tabs)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tab.label),
                      if (tab.locked) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: context.scheme.mutedForeground,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: RemoteView<TeacherCourseDetailCubit, TeacherCourseDetailData>(
            onRetry: cubit.load,
            loading: const Padding(
              padding: EdgeInsets.all(16),
              child: AppListSkeleton(rows: 4, lines: 3),
            ),
            builder: (context, data) => Column(
              children: [
                // One selector for the whole screen — every tab below reads the
                // division it resolves, exactly as the web's one <Select> feeds
                // all seven through context.
                if (data.showDivisionPicker)
                  DivisionSelector(
                    divisions: data.divisions,
                    selected: data.divisionId,
                    onChanged: cubit.selectDivision,
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      CourseDetailsTab(tree: data.tree),
                      LearningPlanTab(
                        tree: data.tree,
                        courseId: widget.courseId,
                        divisionId: data.divisionId,
                      ),
                      BlocProvider(
                        create: (_) => EnrollmentsCubit(
                          enrollments: sl<EnrollmentUseCases>(),
                          courseId: widget.courseId,
                        ),
                        child: const EnrollmentsTab(),
                      ),
                      BlocProvider(
                        // Keyed by section: both tabs read one section's
                        // assessments, so switching divisions must refetch.
                        key: ValueKey('assignments:${data.divisionId}'),
                        create: (_) => AssessmentsListCubit(
                          assessments: sl<TeacherAssessmentUseCases>(),
                          courseId: widget.courseId,
                          divisionId: data.divisionId,
                          quizzes: false,
                        ),
                        child: const AssessmentsTab(),
                      ),
                      BlocProvider(
                        // Keyed by section: both tabs read one section's
                        // assessments, so switching divisions must refetch.
                        key: ValueKey('quiz:${data.divisionId}'),
                        create: (_) => AssessmentsListCubit(
                          assessments: sl<TeacherAssessmentUseCases>(),
                          courseId: widget.courseId,
                          divisionId: data.divisionId,
                          quizzes: true,
                        ),
                        child: const AssessmentsTab(),
                      ),
                      BlocProvider(
                        // Keyed by section: switching divisions must rebuild
                        // the cubit, since the sessions and the rollup are
                        // both scoped to one.
                        key: ValueKey(data.divisionId),
                        create: (_) => AttendanceTabCubit(
                          attendance: sl<AttendanceUseCases>(),
                          courseId: widget.courseId,
                          divisionId: data.divisionId,
                        ),
                        child: const AttendanceTab(),
                      ),
                      const _PendingTab(
                        label: 'Analytics',
                        icon: Icons.insights_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context) =>
      context.select((TeacherCourseDetailCubit c) => c.state.data?.tree.name) ??
      'Course';
}

class _DetailTab {
  const _DetailTab(this.label, {this.locked = false});

  final String label;

  /// Visible but not selectable — the web shows Analytics greyed with a padlock.
  final bool locked;
}

/// A tab whose screen lands in a later stage of this pass.
class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppEmptyState(
        icon: icon,
        title: label,
        description: '$label is next up in the tab-by-tab build.',
      );
}
