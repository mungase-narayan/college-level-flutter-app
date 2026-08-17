import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../discussions/presentation/widgets/discussion_tab.dart';
import '../../../notes/presentation/widgets/material_notes_tab.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
import '../bloc/practice_question_cubit.dart';
import '../widgets/practice_answer_input.dart';
import '../widgets/practice_result_panel.dart';

/// Port of `src/pages/student/practice/detail.tsx` — one question, solved.
///
/// The web splits into two layouts: a tabbed card for objective questions and a
/// three-pane resizable IDE for coding ones. A phone has room for neither
/// arrangement, so both collapse into the same tabbed screen and the coding
/// extras (editor, run buttons, test cases) become part of the Solve tab.
class PracticeQuestionPage extends StatefulWidget {
  const PracticeQuestionPage({super.key});

  @override
  State<PracticeQuestionPage> createState() => _PracticeQuestionPageState();
}

class _PracticeQuestionPageState extends State<PracticeQuestionPage> {
  @override
  void initState() {
    super.initState();
    context.read<PracticeQuestionCubit>().load();
  }

  void _report(Failure failure) => AppToast.failure(context, failure);

  Future<void> _go(String mode) async {
    final cubit = context.read<PracticeQuestionCubit>();
    final id = await cubit.nextQuestionId(mode: mode);
    if (!mounted) return;
    if (id == null) {
      AppToast.warning(context, 'No other questions available.');
      return;
    }
    // `pushReplacement`, not `push`: walking a bank of questions must not build
    // a back stack the student has to unwind one at a time.
    context.pushReplacement('/student/practice/$id');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeQuestionCubit>();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: 'Question',
          actions: [
            BlocBuilder<PracticeQuestionCubit, RemoteState<PracticeSolveState>>(
              builder: (context, state) {
                final bookmarked = state.data?.detail.bookmarked ?? false;
                return IconButton(
                  tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                  onPressed: state.data == null
                      ? null
                      : () async {
                          final failure = await cubit.toggleBookmark();
                          if (failure != null && context.mounted) {
                            _report(failure);
                          }
                        },
                  icon: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: bookmarked ? context.scheme.primary : null,
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Solve'),
              Tab(text: 'Submissions'),
              Tab(text: 'Explanation'),
              Tab(text: 'Notes'),
              Tab(text: 'Discussion'),
            ],
          ),
        ),
        body: SafeArea(
          child: RemoteView<PracticeQuestionCubit, PracticeSolveState>(
            onRetry: cubit.load,
            loading: const Padding(
              padding: EdgeInsets.all(16),
              child: AppListSkeleton(rows: 3),
            ),
            builder: (context, state) => TabBarView(
              children: [
                _SolveTab(state: state, onReport: _report, onNavigate: _go),
                _SubmissionsTab(attempts: state.attempts),
                _ExplanationTab(
                  question: state.solutionSource,
                  unlocked: state.hasAttempted,
                ),
                // Scoped by the NoteLinkContext its cubit was built with, up
                // in the router — the tab itself is link-agnostic.
                const MaterialNotesTab(subject: 'question'),
                const DiscussionTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The statement, the answer surface and everything that acts on it.
class _SolveTab extends StatelessWidget {
  const _SolveTab({
    required this.state,
    required this.onReport,
    required this.onNavigate,
  });

  final PracticeSolveState state;
  final void Function(Failure failure) onReport;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeQuestionCubit>();
    final theme = Theme.of(context);
    final question = state.question;
    final submitted = state.submitted;

    Future<void> guard(Future<Failure?> Function() action) async {
      final failure = await action();
      if (failure != null && context.mounted) onReport(failure);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _QuestionHeader(question: question, stats: state.detail.stats),
        if ((question.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          AppMarkdown(question.description),
        ],
        if (question.examples.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Examples', style: theme.textTheme.labelMedium),
          for (final example in question.examples)
            _ExampleCard(example: example),
        ],
        if (question.constraints.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Constraints', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          for (final constraint in question.constraints)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('•  $constraint', style: theme.textTheme.bodySmall),
            ),
        ],
        const SizedBox(height: 18),

        // ── The answer ────────────────────────────────────────────────────
        if (question.isObjective)
          PracticeObjectiveInput(
            question: question,
            selected: state.draft.selectedAnswers,
            onChanged: (ids) =>
                cubit.setDraft(state.draft.copyWith(selectedAnswers: ids)),
          )
        else if (question.isCoding)
          PracticeCodingInput(
            question: question,
            draft: state.draft,
            isRunning: state.isRunning,
            onChanged: cubit.setDraft,
            onRun: () => guard(cubit.run),
            onRunCustom: (stdin) => guard(() => cubit.runCustom(stdin)),
          )
        else
          _SubjectiveInput(
            initial: state.draft.answerText,
            onChanged: (text) =>
                cubit.setDraft(state.draft.copyWith(answerText: text)),
          ),

        if (state.runResult != null) ...[
          const SizedBox(height: 14),
          PracticeCodingResultView(result: state.runResult!),
        ],
        if (state.customResult != null) ...[
          const SizedBox(height: 14),
          _CustomRunView(result: state.customResult!),
        ],

        const SizedBox(height: 16),
        AppButton(
          label: state.isSubmitting ? 'Submitting…' : 'Submit answer',
          icon: Icons.send_rounded,
          expand: true,
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? () => guard(cubit.submit) : null,
        ),

        if (submitted != null) ...[
          const SizedBox(height: 16),
          PracticeResultPanel(
            attempt: submitted,
            question: state.solutionSource,
            onRetry: cubit.retry,
            onClose: cubit.closeResult,
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Random',
                icon: Icons.shuffle_rounded,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                expand: true,
                onPressed:
                    state.isNavigating ? null : () => onNavigate('random'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Next',
                icon: Icons.arrow_forward_rounded,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                expand: true,
                onPressed: state.isNavigating ? null : () => onNavigate('next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.question, required this.stats});

  final PracticeQuestion question;
  final PracticeQuestionStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final difficultyShade = switch (question.difficulty) {
      'easy' => TwColors.teal,
      'hard' => TwColors.red,
      _ => TwColors.amber,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AppBadge(
              question.difficulty[0].toUpperCase() +
                  question.difficulty.substring(1),
              shade: difficultyShade,
              dense: true,
            ),
            AppBadge(_typeLabel(question.type), dense: true),
            AppBadge('${question.points} pts', dense: true),
            if (stats.isSolved)
              AppBadge('Solved', shade: TwColors.emerald, dense: true),
            if (stats.attempts > 0)
              AppBadge('${stats.attempts} attempts', dense: true),
          ],
        ),
      ],
    );
  }

  static String _typeLabel(String type) => switch (type) {
        'mcq' => 'MCQ',
        'true_false' => 'True / False',
        'subjective' => 'Subjective',
        'coding' => 'Coding',
        _ => type,
      };
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final QuestionExample example;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((example.input ?? '').isNotEmpty)
            _Mono(label: 'Input', value: example.input!),
          if ((example.output ?? '').isNotEmpty)
            _Mono(label: 'Output', value: example.output!),
          if ((example.explanation ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(example.explanation!, style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

class _Mono extends StatelessWidget {
  const _Mono({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ', style: Theme.of(context).textTheme.labelSmall),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
}

class _SubjectiveInput extends StatefulWidget {
  const _SubjectiveInput({required this.initial, required this.onChanged});

  final String? initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SubjectiveInput> createState() => _SubjectiveInputState();
}

class _SubjectiveInputState extends State<_SubjectiveInput> {
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
        onChanged: widget.onChanged,
        maxLines: 12,
        minLines: 6,
        decoration: const InputDecoration(
          hintText: 'Write your answer…',
          alignLabelWithHint: true,
        ),
      );
}

class _CustomRunView extends StatelessWidget {
  const _CustomRunView({required this.result});

  final PracticeCustomRunResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final output = result.compileError
        ? (result.stderr ?? 'Compilation error')
        : (result.stdout ?? '');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(result.status, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              output.isEmpty ? '(no output)' : output,
              style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionsTab extends StatelessWidget {
  const _SubmissionsTab({required this.attempts});

  final List<PracticeAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) {
      return const AppEmptyState(
        title: 'No attempts yet',
        description: 'Submit an answer to start building your history.',
        icon: Icons.history_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: attempts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          PracticeAttemptTile(attempt: attempts[index]),
    );
  }
}

/// Hints, explanation and model answer — locked until the student has tried.
///
/// The server is looser than this: it hands the answer key to anyone who asks
/// for the attempt history. The gate is here because handing over the solution
/// before a first attempt would defeat the exercise.
class _ExplanationTab extends StatelessWidget {
  const _ExplanationTab({required this.question, required this.unlocked});

  final PracticeQuestion question;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!unlocked) {
      return const AppEmptyState(
        title: 'Explanation locked',
        description:
            'Submit at least one attempt to unlock the explanation, hints and '
            'the model answer for this question.',
        icon: Icons.lock_outline_rounded,
      );
    }

    final hasAnything = (question.explanation ?? '').isNotEmpty ||
        (question.modelAnswer ?? '').isNotEmpty ||
        question.hints.isNotEmpty;

    if (!hasAnything) {
      return const AppEmptyState(
        title: 'No explanation provided',
        description: 'Your teacher has not added one for this question.',
        icon: Icons.lightbulb_outline_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (question.hints.isNotEmpty) ...[
          Text('Hints', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final (index, hint) in question.hints.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${index + 1}.  $hint',
                  style: theme.textTheme.bodyMedium),
            ),
          const SizedBox(height: 14),
        ],
        if ((question.explanation ?? '').isNotEmpty) ...[
          Text('Explanation', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          AppMarkdown(question.explanation),
          const SizedBox(height: 14),
        ],
        if ((question.modelAnswer ?? '').isNotEmpty) ...[
          Text('Model answer', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          AppMarkdown(question.modelAnswer),
        ],
      ],
    );
  }
}
