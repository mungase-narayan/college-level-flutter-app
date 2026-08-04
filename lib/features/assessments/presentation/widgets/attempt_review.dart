import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/assessment_detail.dart';
import '../../domain/entities/student_assessment.dart';

/// Port of `attempt/view/index.tsx` — the post-submission review.
///
/// The answer key (correct options, explanation, model answer) and per-question
/// grading only exist once the teacher publishes results; before that this
/// shows the student's own answers and says results are pending, which is
/// exactly what the server sends.
class AttemptReview extends StatelessWidget {
  const AttemptReview({super.key, required this.detail, required this.kind});

  final AssessmentDetail detail;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final assessment = detail.assessment;
    final submission = detail.submission;
    final published = detail.resultsPublished;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // ── Summary ───────────────────────────────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assessment.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (published && submission?.totalScore != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${submission!.totalScore}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tokens.success.foreground,
                      ),
                    ),
                    Text(
                      ' / ${submission.maxScore ?? assessment.totalMarks}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                )
              else
                _PendingBanner(
                  isSubmitted: submission?.status == AssessmentStatus.submitted,
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppBadge.status(
                    submission?.status ?? AssessmentStatus.submitted,
                    dense: true,
                  ),
                  if (submission != null)
                    AppBadge('Attempt ${submission.attempt}', dense: true),
                  if (submission?.isLate ?? false)
                    AppBadge('Late', shade: TwColors.amber, dense: true),
                  if (submission?.autoSubmitted ?? false)
                    AppBadge('Auto-submitted', shade: TwColors.rose, dense: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        AppCard(
          child: Column(
            children: [
              AppDetailRow(
                label: 'Submitted',
                value: Fmt.dateTime(submission?.submittedAt),
              ),
              if (submission != null && submission.timeSpentSeconds > 0)
                AppDetailRow(
                  label: 'Time taken',
                  value: Fmt.duration(submission.timeSpentSeconds),
                ),
              AppDetailRow(
                label: 'Total marks',
                value: '${assessment.totalMarks}',
              ),
            ],
          ),
        ),

        if ((submission?.feedback ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Teacher feedback',
            icon: Icons.comment_outlined,
            child: Text(
              submission!.feedback!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],

        // ── Per-question review ───────────────────────────────────────────
        if (detail.questions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Your answers', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          for (var i = 0; i < detail.questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestionReviewCard(
                index: i + 1,
                question: detail.questions[i],
                answer:
                    detail.answerFor(detail.questions[i].assessmentQuestionId),
                resultsPublished: published,
              ),
            ),
        ] else if ((submission?.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          AppSectionCard(
            title: 'Your submission',
            icon: Icons.description_outlined,
            child: Text(submission!.note!, style: theme.textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.isSubmitted});

  final bool isSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 17, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSubmitted
                  ? 'Submitted — awaiting evaluation.'
                  : 'Evaluated, but results are not published yet.',
              style: theme.textTheme.bodySmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.resultsPublished,
  });

  final int index;
  final AssessmentQuestion question;
  final QuestionAnswer? answer;
  final bool resultsPublished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final correct = answer?.isCorrect;
    final tone = correct == null
        ? tokens.neutral
        : (correct ? tokens.success : tokens.danger);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: tone.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(question.title, style: theme.textTheme.titleSmall),
              ),
              if (resultsPublished && answer?.score != null)
                Text(
                  '${answer!.score}/${answer!.maxScore ?? question.points}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tone.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if ((question.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            AppMarkdown(question.description),
          ],
          const SizedBox(height: 12),

          // Options, marking the student's pick and (once published) the key.
          if (question.isObjective && question.options.isNotEmpty)
            for (final option in question.options)
              _OptionRow(
                option: option,
                isChosen: answer?.selectedAnswers.contains(option.id) ?? false,
                isCorrect: resultsPublished
                    ? question.correctAnswers?.contains(option.id)
                    : null,
              )
          else ...[
            Text('Your answer', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                answer?.code?.trim().isNotEmpty ?? false
                    ? answer!.code!
                    : (answer?.answerText?.trim().isNotEmpty ?? false)
                        ? answer!.answerText!
                        : 'Not answered',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: question.type == 'coding' ? AppTheme.mono : null,
                ),
              ),
            ),
          ],

          if (resultsPublished && (question.explanation ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Explanation', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            AppMarkdown(question.explanation),
          ],
          if ((answer?.feedback ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Feedback', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(answer!.feedback!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isChosen,
    required this.isCorrect,
  });

  final AnswerOption option;
  final bool isChosen;

  /// Null while results are unpublished — the key is withheld then.
  final bool? isCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final tone = switch (isCorrect) {
      true => tokens.success,
      false when isChosen => tokens.danger,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: tone?.background ?? (isChosen ? scheme.muted : Colors.transparent),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: tone?.foreground.withValues(alpha: 0.4) ?? scheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isChosen
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: tone?.foreground ?? scheme.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(option.text, style: theme.textTheme.bodySmall),
            ),
            if (isCorrect == true)
              Icon(Icons.check_rounded, size: 16, color: tokens.success.foreground),
          ],
        ),
      ),
    );
  }
}
