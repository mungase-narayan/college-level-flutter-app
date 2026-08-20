import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/submission.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_grading_usecases.dart';
import '../bloc/submission_review_cubit.dart';
import '../widgets/answer_block.dart';
import '../widgets/proctor_panel.dart';

/// Port of `submission-review.tsx`, as a pushed screen.
///
/// The web splits into resizable panes on a desktop and falls back to a
/// palette strip above one answer at a time on a phone. Only the phone
/// treatment applies here.
///
/// Pops `true` when something was saved, so the overview behind it refetches.
class SubmissionReviewPage extends StatelessWidget {
  const SubmissionReviewPage({
    super.key,
    required this.assessmentId,
    required this.submissionId,
    required this.assessment,
  });

  final String assessmentId;
  final String submissionId;
  final TeacherAssessmentDetail assessment;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubmissionReviewCubit(
        grading: sl<TeacherGradingUseCases>(),
        assessmentId: assessmentId,
        submissionId: submissionId,
        assessment: assessment,
      )..load(),
      child: const _ReviewScaffold(),
    );
  }
}

class _ReviewScaffold extends StatelessWidget {
  const _ReviewScaffold();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SubmissionReviewCubit>();

    return BlocBuilder<SubmissionReviewCubit, SubmissionReviewState>(
      builder: (context, state) {
        final submission = state.submission;

        return Scaffold(
          appBar: AdaptiveAppBar(
            title: submission?.fullName ?? 'Submission',
            actions: [
              if (submission != null && !state.readOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppButton(
                    label: 'Save',
                    size: AppButtonSize.xs,
                    isLoading: state.isSaving,
                    onPressed: () => _save(context, cubit),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            // The question view's pager bar runs to the screen edge and pads
            // itself past the home indicator, the way every other bottom bar in
            // the app does. Holding the inset here instead left a 34pt band of
            // background stranded below the bar.
            bottom: false,
            child: Builder(
              builder: (context) {
                final failure = state.failure;
                if (state.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppListSkeleton(rows: 3, lines: 4),
                  );
                }
                if (failure != null) {
                  return AppErrorView(failure: failure, onRetry: cubit.load);
                }
                if (submission == null) {
                  return const AppEmptyState(
                    icon: Icons.description_outlined,
                    title: 'Submission not found',
                    description: 'It may have been removed.',
                  );
                }

                return cubit.isSubmissionType
                    ? _SubmissionBody(cubit: cubit, state: state)
                    : _QuestionBody(cubit: cubit, state: state);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(
    BuildContext context,
    SubmissionReviewCubit cubit,
  ) async {
    final failure = await cubit.save();
    if (!context.mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Evaluation saved.');
    Navigator.of(context).pop(true);
  }
}

/// The submission-type shape: one note, one score, one feedback box.
class _SubmissionBody extends StatefulWidget {
  const _SubmissionBody({required this.cubit, required this.state});

  final SubmissionReviewCubit cubit;
  final SubmissionReviewState state;

  @override
  State<_SubmissionBody> createState() => _SubmissionBodyState();
}

class _SubmissionBodyState extends State<_SubmissionBody> {
  late final TextEditingController _score =
      TextEditingController(text: widget.state.overallScore);
  late final TextEditingController _feedback =
      TextEditingController(text: widget.state.overallFeedback);

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final cubit = widget.cubit;
    final state = widget.state;
    final note = state.note;
    final totalMarks = cubit.assessment.assessment.totalMarks;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _Details(cubit: cubit, state: state),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'Student submission',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (note?.note ?? '').trim().isEmpty
                    ? 'No written response'
                    : note!.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (note?.note ?? '').trim().isEmpty
                      ? scheme.mutedForeground
                      : scheme.foreground,
                  fontStyle: (note?.note ?? '').trim().isEmpty
                      ? FontStyle.italic
                      : null,
                ),
              ),
              if ((note?.fileIds ?? const []).isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final fileId in note!.fileIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AttachmentTile(fileId: fileId),
                  ),
              ],
            ],
          ),
        ),
        if (!state.readOnly) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Score awarded',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: AppInput(
                  controller: _score,
                  keyboardType: TextInputType.number,
                  onChanged: cubit.setOverallScore,
                ),
              ),
              const SizedBox(width: 8),
              Text('/ $totalMarks', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _feedback,
            label: 'Overall feedback',
            hint: 'Optional',
            minLines: 3,
            maxLines: 6,
            onChanged: cubit.setOverallFeedback,
          ),
        ],
      ],
    );
  }
}

/// The question-type shape: a palette strip over one answer at a time.
class _QuestionBody extends StatelessWidget {
  const _QuestionBody({required this.cubit, required this.state});

  final SubmissionReviewCubit cubit;
  final SubmissionReviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final answers = state.answers;

    if (answers.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [_Details(cubit: cubit, state: state)],
      );
    }

    final index = state.current.clamp(0, answers.length - 1);
    final answer = answers[index];

    return Column(
      children: [
        _Palette(cubit: cubit, state: state, current: index),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              if (state.readOnly) ...[
                _ReadOnlyNotice(),
                const SizedBox(height: 12),
              ],
              AnswerBlock(
                key: ValueKey(answer.id),
                answer: answer,
                index: index,
                mark: state.marks[answer.id] ?? const AnswerMark(),
                readOnly: state.readOnly,
                onScore: (v) => cubit.setScore(answer.id, v),
                onFeedback: (v) => cubit.setFeedback(answer.id, v),
                onCorrect: () => cubit.markCorrect(answer),
                onWrong: () => cubit.markWrong(answer),
              ),
              const SizedBox(height: 18),
              _Details(cubit: cubit, state: state),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: scheme.card,
            border: Border(top: BorderSide(color: scheme.border)),
          ),
          child: Row(
            children: [
              _PagerButton(
                icon: Icons.chevron_left_rounded,
                semanticLabel: 'Previous question',
                onPressed:
                    index > 0 ? () => cubit.setCurrent(index - 1) : null,
              ),
              const SizedBox(width: 12),
              Text(
                '${index + 1}/${answers.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                semanticLabel: 'Next question',
                onPressed: index < answers.length - 1
                    ? () => cubit.setCurrent(index + 1)
                    : null,
              ),
              const Spacer(),
              if (!state.readOnly)
                Text(
                  '${state.awarded}/${state.maxMarks}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.foreground,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A round chevron for the pager bar, sized and toned to match the question
/// palette chips above it so the two read as one navigation system.
class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;

  /// Null at the ends of the list, which greys the button out rather than
  /// hiding it — the row must not reflow as the teacher pages through.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.muted,
            border: Border.all(color: scheme.border),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? scheme.foreground : scheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.tone(TwColors.blue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'This attempt is still in progress — you can see the saved answers '
        'but cannot grade it until the student submits.',
        style: theme.textTheme.labelSmall?.copyWith(color: tone.foreground),
      ),
    );
  }
}

/// The horizontal question strip — the web's own mobile treatment.
class _Palette extends StatelessWidget {
  const _Palette({
    required this.cubit,
    required this.state,
    required this.current,
  });

  final SubmissionReviewCubit cubit;
  final SubmissionReviewState state;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.readOnly
                ? '${cubit.progressCount} of ${state.answers.length} answered'
                : '${cubit.progressCount} of ${state.answers.length} graded',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.answers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _PaletteChip(
                index: i,
                selected: i == current,
                grade: state.readOnly
                    ? (state.answers[i].hasContent
                        ? GradeState.correct
                        : GradeState.ungraded)
                    : cubit.gradeOf(state.answers[i]),
                onTap: () => cubit.setCurrent(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.index,
    required this.selected,
    required this.grade,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final GradeState grade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final shade = switch (grade) {
      GradeState.correct => TwColors.emerald,
      GradeState.partial => TwColors.amber,
      GradeState.wrong => TwColors.rose,
      GradeState.ungraded => TwColors.slate,
    };
    final tone = context.tokens.tone(shade);
    final ungraded = grade == GradeState.ungraded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : ungraded
                  ? scheme.muted
                  : tone.background,
          border: Border.all(
            color: selected
                ? scheme.primary
                : ungraded
                    ? scheme.border
                    : tone.foreground.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '${index + 1}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? scheme.primaryForeground
                : ungraded
                    ? scheme.mutedForeground
                    : tone.foreground,
          ),
        ),
      ),
    );
  }
}

/// The attempt's metadata, plus the proctoring panel when there is one.
class _Details extends StatelessWidget {
  const _Details({required this.cubit, required this.state});

  final SubmissionReviewCubit cubit;
  final SubmissionReviewState state;

  @override
  Widget build(BuildContext context) {
    final submission = state.submission!;
    final assessment = cubit.assessment;
    final detail = state.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (assessment.isProctored && detail != null) ...[
          ProctorPanel(
            detail: detail,
            maxViolations: assessment.maxViolations,
            canReattempt: cubit.canReattempt,
            windowClosed: !state.readOnly && !cubit.windowOpen,
            isReattempting: state.isReattempting,
            onAllowReattempt: () => _reattempt(context),
          ),
          const SizedBox(height: 12),
        ],
        AppSectionCard(
          title: 'Attempt',
          icon: Icons.info_outline_rounded,
          child: Column(
            children: [
              _Row(
                label: 'Status',
                value: SubmissionStatus.label(submission.status),
              ),
              _Row(label: 'Attempt', value: '${submission.attempt}'),
              _Row(
                label: 'Time taken',
                value: Fmt.duration(submission.timeSpentSeconds),
              ),
              if (submission.submittedAt != null)
                _Row(
                  label: 'Submitted',
                  value: Fmt.dateTime(submission.submittedAt),
                ),
              _Row(
                label: 'Total marks',
                value: '${assessment.assessment.totalMarks}',
              ),
              if (submission.isLate) const _Row(label: 'Late', value: 'Yes'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reattempt(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Allow a re-attempt?',
      message: 'The violations are cleared and the student can resume.',
      confirmLabel: 'Allow',
    );
    if (!confirmed || !context.mounted) return;

    final failure = await cubit.allowReattempt();
    if (!context.mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Re-attempt allowed.');
    Navigator.of(context).pop(true);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.labelSmall)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
