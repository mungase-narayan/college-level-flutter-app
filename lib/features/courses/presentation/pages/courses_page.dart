import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/course.dart';
import '../bloc/courses_cubit.dart';

/// Port of `src/pages/student/courses/index.tsx`.
///
/// The desktop version is a filter bar above a table; on mobile the table
/// becomes a card list and the semester `<Select>` becomes a chip row.
class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  @override
  void initState() {
    super.initState();
    context.read<CoursesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CoursesCubit>();
    // Only the bottom is reserved now: the sliver header occupies real scroll
    // space, so the list rises to fill it rather than being padded clear of it.
    // Zero off iOS.
    final glassInsets = context.glassContentInsets;

    // The shell owns the app bar; this contributes body only.
    return StudentScaffold(
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: AppSearchField(
                hint: 'Search by name, code, or department',
                onChanged: cubit.setSearch,
              ),
            ),
            // The semester options are derived from the loaded data, so this
            // only appears once there is something to filter.
            BlocBuilder<CoursesCubit, RemoteState<List<CourseEnrollment>>>(
              builder: (context, state) {
                final semesters = cubit.semesters;
                if (semesters.length < 2) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 10),
                  child: AppFilterChips<String?>(
                    selected: cubit.semesterId,
                    onSelected: cubit.setSemester,
                    options: [
                      const AppFilterChipOption(value: null, label: 'All semesters'),
                      for (final semester in semesters)
                        AppFilterChipOption(
                          value: semester.id,
                          label: semester.label,
                        ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cubit.load(refresh: true),
                child: RemoteView<CoursesCubit, List<CourseEnrollment>>(
                  onRetry: cubit.load,
                  loading: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppListSkeleton(rows: 4, lines: 2),
                  ),
                  isEmpty: (courses) => courses.isEmpty,
                  emptyTitle: 'No courses found',
                  emptyDescription:
                      'Nothing matches your filters, or you have no enrollments yet.',
                  emptyIcon: Icons.menu_book_outlined,
                  builder: (context, courses) => ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Bottom clearance for the floating nav capsule on iOS; a
                    // no-op on Android.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + glassInsets.bottom,
                    ),
                    itemCount: courses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _CourseCard(enrollment: courses[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.enrollment});

  final CourseEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final course = enrollment.course;

    return AppCard(
      onTap: () => context.push('/student/courses/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The course's own colour, falling back to the brand violet.
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: _colorOf(course.colorCode) ?? scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(course.code, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              AppBadge.status(enrollment.status, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(course.typeLabel, dense: true),
              AppBadge('${course.credits} credits', dense: true),
              if (course.semester != null)
                AppBadge(course.semester!.label, dense: true),
              if (course.division != null)
                AppBadge('Div ${course.division!.name}', dense: true),
            ],
          ),
          if (course.instructor?.name?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AppAvatar(
                  imageUrl: course.instructor!.avatar,
                  name: course.instructor!.name,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.instructor!.name!,
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: scheme.mutedForeground),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Parses `#rrggbb` from `colorCode`; null when unset or malformed.
  Color? _colorOf(String? hex) => parseHexColor(hex);
}
