import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/teacher_course.dart';

/// One course in the teacher's list — the web's mobile card, ported.
///
/// Represents a whole [TeacherCourseGroup], not a single assignment: the meta
/// row reads "3 sections" when the teacher takes several divisions of it.
class TeacherCourseCard extends StatelessWidget {
  const TeacherCourseCard({super.key, required this.group, required this.onTap});

  final TeacherCourseGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final course = group.course;

    // The school's own colour, falling back to the primary tint.
    final accent = parseHexColor(course.colorCode) ?? scheme.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  course.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CodeChip(code: course.code, accent: accent),
              AppBadge(CourseType.label(course.type), dense: true),
              AppBadge(
                CourseStatus.label(course.status),
                shade: CourseStatus.shade(course.status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  label: 'Division / Dept',
                  value: [
                    group.sectionLabel,
                    if (course.department != null) course.department!.code,
                  ].join(' / '),
                ),
              ),
              Expanded(
                child: _Meta(
                  label: 'Credits',
                  value: '${course.credits}',
                ),
              ),
              Expanded(
                child: _Meta(
                  label: 'Semester',
                  value: course.semester == null
                      ? '—'
                      : 'Sem ${course.semester!.code}',
                  // The web marks the running semester with a green chip; a
                  // caption line is the phone-sized version of the same signal.
                  caption:
                      (course.semester?.isCurrent ?? false) ? 'Current' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The mono code badge, tinted from the course's own colour.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, required this.accent});

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.foreground, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: context.tokens.tone(TwColors.emerald).foreground),
          ),
      ],
    );
  }
}
