import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../shared/shell/presentation/widgets/teacher_nav.dart';
import '../../domain/entities/teacher_dashboard.dart';

/// Port of `src/pages/teacher/dashboard/components/my-courses.tsx`.
///
/// One card per **(course, division)** assignment — the same course appears
/// once per section the teacher takes it for, which is why rows are keyed by
/// [TeacherCourseSummary.key] rather than by course id.
class MyCoursesGrid extends StatelessWidget {
  const MyCoursesGrid({super.key, required this.courses});

  final List<TeacherCourseSummary> courses;

  /// Fallback accents, cycled by position, for courses the school never gave a
  /// colour. The web app cycles this palette for *every* card and ignores the
  /// `colorCode` it fetched; here it is only the fallback.
  static const _palette = <TwShade>[
    TwColors.blue,
    TwColors.emerald,
    TwColors.violet,
    TwColors.amber,
    TwColors.rose,
    TwColors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'My Courses',
      subtitle: 'Your assigned courses this semester',
      icon: Icons.menu_book_rounded,
      child: courses.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppEmptyState(
                title: 'No courses assigned yet',
                icon: Icons.menu_book_outlined,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < courses.length; i++)
                  StaggeredEntrance(
                    index: i,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == courses.length - 1 ? 0 : 10,
                      ),
                      child: _CourseCard(
                        course: courses[i],
                        fallback: _palette[i % _palette.length],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.fallback});

  final TeacherCourseSummary course;
  final TwShade fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(fallback);

    // The school's own colour wins; the cycled palette is only the fallback.
    final accent = parseHexColor(course.colorCode) ?? tone.foreground;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(TeacherRoutes.course(course.courseId)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.menu_book_rounded, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        course.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        course.code,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (course.divisionOrNull != null)
                      'Division ${course.divisionOrNull}',
                    '${course.students} students',
                    '${course.totalTopics} topics',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
