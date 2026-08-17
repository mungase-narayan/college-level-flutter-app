import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/design/theme/glass_specs.dart';
import '../../../../core/design/widgets/liquid_glass_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../bloc/daily_solve_cubit.dart';
import '../widgets/practice_answer_input.dart';
import '../widgets/practice_result_panel.dart';

/// Port of `daily-challenge-solve.tsx` — one day's set, a question at a time.
///
/// The web puts the palette in a resizable sidebar; here it is a sheet, the
/// same way the quiz runner does it. Everything else follows the web: no
/// auto-advance after an answer, and the review stays in place until the
/// student moves on or tries again.
class DailySolvePage extends StatefulWidget {
  const DailySolvePage({super.key});

  @override
  State<DailySolvePage> createState() => _DailySolvePageState();
}

class _DailySolvePageState extends State<DailySolvePage> {
  @override
  void initState() {
    super.initState();
    context.read<DailySolveCubit>().load();
  }

  void _report(Failure failure) => AppToast.failure(context, failure);

  Future<void> _guard(Future<Failure?> Function() action) async {
    final failure = await action();
    if (failure != null && mounted) _report(failure);
  }

  Future<void> _openPalette(DailySolveState state) async {
    final picked = await showAppSheet<int>(
      context,
      title: 'Questions',
      subtitle: '${state.solvedCount} of ${state.questions.length} solved',
      builder: (context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < state.questions.length; i++)
            _PaletteCell(
              number: i + 1,
              isCurrent: i == state.index,
              isSolved: state.solvedIds.contains(state.questions[i].id),
              isAttempted: state.attemptedIds.contains(state.questions[i].id),
              onTap: () => Navigator.of(context).pop(i),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      context.read<DailySolveCubit>().select(picked);
    }
  }

  Future<void> _redeem(DailySolveCubit cubit) async {
    // A ticket is bought with coins and spending it is irreversible, so unlike
    // the web — which redeems on a single unconfirmed tap — this asks first.
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Use a Time Travel Ticket?',
      message:
          'This spends one ticket to re-open this day so you can still complete '
          'it. Tickets cannot be refunded.',
      confirmLabel: 'Use ticket',
    );
    if (!confirmed || !mounted) return;
    await _guard(cubit.redeemTicket);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailySolveCubit>();

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Daily Challenge'),
      body: SafeArea(
        bottom: false,
        child: RemoteView<DailySolveCubit, DailySolveState>(
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsets.all(16),
            child: AppListSkeleton(rows: 3),
          ),
          builder: (context, state) {
            final set = state.challenge.set;
            if (!state.challenge.available || set == null) {
              return AppEmptyState(
                title: 'No challenge on this date',
                description:
                    'There was no daily challenge posted for '
                    '${Fmt.longDate(cubit.date)}.',
                icon: Icons.calendar_month_outlined,
              );
            }
            if (state.questions.isEmpty) {
              return const AppEmptyState(
                title: 'No questions in this challenge',
                description: 'Check back tomorrow for a fresh set.',
                icon: Icons.help_outline_rounded,
              );
            }

            return Column(
              children: [
                _StatusBanner(state: state, onRedeem: () => _redeem(cubit)),
                _ProgressHeader(
                  state: state,
                  onPalette: () => _openPalette(state),
                ),
                Expanded(
                  child: _QuestionPane(state: state, onGuard: _guard),
                ),
                _Footer(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Says whether this day can still be answered, and offers the way back in.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.onRedeem});

  final DailySolveState state;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final challenge = state.challenge;

    if (challenge.timeTravelUnlocked) {
      final tone = tokens.tone(TwColors.violet);
      return _Banner(
        tone: tone,
        child: Text(
          'Time Travel Ticket active — complete this challenge to earn its '
          'points.',
          style: theme.textTheme.labelMedium?.copyWith(color: tone.foreground),
        ),
      );
    }

    if (challenge.isOpen) return const SizedBox.shrink();

    final tone = tokens.tone(TwColors.amber);
    return _Banner(
      tone: tone,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'This challenge is outside its window — review only.',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: tone.foreground),
            ),
          ),
          if (challenge.availableTickets > 0) ...[
            const SizedBox(width: 8),
            AppButton(
              label: state.isRedeeming
                  ? 'Applying…'
                  : 'Use ticket (${challenge.availableTickets})',
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
              isLoading: state.isRedeeming,
              onPressed: state.isRedeeming ? null : onRedeem,
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.tone, required this.child});

  final StatusTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: tone.background,
        child: child,
      );
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state, required this.onPalette});

  final DailySolveState state;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final total = state.questions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${state.index + 1} of $total',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (state.isComplete)
                AppBadge('Completed', shade: TwColors.emerald, dense: true),
              IconButton(
                onPressed: onPalette,
                tooltip: 'All questions',
                icon: const Icon(Icons.grid_view_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : state.solvedCount / total,
              minHeight: 5,
              backgroundColor: scheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.solvedCount} of $total solved',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _QuestionPane extends StatelessWidget {
  const _QuestionPane({required this.state, required this.onGuard});

  final DailySolveState state;
  final Future<void> Function(Future<Failure?> Function()) onGuard;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailySolveCubit>();
    final theme = Theme.of(context);
    final question = state.current!;
    final result = state.result;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(question.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AppBadge(question.difficulty, dense: true),
            AppBadge('${question.points} pts', dense: true),
            if (state.solvedIds.contains(question.id))
              AppBadge('Solved', shade: TwColors.emerald, dense: true),
          ],
        ),
        if ((question.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          AppMarkdown(question.description),
        ],
        const SizedBox(height: 18),

        // After an answer the form gives way to its result, exactly as the web
        // does — no auto-advance, so the student reads it before moving on.
        if (result != null)
          PracticeResultPanel(
            attempt: result,
            // `revealed` is the question as the review payload returned it —
            // the only copy that carries the answer key.
            question: state.revealed ?? question,
            // Another go is only on offer while the day is open. A closed day
            // can be read back, not redone.
            onRetry: state.challenge.isOpen ? cubit.retry : null,
            onClose: cubit.retry,
          )
        else if (question.isObjective)
          PracticeObjectiveInput(
            question: question,
            selected: state.draft.selectedAnswers,
            enabled: state.canAttempt,
            onChanged: (ids) =>
                cubit.setDraft(state.draft.copyWith(selectedAnswers: ids)),
          )
        else if (question.isCoding)
          PracticeCodingInput(
            question: question,
            draft: state.draft,
            isRunning: state.isRunning,
            enabled: state.canAttempt,
            onChanged: cubit.setDraft,
            onRun: () => onGuard(cubit.run),
            onRunCustom: (stdin) => onGuard(() => cubit.runCustom(stdin)),
          )
        else
          _SubjectiveField(
            key: ValueKey(question.id),
            initial: state.draft.answerText,
            enabled: state.canAttempt,
            onChanged: (text) =>
                cubit.setDraft(state.draft.copyWith(answerText: text)),
          ),

        if (result == null && state.runResult != null) ...[
          const SizedBox(height: 14),
          PracticeCodingResultView(result: state.runResult!),
        ],
        if (result == null && state.customResult != null) ...[
          const SizedBox(height: 14),
          Text(
            state.customResult!.stdout ?? state.customResult!.stderr ?? '',
            style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

class _SubjectiveField extends StatefulWidget {
  const _SubjectiveField({
    super.key,
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  final String? initial;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_SubjectiveField> createState() => _SubjectiveFieldState();
}

class _SubjectiveFieldState extends State<_SubjectiveField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        maxLines: 10,
        minLines: 5,
        decoration: const InputDecoration(
          hintText: 'Write your answer…',
          alignLabelWithHint: true,
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final DailySolveState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailySolveCubit>();
    final scheme = context.scheme;
    final isLast = state.index >= state.questions.length - 1;
    final answered = state.result != null;

    final body = Padding(
      // `viewPadding`, not `padding`: the bar draws itself into the home
      // indicator's strip so its surface reaches the screen edge, and only its
      // *contents* sit above the indicator. Reserving the full inset as
      // padding as well left a band of empty white under the button.
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous question',
            onPressed:
                state.index == 0 ? null : () => cubit.select(state.index - 1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: answered
                ? AppButton(
                    label: isLast ? 'Finish' : 'Next question',
                    icon: isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: isLast
                        ? () => Navigator.of(context).maybePop()
                        : () => cubit.select(state.index + 1),
                  )
                : AppButton(
                    label: state.isSubmitting ? 'Submitting…' : 'Submit answer',
                    icon: Icons.send_rounded,
                    expand: true,
                    isLoading: state.isSubmitting,
                    // Disabled outside the window: the server would refuse it,
                    // and a rejected submit reads as lost work.
                    onPressed: state.canSubmit
                        ? () async {
                            final failure = await cubit.submit();
                            if (failure != null && context.mounted) {
                              AppToast.failure(context, failure);
                            }
                          }
                        : null,
                  ),
          ),
          const SizedBox(width: 10),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next question',
            onPressed: isLast ? null : () => cubit.select(state.index + 1),
          ),
        ],
      ),
    );

    // Chrome, like the app bar and the comment composer: the questions scroll
    // under it rather than stopping at an opaque strip.
    if (context.useGlass) {
      final glass = context.glass;
      return LiquidGlassContainer(
        blur: GlassBlur.chrome,
        spec: glass.chromeScrolled,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        showShadow: false,
        showHighlight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: glass.chromeScrolled.borderColor,
            ),
            body,
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: body,
    );
  }
}

/// A step-to-the-next-question control.
///
/// A circle rather than a bare `IconButton`, so the two of them read as a pair
/// bracketing the primary action instead of as two stray glyphs.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? scheme.muted : Colors.transparent,
            border: Border.all(
              color: enabled ? scheme.border : scheme.border.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            // Dimmed rather than hidden at the ends of the set: a control that
            // vanishes moves the button beside it.
            color: enabled
                ? scheme.foreground
                : scheme.mutedForeground.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// One cell of the question palette.
class _PaletteCell extends StatelessWidget {
  const _PaletteCell({
    required this.number,
    required this.isCurrent,
    required this.isSolved,
    required this.isAttempted,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;

  /// Solved beats attempted — a question answered correctly is done, however
  /// many tries it took.
  final bool isSolved;
  final bool isAttempted;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final (background, foreground) = isCurrent
        ? (scheme.primary, scheme.primaryForeground)
        : isSolved
            ? (
                tokens.tone(TwColors.emerald).background,
                tokens.tone(TwColors.emerald).foreground,
              )
            : isAttempted
                ? (
                    tokens.tone(TwColors.orange).background,
                    tokens.tone(TwColors.orange).foreground,
                  )
                : (scheme.muted, scheme.mutedForeground);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          '$number',
          style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
        ),
      ),
    );
  }
}
