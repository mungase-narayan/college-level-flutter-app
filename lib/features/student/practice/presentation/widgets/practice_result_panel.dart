import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/markdown/code_block.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';

/// The banner and breakdown shown after submitting.
class PracticeResultPanel extends StatelessWidget {
  const PracticeResultPanel({
    super.key,
    required this.attempt,
    required this.question,
    required this.onClose,
    this.onRetry,
  });

  final PracticeAttempt attempt;

  /// The question as the submit response returned it — with the answer key.
  final PracticeQuestion question;

  /// Null when another attempt is not on offer — reviewing a day whose window
  /// has closed, for instance.
  final VoidCallback? onRetry;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final (shade, icon, headline) = switch (attempt.verdict) {
      // A coding answer lands here too when the runner was unavailable — the
      // work is saved and waiting, which is not the same as being wrong.
      PracticeVerdict.pending => (
          TwColors.amber,
          Icons.hourglass_top_rounded,
          'Submitted — awaiting review',
        ),
      PracticeVerdict.correct => (
          TwColors.emerald,
          Icons.check_circle_rounded,
          'Correct!',
        ),
      PracticeVerdict.wrong => (
          TwColors.rose,
          Icons.cancel_rounded,
          'Not quite — review the solution below',
        ),
    };
    final tone = tokens.tone(shade);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tone.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tone.foreground,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                tooltip: 'Close result',
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Withheld while pending: there is no score yet, and showing 0
              // would read as a grade.
              if (!attempt.isPending && attempt.score != null)
                AppBadge(
                  'Score ${attempt.score}/${attempt.maxScore ?? question.points}',
                  shade: shade,
                  dense: true,
                ),
              if (attempt.pointsAwarded > 0)
                AppBadge(
                  '+${attempt.pointsAwarded} pts',
                  shade: TwColors.violet,
                  dense: true,
                ),
              AppBadge('Attempt #${attempt.attempt}', dense: true),
            ],
          ),
          // The answer key, which is the point of showing a result at all: the
          // student needs to see which option was right and which they picked,
          // not just that they were wrong.
          if (question.isObjective) ...[
            const SizedBox(height: 12),
            _AnswerKey(question: question, selected: attempt.selectedAnswers),
          ],
          if (attempt.codingResult != null) ...[
            const SizedBox(height: 12),
            PracticeCodingResultView(result: attempt.codingResult!),
          ],
          if ((attempt.answerText ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Your answer', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(attempt.answerText!, style: theme.textTheme.bodyMedium),
          ],
          if ((question.modelAnswer ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Model answer', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            AppMarkdown(question.modelAnswer),
          ],
          if ((question.explanation ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Explanation', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            AppMarkdown(question.explanation),
          ],
          if ((attempt.feedback ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Teacher feedback', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            AppMarkdown(attempt.feedback),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The per-test-case breakdown of a code run or a submitted coding attempt.
class PracticeCodingResultView extends StatelessWidget {
  const PracticeCodingResultView({
    super.key,
    required this.result,
    this.summaryOnly = false,
  });

  final PracticeCodingResult result;

  /// Hides the per-case list — used where space is tight, such as a history row.
  final bool summaryOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final passedAll = result.allPassed && result.total > 0;
    final tone = tokens.tone(passedAll ? TwColors.emerald : TwColors.rose);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              passedAll ? Icons.verified_rounded : Icons.error_outline_rounded,
              size: 17,
              color: tone.foreground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.compileError
                    ? 'Compilation error'
                    : '${result.passed} / ${result.total} test cases passed',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tone.foreground,
                ),
              ),
            ),
          ],
        ),
        if ((result.failureReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(result.failureReason!, style: theme.textTheme.labelSmall),
        ],
        if (!summaryOnly)
          for (final (index, testCase) in result.cases.indexed) ...[
            const SizedBox(height: 8),
            _CaseTile(index: index + 1, result: testCase),
          ],
      ],
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.index, required this.result});

  final int index;
  final PracticeCaseResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final tone =
        tokens.tone(result.passed ? TwColors.emerald : TwColors.rose);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                result.passed
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 15,
                color: tone.foreground,
              ),
              const SizedBox(width: 6),
              Text(
                // A hidden case is named but never shown: its input is the
                // whole point of it being hidden.
                result.isSample ? 'Sample case $index' : 'Hidden case $index',
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              Text(result.status, style: theme.textTheme.labelSmall),
            ],
          ),
          if (result.isSample) ...[
            if ((result.stdin ?? '').isNotEmpty)
              _IoBlock(label: 'Input', value: result.stdin!),
            if ((result.expectedOutput ?? '').isNotEmpty)
              _IoBlock(label: 'Expected', value: result.expectedOutput!),
            if ((result.stdout ?? '').isNotEmpty)
              _IoBlock(label: 'Your output', value: result.stdout!),
            if ((result.stderr ?? '').isNotEmpty)
              _IoBlock(label: 'Errors', value: result.stderr!),
          ],
          if (result.timeSec != null || result.memoryKb != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (result.timeSec != null)
                  '${(result.timeSec! * 1000).round()} ms',
                if (result.memoryKb != null)
                  '${(result.memoryKb! / 1024).toStringAsFixed(1)} MB',
              ].join(' · '),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _IoBlock extends StatelessWidget {
  const _IoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: scheme.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the Submissions tab.
class PracticeAttemptTile extends StatefulWidget {
  const PracticeAttemptTile({super.key, required this.attempt});

  final PracticeAttempt attempt;

  @override
  State<PracticeAttemptTile> createState() => _PracticeAttemptTileState();
}

class _PracticeAttemptTileState extends State<PracticeAttemptTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final attempt = widget.attempt;

    final (shade, label) = switch (attempt.verdict) {
      PracticeVerdict.pending => (TwColors.amber, 'Pending review'),
      PracticeVerdict.correct => (TwColors.emerald, 'Correct'),
      PracticeVerdict.wrong => (TwColors.rose, 'Incorrect'),
    };
    final hasCode = (attempt.code ?? '').trim().isNotEmpty;

    return AppCard(
      onTap: hasCode ? () => setState(() => _expanded = !_expanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppBadge('#${attempt.attempt}', dense: true),
              const SizedBox(width: 6),
              AppBadge(label, shade: shade, dense: true),
              const Spacer(),
              if (!attempt.isPending && attempt.score != null)
                Text(
                  '${attempt.score}/${attempt.maxScore ?? 0}',
                  style: theme.textTheme.labelMedium,
                ),
              if (attempt.pointsAwarded > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '+${attempt.pointsAwarded}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.tone(TwColors.violet).foreground,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                Fmt.relative(attempt.submittedAt),
                style: theme.textTheme.labelSmall,
              ),
              if ((attempt.language ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  attempt.language!.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
              ],
              if (attempt.timeTakenSec != null) ...[
                const SizedBox(width: 8),
                Text(
                  Fmt.duration(attempt.timeTakenSec!),
                  style: theme.textTheme.labelSmall,
                ),
              ],
              const Spacer(),
              if (hasCode)
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: context.scheme.mutedForeground,
                ),
            ],
          ),
          if (_expanded && hasCode) ...[
            const SizedBox(height: 10),
            MarkdownCodeBlock(
              code: attempt.code!,
              language: attempt.language,
            ),
            if (attempt.codingResult != null) ...[
              const SizedBox(height: 10),
              PracticeCodingResultView(
                result: attempt.codingResult!,
                summaryOnly: true,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Which option was right, and which the student picked.
class _AnswerKey extends StatelessWidget {
  const _AnswerKey({required this.question, required this.selected});

  final PracticeQuestion question;
  final List<String> selected;

  /// A true/false question often ships without options of its own.
  List<QuestionOption> get _options => question.options.isNotEmpty
      ? question.options
      : const [
          QuestionOption(id: 'true', text: 'True'),
          QuestionOption(id: 'false', text: 'False'),
        ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;
    final correct = question.answers ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, option) in _options.indexed)
          Builder(
            builder: (context) {
              final isCorrect = correct.contains(option.id);
              final wasPicked = selected.contains(option.id);
              final tone = isCorrect
                  ? tokens.tone(TwColors.emerald)
                  : wasPicked
                      ? tokens.tone(TwColors.rose)
                      : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tone?.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: tone?.foreground.withValues(alpha: 0.4) ??
                        scheme.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : wasPicked
                              ? Icons.cancel_rounded
                              : Icons.circle_outlined,
                      size: 18,
                      color: tone?.foreground ?? scheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${String.fromCharCode(65 + index)}.',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: InlineMarkdown(option.text)),
                    if (isCorrect || wasPicked) ...[
                      const SizedBox(width: 8),
                      Text(
                        isCorrect && wasPicked
                            ? 'Correct · your pick'
                            : isCorrect
                                ? 'Correct answer'
                                : 'Your pick',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tone?.foreground,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        // The key only arrives with a review payload; without it every row
        // would silently read as wrong.
        if (correct.isEmpty)
          Text(
            'The answer key is not available for this question.',
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}
