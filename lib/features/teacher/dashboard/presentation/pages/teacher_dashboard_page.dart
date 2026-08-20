import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../../shared/notifications/presentation/bloc/notifications_cubit.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../domain/entities/teacher_dashboard.dart';
import '../bloc/teacher_dashboard_cubit.dart';
import '../widgets/activity_feed_card.dart';
import '../widgets/my_courses_grid.dart';
import '../widgets/today_sessions_timeline.dart';

/// Port of `src/pages/teacher/dashboard/index.tsx` — the teacher dashboard.
///
/// Stacks the three stat cards, today's timetable, the activity feed, and the
/// assigned-course list, in that order. The web renders sessions and activity
/// side by side in a two-column grid; stacked, that puts them one after another.
class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<TeacherDashboardCubit>().load();
    // Its own request, so it starts alongside rather than after the dashboard.
    context.read<NotificationsCubit>().load();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<TeacherDashboardCubit>().load(refresh: true),
      context.read<NotificationsCubit>().load(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherDashboardCubit>();
    final auth = context.watch<AuthBloc>().state;

    // The shell owns the app bar; this contributes body only.
    return ShellScaffold(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: RemoteView<TeacherDashboardCubit, TeacherDashboard>(
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsets.all(16),
            child: AppListSkeleton(rows: 4, lines: 3),
          ),
          builder: (context, data) => RefreshableScroll(
            onRefresh: _refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WelcomeHeader(name: auth.user?.displayName),
                const SizedBox(height: 14),

                // Port of `StatCards`.
                AppStatGrid(
                  tiles: [
                    AppStatTile(
                      label: 'Courses',
                      value: Fmt.number(data.stats.coursesCount),
                      caption: 'Assigned to you',
                      icon: Icons.menu_book_outlined,
                      shade: TwColors.blue,
                    ),
                    AppStatTile(
                      label: 'Students',
                      value: Fmt.number(data.stats.studentsCount),
                      caption: 'Across your divisions',
                      icon: Icons.groups_outlined,
                      shade: TwColors.emerald,
                    ),
                    AppStatTile(
                      label: 'Topics',
                      value: Fmt.number(data.stats.topicsCount),
                      caption: 'Across your courses',
                      icon: Icons.checklist_rounded,
                      shade: TwColors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TodaySessionsTimeline(sessions: data.todaySessions),
                const SizedBox(height: 12),

                const ActivityFeedCard(),
                const SizedBox(height: 12),

                MyCoursesGrid(courses: data.myCourses),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The greeting line. The web app has a `WelcomeBanner` component for this, but
/// it is dead code there — unreferenced, and carrying hardcoded counts — so
/// this is the plain greeting the rest of the app uses instead.
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null ? greeting : '$greeting, $name',
            style: theme.textTheme.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            "Here's what's happening across your classes today.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}
