import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/injection_modules/service_locator.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/course_tree.dart';
import '../bloc/course_tabs_cubit.dart';
import '../bloc/courses_cubit.dart';
import '../widgets/course_assessments_tab.dart';
import '../widgets/course_attendance_tab.dart';
import '../widgets/learning_plan_tree.dart';

/// Port of `student/courses/detail/*`.
///
/// The web version is a tab bar across Course Details / Learning Plan /
/// Assignments / Quiz / Attendance. On mobile the same tabs sit in a
/// [TabBar]; Assignments, Quiz, and Attendance are course-scoped views of
/// features built in later passes and currently link out to their
/// cross-course equivalents.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<CourseTreeCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourseTreeCubit>();

    // The five tabs of `StudentCourseDetailLayout`, in the order requested:
    // Details · Learning Plan · Attendance · Assignments · Quiz.
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: const AdaptiveAppBar(
          title: 'Course',
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Learning Plan'),
              Tab(text: 'Attendance'),
              Tab(text: 'Assignments'),
              Tab(text: 'Quiz'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Details and Learning Plan share the one course tree, fetched
              // once by CourseTreeCubit — the React layout does the same and
              // passes it down through the outlet context.
              RemoteView<CourseTreeCubit, CourseTree>(
                onRetry: cubit.load,
                loading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppListSkeleton(rows: 4),
                ),
                builder: (context, tree) => _DetailsTab(
                  tree: tree,
                  onRefresh: () => cubit.load(refresh: true),
                ),
              ),
              RemoteView<CourseTreeCubit, CourseTree>(
                onRetry: cubit.load,
                loading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppListSkeleton(rows: 4),
                ),
                builder: (context, tree) => LearningPlanTree(
                  tree: tree,
                  onRefresh: () => cubit.load(refresh: true),
                  onToggleMaterial: cubit.toggleMaterial,
                ),
              ),

              // These three fetch their own data, each lazily on first build.
              BlocProvider(
                create: (_) => CourseAttendanceCubit(
                  getAnalytics: sl(),
                  listSessions: sl(),
                  courseId: widget.courseId,
                ),
                child: const CourseAttendanceTab(),
              ),
              BlocProvider(
                create: (_) => CourseAssessmentsCubit(
                  listAssessments: sl(),
                  courseId: widget.courseId,
                  // No category → the backend excludes quizzes.
                  category: null,
                ),
                child: const CourseAssessmentsTab(kind: 'Assignment'),
              ),
              BlocProvider(
                create: (_) => CourseAssessmentsCubit(
                  listAssessments: sl(),
                  courseId: widget.courseId,
                  category: 'quiz',
                ),
                child: const CourseAssessmentsTab(kind: 'Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Port of `course-details/index.tsx` — metadata plus the counts of modules,
/// topics, and materials, and the overall completion bar.
class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.tree, required this.onRefresh});

  final CourseTree tree;
  final Future<void> Function() onRefresh;

  /// `regular` → `Regular`, `open_elective` → `Open elective`.
  String _typeLabel(String? type) {
    final raw = (type ?? '').replaceAll('_', ' ').trim();
    if (raw.isEmpty) return '—';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshableScroll(
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tree.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(tree.code, style: theme.textTheme.labelSmall),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: tree.progress.fraction,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${tree.progress.percentValue}%',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${tree.progress.completedMaterials} of '
                  '${tree.progress.totalMaterials} materials completed',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppStatGrid(
            columns: 3,
            tiles: [
              AppStatTile(label: 'Modules', value: '${tree.modules.length}'),
              AppStatTile(label: 'Topics', value: '${tree.totalTopics}'),
              AppStatTile(
                label: 'Materials',
                value: '${tree.progress.totalMaterials}',
              ),
            ],
          ),
          if ((tree.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'About this course',
              icon: Icons.info_outline_rounded,
              child: AppMarkdown(tree.description),
            ),
          ],
          // Credits and Type as a two-card row, matching the stat cards above.
          // Completion is deliberately not repeated here — the progress bar at
          // the top of this tab already states it.
          const SizedBox(height: 12),
          AppStatGrid(
            tiles: [
              AppStatTile(
                label: 'Credits',
                value: '${tree.credits ?? 0}',
                icon: Icons.workspace_premium_outlined,
                shade: TwColors.amber,
              ),
              AppStatTile(
                label: 'Type',
                value: _typeLabel(tree.type),
                icon: Icons.category_outlined,
                shade: TwColors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
