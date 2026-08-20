import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/teacher_course.dart';
import '../../domain/entities/teacher_course_tree.dart';

/// Port of `.../detail/course-details/index.tsx`.
///
/// Pure render of the already-loaded tree — it makes no request of its own.
class CourseDetailsTab extends StatelessWidget {
  const CourseDetailsTab({super.key, required this.tree});

  final TeacherCourseTree tree;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _IdentityCard(tree: tree),
        const SizedBox(height: 12),
        AppStatGrid(
          tiles: [
            AppStatTile(
              label: 'Credits',
              value: '${tree.credits}',
              icon: Icons.workspace_premium_outlined,
              shade: TwColors.amber,
            ),
            AppStatTile(
              label: 'Type',
              value: CourseType.label(tree.type),
              icon: Icons.category_outlined,
              shade: TwColors.violet,
            ),
            AppStatTile(
              label: 'Modules',
              value: Fmt.number(tree.modules.length),
              icon: Icons.menu_book_outlined,
              shade: TwColors.blue,
            ),
            AppStatTile(
              label: 'Topics',
              value: Fmt.number(tree.totalTopics),
              icon: Icons.list_alt_outlined,
              shade: TwColors.teal,
            ),
            AppStatTile(
              label: 'Materials',
              value: Fmt.number(tree.totalMaterials),
              icon: Icons.description_outlined,
              shade: TwColors.rose,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Instructors(instructors: tree.instructors),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'Description',
          icon: Icons.notes_rounded,
          child: (tree.description ?? '').isEmpty
              ? Text(
                  'No description provided for this course.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.scheme.mutedForeground,
                        fontStyle: FontStyle.italic,
                      ),
                )
              : AppMarkdown(tree.description),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.tree});

  final TeacherCourseTree tree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = parseHexColor(tree.colorCode) ?? context.scheme.primary;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tree.name,
            style: theme.textTheme.headlineSmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Text(
                  tree.code,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              AppBadge(
                CourseStatus.label(tree.status),
                shade: CourseStatus.shade(tree.status),
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every instructor on the course.
///
/// These span **all** divisions, not the selected section — the endpoint
/// returns the whole teaching team, which is what the web shows too.
class _Instructors extends StatelessWidget {
  const _Instructors({required this.instructors});

  final List<CourseInstructor> instructors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppSectionCard(
      title: 'Instructors',
      icon: Icons.school_outlined,
      child: instructors.isEmpty
          ? Text(
              'No teacher assigned yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.mutedForeground,
                fontStyle: FontStyle.italic,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < instructors.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _InstructorRow(instructor: instructors[i]),
                ],
              ],
            ),
    );
  }
}

class _InstructorRow extends StatelessWidget {
  const _InstructorRow({required this.instructor});

  final CourseInstructor instructor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = instructor.subtitle;

    return Row(
      children: [
        AppAvatar(
          imageUrl: instructor.avatar,
          name: instructor.fullName,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructor.fullName,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (instructor.division != null) ...[
          const SizedBox(width: 8),
          AppBadge(instructor.division!.label, dense: true),
        ],
      ],
    );
  }
}
