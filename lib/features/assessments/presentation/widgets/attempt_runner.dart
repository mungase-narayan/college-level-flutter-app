import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/assessment_detail.dart';
import '../bloc/assessment_detail_cubit.dart';

/// Port of `attempt/index.tsx`, re-flowed for a phone.
///
/// The desktop runner is a resizable navigator sidebar beside the question
/// pane. Here it is one question per page with a palette in a bottom sheet, a
/// countdown in the header, and the same autosave.
///
/// A proctored attempt also watches the app lifecycle: leaving the app is the
/// mobile equivalent of the web's fullscreen-exit signal.
class AttemptRunner extends StatefulWidget {
  const AttemptRunner({super.key, required this.detail, required this.kind});

  final AssessmentDetail detail;
  final String kind;

  @override
  State<AttemptRunner> createState() => _AttemptRunnerState();
}

class _AttemptRunnerState extends State<AttemptRunner> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _clock;
  Duration? _remaining;

  /// Counted locally so the student sees a warning immediately; the server
  /// remains the authority on the violation total.
  int _violations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.detail.assessment.isProctored) return;
    // `paused` / `inactive` is the mobile stand-in for the web's tab-switch and
    // fullscreen-exit signals.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      setState(() => _violations++);
    }
  }

  /// Counts down from the attempt's start plus its duration.
  void _startClock() {
    final minutes = widget.detail.assessment.durationMinutes;
    final startedAt = DateTime.tryParse(widget.detail.submission?.startedAt ?? '');
    if (minutes == null || startedAt == null) return;

    final endsAt = startedAt.toLocal().add(Duration(minutes: minutes));
    void tick() {
      final left = endsAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _remaining = left.isNegative ? Duration.zero : left);
      if (left.isNegative) {
        _clock?.cancel();
        // Time is up — submit for them rather than silently losing the work.
        unawaited(_submit(autoSubmitted: true));
      }
    }

    tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.detail.questions;

    // A submission-type assessment has no questions — it's a note + files.
    if (questions.isEmpty) return _SubmissionForm(detail: widget.detail);

    final cubit = context.watch<AssessmentDetailCubit>();
    final question = questions[_index];
    final answer = cubit.draft[question.assessmentQuestionId];

    return Column(
      children: [
        _RunnerHeader(
          index: _index,
          total: questions.length,
          answered: cubit.answeredCount,
          remaining: _remaining,
          violations: widget.detail.assessment.isProctored ? _violations : null,
          onPalette: () => _openPalette(questions, cubit),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _QuestionCard(
                index: _index + 1,
                question: question,
                answer: answer,
                onChanged: (updated) => cubit.setAnswer(question, updated),
              ),
            ],
          ),
        ),
        _RunnerFooter(
          isFirst: _index == 0,
          isLast: _index == questions.length - 1,
          isBusy: cubit.isBusy,
          onPrevious: () => setState(() => _index--),
          onNext: () => setState(() => _index++),
          onSubmit: _confirmSubmit,
        ),
      ],
    );
  }

  Future<void> _openPalette(
    List<AssessmentQuestion> questions,
    AssessmentDetailCubit cubit,
  ) async {
    final picked = await showAppSheet<int>(
      context,
      title: 'Questions',
      subtitle: '${cubit.answeredCount} of ${questions.length} answered',
      builder: (context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < questions.length; i++)
            _PaletteCell(
              number: i + 1,
              isCurrent: i == _index,
              isAnswered:
                  cubit.draft[questions[i].assessmentQuestionId]?.isAnswered ??
                      false,
              onTap: () => Navigator.of(context).pop(i),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _index = picked);
  }

  Future<void> _confirmSubmit() async {
    final cubit = context.read<AssessmentDetailCubit>();
    final total = widget.detail.questions.length;
    final unanswered = total - cubit.answeredCount;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Submit ${widget.kind.toLowerCase()}?',
      message: unanswered > 0
          ? '$unanswered of $total questions are unanswered. You cannot change '
              'your answers after submitting.'
          : 'You cannot change your answers after submitting.',
      confirmLabel: 'Submit',
    );
    if (!confirmed) return;
    await _submit();
  }

  Future<void> _submit({bool autoSubmitted = false}) async {
    final cubit = context.read<AssessmentDetailCubit>();
    final failure = await cubit.submit(autoSubmitted: autoSubmitted);
    if (!mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(
      context,
      autoSubmitted ? 'Time is up — submitted automatically.' : 'Submitted.',
    );
  }
}

class _RunnerHeader extends StatelessWidget {
  const _RunnerHeader({
    required this.index,
    required this.total,
    required this.answered,
    required this.remaining,
    required this.violations,
    required this.onPalette,
  });

  final int index;
  final int total;
  final int answered;
  final Duration? remaining;
  final int? violations;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    // Rose under five minutes, matching the arena's urgent tint.
    final urgent = remaining != null && remaining!.inSeconds <= 300;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1} of $total',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (remaining != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: urgent ? tokens.danger.foreground : scheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Fmt.countdown(remaining!),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFeatures: const [],
                          color: urgent ? tokens.danger.foreground : scheme.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                tooltip: 'All questions',
                onPressed: onPalette,
                icon: const Icon(Icons.grid_view_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : answered / total,
                    minHeight: 5,
                    backgroundColor: scheme.muted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$answered/$total', style: theme.textTheme.labelSmall),
              const SizedBox(width: 8),
            ],
          ),
          if (violations != null && violations! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: tokens.warning.foreground),
                const SizedBox(width: 6),
                Text(
                  '$violations violation${violations == 1 ? '' : 's'} recorded',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: tokens.warning.foreground),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RunnerFooter extends StatelessWidget {
  const _RunnerFooter({
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Previous',
              variant: AppButtonVariant.outline,
              icon: Icons.chevron_left_rounded,
              onPressed: isFirst ? null : onPrevious,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isLast
                ? AppButton(
                    label: 'Submit',
                    isLoading: isBusy,
                    onPressed: onSubmit,
                  )
                : AppButton(label: 'Next', onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

class _PaletteCell extends StatelessWidget {
  const _PaletteCell({
    required this.number,
    required this.isCurrent,
    required this.isAnswered,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final bool isAnswered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final background = isCurrent
        ? scheme.primary
        : isAnswered
            ? tokens.success.background
            : scheme.muted;
    final foreground = isCurrent
        ? scheme.primaryForeground
        : isAnswered
            ? tokens.success.foreground
            : scheme.mutedForeground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isCurrent ? scheme.primary : scheme.border,
          ),
        ),
        child: Text(
          '$number',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// One question with the input its type calls for.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final int index;
  final AssessmentQuestion question;
  final QuestionAnswer? answer;
  final ValueChanged<QuestionAnswer> onChanged;

  QuestionAnswer get _base =>
      answer ??
      QuestionAnswer(
        assessmentQuestionId: question.assessmentQuestionId,
        questionId: question.questionId,
        questionType: question.type,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppBadge(question.typeLabel, dense: true),
              const SizedBox(width: 6),
              AppBadge('${question.points} pts', shade: TwColors.violet, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(question.title, style: theme.textTheme.titleSmall),
          if ((question.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            AppMarkdown(question.description),
          ],
          const SizedBox(height: 16),
          if (question.isObjective)
            _ObjectiveInput(
              question: question,
              selected: _base.selectedAnswers,
              onChanged: (ids) => onChanged(_base.copyWith(selectedAnswers: ids)),
            )
          else
            _TextInput(
              key: ValueKey(question.assessmentQuestionId),
              initial: question.type == 'coding' ? _base.code : _base.answerText,
              isCode: question.type == 'coding',
              onChanged: (value) => onChanged(
                question.type == 'coding'
                    ? _base.copyWith(code: value)
                    : _base.copyWith(answerText: value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ObjectiveInput extends StatelessWidget {
  const _ObjectiveInput({
    required this.question,
    required this.selected,
    required this.onChanged,
  });

  final AssessmentQuestion question;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // True/false questions carry no stored options; synthesise the pair.
    final options = question.options.isNotEmpty
        ? question.options
        : const [
            AnswerOption(id: 'true', text: 'True'),
            AnswerOption(id: 'false', text: 'False'),
          ];

    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () {
                if (question.allowsMultiple) {
                  final next = [...selected];
                  next.contains(option.id)
                      ? next.remove(option.id)
                      : next.add(option.id);
                  onChanged(next);
                } else {
                  onChanged([option.id]);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: selected.contains(option.id)
                      ? scheme.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: selected.contains(option.id)
                        ? scheme.primary
                        : scheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      question.allowsMultiple
                          ? (selected.contains(option.id)
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                          : (selected.contains(option.id)
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                      size: 20,
                      color: selected.contains(option.id)
                          ? scheme.primary
                          : scheme.mutedForeground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(option.text, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (question.allowsMultiple)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select all that apply.',
              style: theme.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

/// Free-text and coding answers.
///
/// Coding uses a monospace field for now; the full editor arrives with the
/// practice solve workspace.
class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.initial,
    required this.isCode,
    required this.onChanged,
  });

  final String? initial;
  final bool isCode;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.isCode ? 14 : 8,
      minLines: widget.isCode ? 8 : 5,
      style: widget.isCode
          ? const TextStyle(fontFamily: AppTheme.mono, fontSize: 13.5)
          : Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.isCode ? 'Write your solution…' : 'Type your answer…',
        alignLabelWithHint: true,
      ),
    );
  }
}

/// Port of `SubmissionForm` — a note plus attachments, for assessments that
/// have no questions.
class _SubmissionForm extends StatefulWidget {
  const _SubmissionForm({required this.detail});

  final AssessmentDetail detail;

  @override
  State<_SubmissionForm> createState() => _SubmissionFormState();
}

class _SubmissionFormState extends State<_SubmissionForm> {
  late final TextEditingController _note =
      TextEditingController(text: widget.detail.submission?.note);
  bool _isBusy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send({required bool submit}) async {
    final cubit = context.read<AssessmentDetailCubit>();
    setState(() => _isBusy = true);

    // Carry the body on both paths — submitting without it would discard
    // everything the student typed.
    cubit.setNote(_note.text);
    final failure = submit ? await cubit.submit() : await cubit.flushDraft();

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, submit ? 'Submitted.' : 'Draft saved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text(widget.detail.assessment.title, style: theme.textTheme.titleMedium),
              if ((widget.detail.assessment.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                AppMarkdown(widget.detail.assessment.description),
              ],
              const SizedBox(height: 18),
              Text('Your submission', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 12,
                minLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Write your submission…',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: context.scheme.card,
            border: Border(top: BorderSide(color: context.scheme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Save draft',
                  variant: AppButtonVariant.outline,
                  onPressed: _isBusy ? null : () => _send(submit: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Submit',
                  isLoading: _isBusy,
                  onPressed: () => _send(submit: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
