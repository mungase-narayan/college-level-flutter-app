import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:re_editor/re_editor.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/files/domain/usecases/file_usecases.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/assessment_detail.dart';
import '../../domain/entities/student_assessment.dart';
import '../../domain/usecases/attempt_usecases.dart';
import '../bloc/assessment_detail_cubit.dart';

/// Where an attachment comes from. iOS cannot span the document browser and the
/// photo library in one picker, so the student picks the source first.
enum _PickSource { files, photos, camera }

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

  /// The server's tally, seeded from the attempt so a resumed session shows
  /// what the student has already used rather than restarting at zero. Each
  /// report replaces it with the count the server answers with — the client
  /// never does its own arithmetic on it.
  late int _violations = widget.detail.submission?.violationCount ?? 0;

  /// Reports are chained so two signals firing together cannot race the
  /// counter, and so a burst is applied in the order it happened.
  Future<void> _reports = Future.value();

  /// The threshold fires exactly once: the auto-submit is already in flight for
  /// every later event, and a second submit would error over the first.
  bool _thresholdFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
  }

  /// The signals the teacher switched on. Null while the assessment is not
  /// proctored, or when the server sent no config at all.
  ProctoringConfig? get _config => widget.detail.assessment.isProctored
      ? widget.detail.assessment.proctoringConfig
      : null;

  /// Records a violation server-side and acts on what comes back.
  ///
  /// Failures are swallowed on purpose: a dropped report must not take the
  /// attempt down with it, and the server re-tallies from its own events when
  /// the next one lands.
  void _reportViolation(String eventType, {Map<String, dynamic>? meta}) {
    if (_thresholdFired) return;
    final occurredAt = DateTime.now();

    _reports = _reports.then((_) async {
      if (_thresholdFired || !mounted) return;

      final result = await sl<RecordProctorEventUseCase>()(
        ProctorEventParams(
          assessmentId: widget.detail.assessment.id,
          eventType: eventType,
          occurredAt: occurredAt,
          meta: meta,
        ),
      );
      if (!mounted) return;

      result.fold((_) {}, (event) {
        setState(() => _violations = event.violationCount);

        // The limit is enforced on both sides. `shouldAutoSubmit` is the
        // server's word and is authoritative, but the client holds the same
        // `maxViolations` it is already showing the student — so if that flag
        // ever fails to arrive, the count must still not be allowed to sail
        // past the limit the student was promised. Reaching the limit ends the
        // attempt either way.
        final max = widget.detail.assessment.maxViolations;
        final reachedLimit = event.shouldAutoSubmit ||
            (max != null && event.violationCount >= max);

        if (reachedLimit && !_thresholdFired) {
          _thresholdFired = true;
          // One message, not two: `_warnViolation` would also fire here and
          // the student would get "no warnings left" stacked on top of the
          // submission notice.
          unawaited(_submitForViolations(eventType));
          return;
        }
        _warnViolation(eventType, event.violationCount);
      });
    });
  }

  /// Tells the student what was seen and how much rope is left, matching the
  /// web's warning toast.
  void _warnViolation(String eventType, int count) {
    final max = widget.detail.assessment.maxViolations;
    final label = ProctorEventType.label(eventType);
    if (max == null) {
      AppToast.warning(context, '$label. This has been recorded.');
      return;
    }
    final left = (max - count).clamp(0, max);
    AppToast.warning(
      context,
      left == 0
          ? '$label. No warnings left — submitting automatically.'
          : '$label. $left warning${left == 1 ? '' : 's'} left before '
              'auto-submit.',
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only when the teacher asked for it. Counting a background switch against
    // a student whose assessment never enabled tab-switch detection is the
    // difference between proctoring and punishing.
    if (_config?.tabSwitch != true) return;
    // Backgrounding the app is only suspicious when the student did not ask for
    // it. Opening the file picker to hand in their work is the opposite.
    if (_isTrustedInteraction) return;
    // `paused` / `inactive` is the mobile stand-in for the web's tab-switch and
    // fullscreen-exit signals. Only `paused` counts: `inactive` also fires for
    // a notification banner or the app switcher being peeked, which the student
    // did not choose, and it always precedes a real `paused` anyway.
    if (state == AppLifecycleState.paused) {
      _reportViolation(ProctorEventType.tabSwitch);
    }
  }

  /// While set, lifecycle changes are the student's own doing — an OS picker
  /// they deliberately opened owns the screen.
  ///
  /// A *deadline* rather than a flag: a picker that throws, or a platform
  /// channel that never answers, would leave a boolean stuck on and quietly
  /// disable proctoring for the rest of the attempt. This expires by itself.
  DateTime? _trustedUntil;

  bool get _isTrustedInteraction {
    final until = _trustedUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _trustedUntil = null;
      return false;
    }
    return true;
  }

  /// Called synchronously, before the picker opens — the `inactive` event
  /// arrives before any `await` would return.
  void _beginTrustedInteraction() =>
      _trustedUntil = DateTime.now().add(const Duration(minutes: 10));

  void _endTrustedInteraction() {
    // The trailing inactive → resumed pair lands a frame or two after the
    // picker dismisses; re-arming immediately would score that as the
    // violation the suppression existed to prevent.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _trustedUntil = null;
    });
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
    if (questions.isEmpty) {
      return _SubmissionForm(
        detail: widget.detail,
        onBeforePick: _beginTrustedInteraction,
        onAfterPick: _endTrustedInteraction,
      );
    }

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
          // Shown for any proctored attempt, not just one with a mobile
          // signal enabled: a resumed attempt can carry violations recorded on
          // the web, and hiding them would understate where the student stands.
          // Shown for any proctored attempt, not just one with a mobile
          // signal enabled: a resumed attempt can carry violations recorded on
          // the web, and hiding them would understate where the student stands.
          violations:
              widget.detail.assessment.isProctored ? _violations : null,
          maxViolations: widget.detail.assessment.maxViolations,
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
                onClipboardViolation:
                    _config?.copyPaste == true ? _reportViolation : null,
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

  /// Ends the attempt because the violation limit was reached, then leaves it.
  ///
  /// The submit is allowed to fail without changing the outcome: the server
  /// finalizes the attempt itself the moment the threshold trips, so a failure
  /// here usually means it is *already* submitted. Either way the student must
  /// not be left sitting on a live-looking quiz they can no longer submit, so
  /// the screen closes regardless.
  Future<void> _submitForViolations(String eventType) async {
    final cubit = context.read<AssessmentDetailCubit>();
    // Captured before the await. Submitting reloads the attempt, which swaps
    // this runner for the review screen — so by the time the submit returns,
    // this widget may be gone and its context dead. The router outlives it.
    final router = GoRouter.of(context);
    final fallback = widget.kind.toLowerCase() == 'quiz'
        ? StudentRoutes.quiz
        : StudentRoutes.assignments;

    _clock?.cancel();

    // Said first, while this widget is certainly still alive to say it.
    AppToast.warning(
      context,
      '${ProctorEventType.label(eventType)}. Violation limit reached — your '
      '${widget.kind.toLowerCase()} was submitted automatically.',
    );

    // The outcome does not depend on this succeeding: the server finalizes the
    // attempt itself the moment the threshold trips, so a failure here almost
    // always means it is already submitted. Either way the student must not be
    // left on a live-looking quiz they can no longer submit.
    await cubit.submit(autoSubmitted: true);

    if (router.canPop()) {
      router.pop();
    } else {
      // No stack — a deep link straight into the attempt. Land on the list the
      // quiz came from rather than a dead end.
      router.go(fallback);
    }
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
    required this.maxViolations,
    required this.onPalette,
  });

  final int index;
  final int total;
  final int answered;
  final Duration? remaining;
  final int? violations;

  /// The limit the count is racing towards, when the assessment sets one.
  final int? maxViolations;
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
          // Shown from the first question, at zero. The allowance is part of
          // the rules the student is playing by, so it has to be visible
          // *before* it is spent — appearing only on the first violation made
          // it read as a punishment notice rather than as a budget.
          //
          // Amber is reserved for a student who has actually spent something;
          // an untouched allowance is information, not a warning.
          if (violations != null) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final tone = violations! > 0
                  ? tokens.warning.foreground
                  : context.scheme.mutedForeground;

              return Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: tone),
                  const SizedBox(width: 6),
                  Text(
                    // Clamped: the server's tally can legitimately run past the
                    // limit — a burst of events queued while the app was in the
                    // background all land — but "4 of 3" is nonsense to read,
                    // and the attempt is over at 3 either way.
                    maxViolations == null
                        ? '$violations violation'
                            '${violations == 1 ? '' : 's'} recorded'
                        : '${violations!.clamp(0, maxViolations!)} of '
                            '$maxViolations violations used',
                    style: theme.textTheme.labelSmall?.copyWith(color: tone),
                  ),
                ],
              );
            }),
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
    this.onClipboardViolation,
  });

  final int index;
  final AssessmentQuestion question;
  final QuestionAnswer? answer;
  final ValueChanged<QuestionAnswer> onChanged;

  /// Non-null only while `copyPaste` proctoring is on.
  final ValueChanged<String>? onClipboardViolation;

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
              // An assessment question carries no language of its own; the only
              // hint is whatever the student's saved answer was written in.
              language: _base.language,
              onClipboardViolation: onClipboardViolation,
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
/// A coding answer gets the shared [AppCodeEditor] — syntax highlighting, a
/// line-number gutter and horizontal scrolling — so a coding question feels the
/// same here as it does in the practice question bank. Prose keeps a plain
/// field: highlighting an essay would be noise.
class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.initial,
    required this.isCode,
    required this.onChanged,
    this.language,
    this.onClipboardViolation,
  });

  final String? initial;
  final bool isCode;
  final ValueChanged<String> onChanged;

  /// Set only while `copyPaste` proctoring is on. Called with the event type
  /// when the student reaches for copy, cut or paste — the action is blocked
  /// as well as reported, matching the web, whose switch is literally labelled
  /// "Block copy & paste".
  final ValueChanged<String>? onClipboardViolation;

  /// Drives the highlighting when this is a coding answer. An assessment
  /// question carries no language of its own, so this is usually null and the
  /// code renders unhighlighted rather than guessed at.
  final String? language;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  TextEditingController? _text;
  CodeLineEditingController? _code;

  @override
  void initState() {
    super.initState();
    if (widget.isCode) {
      _code = CodeLineEditingController.fromText(widget.initial ?? '')
        ..addListener(_onCodeChanged);
    } else {
      _text = TextEditingController(text: widget.initial);
    }
  }

  void _onCodeChanged() => widget.onChanged(_code!.text);

  @override
  void dispose() {
    _text?.dispose();
    _code?..removeListener(_onCodeChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code != null) {
      return AppCodeEditor(
        controller: code,
        language: widget.language,
        hint: 'Write your solution…',
      );
    }

    final report = widget.onClipboardViolation;

    return TextField(
      controller: _text,
      onChanged: widget.onChanged,
      maxLines: 8,
      minLines: 5,
      style: Theme.of(context).textTheme.bodyMedium,
      contextMenuBuilder: report == null
          ? null
          : (context, editableTextState) {
              // The clipboard entries stay in the menu rather than being hidden:
              // a student who reaches for paste has to be told it was seen and
              // refused, and a menu that silently lacks the button reads as a
              // bug instead of a rule.
              final items = [
                for (final item in editableTextState.contextMenuButtonItems)
                  switch (item.type) {
                    ContextMenuButtonType.copy => item.copyWith(
                        onPressed: () {
                          editableTextState.hideToolbar();
                          report(ProctorEventType.copy);
                        },
                      ),
                    ContextMenuButtonType.cut => item.copyWith(
                        onPressed: () {
                          editableTextState.hideToolbar();
                          report(ProctorEventType.copy);
                        },
                      ),
                    ContextMenuButtonType.paste => item.copyWith(
                        onPressed: () {
                          editableTextState.hideToolbar();
                          report(ProctorEventType.paste);
                        },
                      ),
                    _ => item,
                  },
              ];
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: items,
              );
            },
      decoration: const InputDecoration(
        hintText: 'Type your answer…',
        alignLabelWithHint: true,
      ),
    );
  }
}

/// Port of `SubmissionForm` — a note plus attachments, for assessments that
/// have no questions.
class _SubmissionForm extends StatefulWidget {
  const _SubmissionForm({
    required this.detail,
    required this.onBeforePick,
    required this.onAfterPick,
  });

  final AssessmentDetail detail;

  /// Called synchronously before the OS picker opens, and again once it has
  /// closed, so a proctored attempt does not score the resulting background
  /// event as a violation.
  final VoidCallback onBeforePick;
  final VoidCallback onAfterPick;

  @override
  State<_SubmissionForm> createState() => _SubmissionFormState();
}

class _SubmissionFormState extends State<_SubmissionForm> {
  late final TextEditingController _note =
      TextEditingController(text: widget.detail.submission?.note);

  /// Seeded from the server so a resumed draft — or one started on the web —
  /// shows what is already attached.
  late final List<String> _fileIds =
      List<String>.of(widget.detail.submission?.fileIds ?? const []);

  bool _isBusy = false;
  bool _isUploading = false;

  /// Anything past this fails slowly and then times out on mobile data; naming
  /// it up front beats a generic error three minutes later.
  static const _maxUploadBytes = 25 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    // The auto-submit path (time expiry, violation limit) reads these off the
    // cubit, so it has to know what is attached before anything is saved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AssessmentDetailCubit>().setFileIds(_fileIds);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send({required bool submit}) async {
    final cubit = context.read<AssessmentDetailCubit>();
    setState(() => _isBusy = true);

    // Carry the body on both paths — submitting without it would discard
    // everything the student typed or attached.
    cubit.setNote(_note.text);
    cubit.setFileIds(_fileIds);
    final failure = submit ? await cubit.submit() : await cubit.flushDraft();

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, submit ? 'Submitted.' : 'Draft saved');
  }

  /// Picks files and uploads them one at a time.
  ///
  /// Sequential rather than concurrent: a phone radio handles one multipart
  /// body far better than three, and a failure halfway through leaves a result
  /// the student can understand.
  Future<void> _addFiles() async {
    final source = await showAppOptionSheet<_PickSource>(
      context,
      title: 'Add files',
      options: const [
        AppSheetOption(
          value: _PickSource.files,
          label: 'Choose files',
          description: 'PDFs, documents, images',
          icon: Icons.folder_open_rounded,
        ),
        AppSheetOption(
          value: _PickSource.photos,
          label: 'Photo library',
          description: 'A photo of written work',
          icon: Icons.photo_library_outlined,
        ),
        AppSheetOption(
          value: _PickSource.camera,
          label: 'Take a photo',
          icon: Icons.photo_camera_outlined,
        ),
      ],
    );
    if (source == null || !mounted) return;

    // Set *before* the picker opens: the OS backgrounds the app before any
    // await here would return.
    widget.onBeforePick();
    List<({String path, String name})> picked = const [];
    try {
      picked = await _pick(source);
    } on PlatformException {
      if (mounted) {
        AppToast.error(context, 'Could not open the picker. Check permissions.');
      }
    } finally {
      widget.onAfterPick();
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _isUploading = true);
    final upload = sl<UploadFileUseCase>();
    var uploaded = 0;
    String? error;

    for (final file in picked) {
      final size = await File(file.path).length();
      if (size > _maxUploadBytes) {
        error = '${file.name} is larger than 25 MB.';
        break;
      }
      final result = await upload(
        UploadFileParams(filePath: file.path, fileName: file.name),
      );
      final failed = result.fold((failure) => failure, (_) => null);
      if (failed != null) {
        error = failed.message;
        break;
      }
      // Kept as they land rather than all-or-nothing: throwing away a file that
      // already uploaded because a later one failed is the web's behaviour and
      // it is the wrong one on a phone connection.
      result.forEach((file) {
        if (!_fileIds.contains(file.id)) _fileIds.add(file.id);
      });
      uploaded++;
    }

    if (!mounted) return;
    setState(() => _isUploading = false);
    context.read<AssessmentDetailCubit>().setFileIds(_fileIds);

    if (error != null) {
      AppToast.error(
        context,
        uploaded == 0
            ? error
            : 'Attached $uploaded of ${picked.length}. $error',
      );
    }
  }

  Future<List<({String path, String name})>> _pick(_PickSource source) async {
    if (source == _PickSource.files) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        // Paths, not bytes: `DioClient.uploadFile` streams from a path, and
        // loading a 20 MB document into memory to hand it straight back is
        // wasted heap.
        withData: false,
      );
      return [
        for (final file in result?.files ?? const <PlatformFile>[])
          if (file.path != null) (path: file.path!, name: file.name),
      ];
    }

    final picked = await ImagePicker().pickImage(
      source: source == _PickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Deliberately unresized, unlike the avatar flow: a photo of handwritten
      // work has to stay legible.
    );
    return picked == null ? const [] : [(path: picked.path, name: picked.name)];
  }

  void _removeFile(String fileId) {
    setState(() => _fileIds.remove(fileId));
    context.read<AssessmentDetailCubit>().setFileIds(_fileIds);
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
              // The brief stays reachable mid-attempt: backing out to the intro
              // to re-read the question paper would abandon the draft.
              if (widget.detail.assessment.fileIds.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Brief', style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                for (final fileId in widget.detail.assessment.fileIds)
                  AttachmentTile(fileId: fileId),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attachments',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  AppButton(
                    label: _isUploading ? 'Uploading…' : 'Add files',
                    icon: Icons.attach_file_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.outline,
                    isLoading: _isUploading,
                    // Also blocked while saving: submitting halfway through an
                    // upload would hand in an incomplete list.
                    onPressed: _isUploading || _isBusy ? null : _addFiles,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_fileIds.isEmpty)
                Text(
                  'Upload files to support your submission (optional).',
                  style: theme.textTheme.labelSmall,
                )
              else
                for (final fileId in _fileIds)
                  AttachmentTile(
                    key: ValueKey(fileId),
                    fileId: fileId,
                    onRemove: _isBusy ? null : () => _removeFile(fileId),
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
