import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/teacher_assessment.dart';

/// One assessment in the list — the web's mobile card, ported.
class AssessmentCard extends StatelessWidget {
  const AssessmentCard({
    super.key,
    required this.assessment,
    required this.number,
    required this.onTap,
    required this.onActions,
  });

  final TeacherAssessment assessment;

  /// Running position across pages, so row 11 reads "11" and not "1".
  final int number;
  final VoidCallback onTap;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '#$number',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assessment.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Actions',
                onPressed: onActions,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(
                AssessmentCategory.label(assessment.category),
                shade: AssessmentCategory.shade(assessment.category),
                dense: true,
              ),
              AppBadge(
                AssessmentType.label(assessment.type),
                shade: AssessmentType.shade(assessment.type),
                dense: true,
              ),
              AppBadge(
                AssessmentStatus.label(assessment.status),
                shade: AssessmentStatus.shade(assessment.status),
                dense: true,
              ),
              if (assessment.resultsPublished)
                const AppBadge('Results published', dense: true),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Meta(
                    label: 'Opens',
                    value: Fmt.dateTime(assessment.startDate),
                  ),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Due',
                    value: Fmt.dateTime(assessment.endDate),
                  ),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Marks',
                    value: '${assessment.totalMarks}',
                    // The pass mark is genuinely optional, so it only appears
                    // when one is set rather than showing a bare slash.
                    caption: assessment.passingMarks == null
                        ? null
                        : 'pass ${assessment.passingMarks}',
                  ),
                ),
              ],
            ),
          ),
        ],
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
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.foreground,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null)
          Text(caption!, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
