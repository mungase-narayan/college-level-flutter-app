import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/submission.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../bloc/submission_review_cubit.dart';

/// Port of `answer-block.tsx` — one question, the student's answer next to the
/// correct one, and the grading controls.
class AnswerBlock extends StatefulWidget {
  const AnswerBlock({
    super.key,
    required this.answer,
    required this.index,
    required this.mark,
    required this.readOnly,
    required this.onScore,
    required this.onFeedback,
    required this.onCorrect,
    required this.onWrong,
  });

  final SubmissionAnswer answer;
  final int index;
  final AnswerMark mark;

  /// In-progress attempts are view-only: every grading control is dropped.
  final bool readOnly;

  final ValueChanged<String> onScore;
  final ValueChanged<String> onFeedback;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  @override
  State<AnswerBlock> createState() => _AnswerBlockState();
}

class _AnswerBlockState extends State<AnswerBlock> {
  late final CodeLineEditingController _code;
  late final TextEditingController _score;
  late final TextEditingController _feedback;

  @override
  void initState() {
    super.initState();
    _code = CodeLineEditingController.fromText(widget.answer.code ?? '');
    _score = TextEditingController(text: widget.mark.score);
    _feedback = TextEditingController(text: widget.mark.feedback);
  }

  @override
  void didUpdateWidget(AnswerBlock old) {
    super.didUpdateWidget(old);
    // The two shortcut buttons write the score from outside, so the field has
    // to follow — but only when it actually changed, or typing would fight it.
    if (widget.mark.score != _score.text) _score.text = widget.mark.score;
  }

  @override
  void dispose() {
    _code.dispose();
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answer = widget.answer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${widget.index + 1}. ${answer.questionTitle}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            AppBadge(QuestionType.label(answer.questionType), dense: true),
          ],
        ),
        const SizedBox(height: 12),
        if (answer.isChoice)
          _Options(answer: answer)
        else if (answer.questionType == QuestionType.subjective)
          _Subjective(answer: answer)
        else if (answer.questionType == QuestionType.coding)
          _Coding(answer: answer, controller: _code)
        else
          _Written(text: answer.answerText),
        if (answer.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final fileId in answer.attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AttachmentTile(fileId: fileId),
            ),
        ],
        if ((answer.studentNote ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Callout(label: 'Student note', text: answer.studentNote!),
        ],
        if (!widget.readOnly) ...[
          const SizedBox(height: 14),
          _Grading(
            answer: answer,
            mark: widget.mark,
            score: _score,
            feedback: _feedback,
            onScore: widget.onScore,
            onFeedback: widget.onFeedback,
            onCorrect: widget.onCorrect,
            onWrong: widget.onWrong,
          ),
        ],
      ],
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.answer});

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tokens = context.tokens;
    final correctTone = tokens.tone(TwColors.emerald);
    final wrongTone = tokens.tone(TwColors.rose);

    return Column(
      children: [
        for (final option in answer.questionOptions)
          Builder(
            builder: (context) {
              final picked = answer.selectedAnswers.contains(option.id);
              final correct = answer.questionAnswers.contains(option.id);
              // Correct wins over picked, so the right answer always reads as
              // right even when the student also chose it.
              final tone = correct
                  ? correctTone
                  : picked
                      ? wrongTone
                      : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tone?.background,
                  border: Border.all(
                    color: tone == null
                        ? scheme.border
                        : tone.foreground.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : picked
                              ? Icons.cancel_rounded
                              : Icons.circle_outlined,
                      size: 15,
                      color: tone?.foreground ?? scheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InlineMarkdown(
                        option.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: picked
                              ? scheme.foreground
                              : scheme.mutedForeground,
                        ),
                      ),
                    ),
                    if (picked) ...[
                      const SizedBox(width: 8),
                      Text(
                        'CHOSEN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Subjective extends StatelessWidget {
  const _Subjective({required this.answer});

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Written(text: answer.answerText),
        if ((answer.questionModelAnswer ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _Callout(
            label: 'Model answer',
            text: answer.questionModelAnswer!,
            shade: TwColors.emerald,
          ),
        ],
      ],
    );
  }
}

class _Coding extends StatelessWidget {
  const _Coding({required this.answer, required this.controller});

  final SubmissionAnswer answer;
  final CodeLineEditingController controller;

  @override
  Widget build(BuildContext context) {
    if ((answer.code ?? '').trim().isEmpty) {
      return _Written(text: null, emptyLabel: 'No code submitted');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCodeEditor(
          controller: controller,
          language: answer.language,
          readOnly: true,
          minHeight: 160,
          maxHeight: 320,
        ),
        const SizedBox(height: 8),
        _TestCaseBand(answer: answer),
      ],
    );
  }
}

/// The auto-grade band. A coding answer that was never run says so plainly, so
/// the teacher knows the score is theirs to set.
class _TestCaseBand extends StatelessWidget {
  const _TestCaseBand({required this.answer});

  final SubmissionAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final total = answer.testCasesTotal ?? 0;

    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_outline_rounded,
              size: 14,
              color: scheme.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not auto-graded — no test-case run for this answer.',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );
    }

    final passed = answer.testCasesPassed ?? 0;
    final shade = passed >= total
        ? TwColors.emerald
        : passed > 0
            ? TwColors.amber
            : TwColors.rose;
    final tone = context.tokens.tone(shade);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border.all(color: tone.foreground.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            passed >= total
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            size: 14,
            color: tone.foreground,
          ),
          const SizedBox(width: 8),
          Text(
            '$passed/$total test cases passed',
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Written extends StatelessWidget {
  const _Written({required this.text, this.emptyLabel = 'No answer'});

  final String? text;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final value = (text ?? '').trim();

    if (value.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: scheme.mutedForeground,
        ),
      );
    }
    return Text(
      value,
      style: theme.textTheme.bodySmall?.copyWith(color: scheme.foreground),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.label,
    required this.text,
    this.shade = TwColors.slate,
  });

  final String label;
  final String text;
  final TwShade shade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(shade);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: tone.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Grading extends StatelessWidget {
  const _Grading({
    required this.answer,
    required this.mark,
    required this.score,
    required this.feedback,
    required this.onScore,
    required this.onFeedback,
    required this.onCorrect,
    required this.onWrong,
  });

  final SubmissionAnswer answer;
  final AnswerMark mark;
  final TextEditingController score;
  final TextEditingController feedback;
  final ValueChanged<String> onScore;
  final ValueChanged<String> onFeedback;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            controller: feedback,
            hint: 'Feedback for this answer (optional)',
            minLines: 2,
            maxLines: 4,
            onChanged: onFeedback,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MarkButton(
                label: 'Wrong',
                icon: Icons.cancel_rounded,
                shade: TwColors.rose,
                selected: mark.isCorrect == false,
                onPressed: onWrong,
              ),
              const SizedBox(width: 8),
              _MarkButton(
                label: 'Correct',
                icon: Icons.check_circle_rounded,
                shade: TwColors.emerald,
                selected: mark.isCorrect == true,
                onPressed: onCorrect,
              ),
              const Spacer(),
              SizedBox(
                width: 52,
                child: AppInput(
                  controller: score,
                  // Matches the 30pt height of the Wrong/Correct buttons
                  // beside it. At the default height it towered over them and
                  // read as the row's primary control; plain `dense` (38) was
                  // still 8pt taller than they are.
                  compact: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onScore,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${answer.questionPoints}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.icon,
    required this.shade,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final TwShade shade;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(shade);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tone.foreground : tone.background,
          border: Border.all(
            color: selected ? tone.foreground : scheme.border,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? scheme.card : tone.foreground,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.card : tone.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
