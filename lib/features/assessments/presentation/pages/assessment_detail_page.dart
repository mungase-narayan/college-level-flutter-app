import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/assessment_detail.dart';
import '../../domain/entities/student_assessment.dart';
import '../bloc/assessment_detail_cubit.dart';
import '../widgets/attempt_runner.dart';
import '../widgets/attempt_review.dart';

/// Port of `courses/detail/assignments/detail.tsx`.
///
/// One route, four states, chosen from the submission and the attempt window:
/// intro → attempt → review, plus a read-only "closed" variant for a window
/// that lapsed before the student started.
class AssessmentDetailPage extends StatefulWidget {
  const AssessmentDetailPage({super.key, required this.kind});

  /// `Assignment` or `Quiz` — only the copy differs.
  final String kind;

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<AssessmentDetailCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssessmentDetailCubit>();

    return Scaffold(
      appBar: AdaptiveAppBar(title: widget.kind),
      body: SafeArea(
        child: RemoteView<AssessmentDetailCubit, AssessmentDetail>(
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsets.all(16),
            child: AppListSkeleton(rows: 3),
          ),
          builder: (context, detail) {
            switch (detail.viewFor(DateTime.now())) {
              case AssessmentView.review:
                return AttemptReview(detail: detail, kind: widget.kind);
              case AssessmentView.closed:
                return AttemptIntro(
                  detail: detail,
                  kind: widget.kind,
                  onRefresh: () => cubit.load(refresh: true),
                );
              case AssessmentView.attempt:
                return AttemptRunner(detail: detail, kind: widget.kind);
              case AssessmentView.intro:
                return AttemptIntro(
                  detail: detail,
                  kind: widget.kind,
                  onRefresh: () => cubit.load(refresh: true),
                );
            }
          },
        ),
      ),
    );
  }
}

/// Port of `attempt/components/attempt-intro.tsx` — the pre-start screen.
///
/// A gradient hero, a hairline meta grid, a live schedule strip, and the
/// proctoring notice. The clock ticks so "closes in 1d 11h" stays honest and a
/// locked assessment unlocks itself the moment its window opens.
class AttemptIntro extends StatefulWidget {
  const AttemptIntro({
    super.key,
    required this.detail,
    required this.kind,
    required this.onRefresh,
  });

  final AssessmentDetail detail;
  final String kind;
  final Future<void> Function() onRefresh;

  @override
  State<AttemptIntro> createState() => _AttemptIntroState();
}

class _AttemptIntroState extends State<AttemptIntro> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;
    final assessment = widget.detail.assessment;

    final notOpenYet = assessment.notOpenYet(_now);
    final closed = assessment.isWindowClosed(_now);
    final blocked = notOpenYet || closed;

    return RefreshableScroll(
      onRefresh: widget.onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(
            kind: widget.kind,
            assessment: assessment,
            questionCount: widget.detail.questions.length,
          ),
          const SizedBox(height: 12),

          // The question paper, above marks and dates: it is the first thing a
          // student needs, and this screen also serves a window that has closed
          // — so the brief stays readable even once the chance to hand in has
          // gone.
          if (assessment.fileIds.isNotEmpty) ...[
            AppSectionCard(
              title: 'Brief',
              icon: Icons.attach_file_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final fileId in assessment.fileIds)
                    AttachmentTile(fileId: fileId),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          _MetaGrid(
            items: [
              _MetaItem(
                icon: Icons.workspace_premium_outlined,
                label: 'Total marks',
                value: '${assessment.totalMarks}',
              ),
              if (assessment.type == 'questions')
                _MetaItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Questions',
                  value: '${widget.detail.questions.length}',
                ),
              _MetaItem(
                icon: Icons.replay_rounded,
                label: 'Attempts',
                value: assessment.isAllowResubmission
                    ? 'Up to ${assessment.maxAttempt}'
                    : 'Single',
              ),
              _MetaItem(
                icon: Icons.timer_outlined,
                label: 'Time limit',
                value: assessment.durationMinutes == null
                    ? 'None'
                    : '${assessment.durationMinutes} min',
              ),
            ],
          ),
          const SizedBox(height: 12),

          _ScheduleCard(
            assessment: assessment,
            now: _now,
            notOpenYet: notOpenYet,
            closed: closed,
          ),

          if (assessment.isProctored) ...[
            const SizedBox(height: 12),
            _Notice(
              tone: tokens.warning,
              icon: Icons.shield_outlined,
              title: 'This is a proctored ${widget.kind.toLowerCase()}',
              // The mobile equivalent of the web's fullscreen rule: leaving the
              // app is what gets recorded here.
              body: 'Leaving the app, switching away, or copying content is '
                  'recorded as a violation.',
            ),
          ],

          const SizedBox(height: 22),
          AppButton(
            label: notOpenYet
                ? 'Not open yet'
                : closed
                    ? 'Closed'
                    : 'Start ${widget.kind.toLowerCase()}',
            icon: blocked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
            expand: true,
            size: AppButtonSize.lg,
            onPressed: blocked ? null : _start,
          ),
          const SizedBox(height: 10),
          Text(
            blocked
                ? 'You cannot start this ${widget.kind.toLowerCase()} right now.'
                // A submission-type assessment has neither answers nor an
                // autosave — its draft is saved when the student asks.
                : assessment.type == 'questions'
                    ? 'Your answers save automatically as you go.'
                    : 'Draft your response and submit when you are ready.',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final cubit = context.read<AssessmentDetailCubit>();
    final failure = await cubit.start();
    if (!mounted || failure == null) return;
    AppToast.failure(context, failure);
  }
}

/// The gradient title block.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.kind,
    required this.assessment,
    required this.questionCount,
  });

  final String kind;
  final StudentAssessment assessment;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // Compact flat header: icon and title on one line. The "Quiz" chip is gone
    // — the app bar already names the kind, so it was saying it twice.
    final extras = [
      if (assessment.isProctored)
        AppBadge(
          'Proctored',
          shade: TwColors.amber,
          icon: Icons.shield_outlined,
          dense: true,
        ),
      if (assessment.isLateSubmissionAllowed)
        AppBadge(
          'Late −${assessment.latePenalty}%',
          shade: TwColors.slate,
          dense: true,
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  kind == 'Quiz'
                      ? Icons.checklist_rounded
                      : Icons.assignment_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assessment.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Only the badges that carry information the header doesn't.
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: extras),
          ],
          if ((assessment.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            AppMarkdown(assessment.description),
          ],
        ],
      ),
    );
  }
}

class _MetaItem {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Two-per-row cells separated by hairlines — the React
/// `gap-px bg-border/60` grid.
class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.items});

  final List<_MetaItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final rows = <List<_MetaItem>>[
      for (var i = 0; i < items.length; i += 2) items.skip(i).take(2).toList(),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) Divider(height: 1, color: scheme.border.withValues(alpha: 0.6)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _MetaCell(item: rows[r][0])),
                  if (rows[r].length > 1) ...[
                    VerticalDivider(
                      width: 1,
                      color: scheme.border.withValues(alpha: 0.6),
                    ),
                    Expanded(child: _MetaCell(item: rows[r][1])),
                  ] else
                    // Keeps a lone cell at half width so the grid stays even.
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.item});

  final _MetaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 13, color: scheme.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Opens / Due, plus the live window strip.
///
/// Dates get their own full-width rows because a formatted timestamp is far
/// too long for a half-width grid cell.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.assessment,
    required this.now,
    required this.notOpenYet,
    required this.closed,
  });

  final StudentAssessment assessment;
  final DateTime now;
  final bool notOpenYet;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final (tone, label) = _window(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                _ScheduleRow(
                  icon: Icons.event_available_outlined,
                  label: 'Opens',
                  value: Fmt.dateTime(assessment.startDate),
                ),
                const SizedBox(height: 12),
                _ScheduleRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Due',
                  value: Fmt.dateTime(assessment.endDate),
                ),
              ],
            ),
          ),
          // The live strip — this is what the 1 s clock keeps current.
          Container(
            width: double.infinity,
            color: tone.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tone.foreground,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: tone.foreground),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (StatusTone, String) _window(BuildContext context) {
    final tokens = context.tokens;

    if (notOpenYet) {
      final start = DateTime.tryParse(assessment.startDate ?? '')?.toLocal();
      final left = start == null ? Duration.zero : start.difference(now);
      return (tokens.warning, 'Opens in ${Fmt.duration(left.inSeconds)}');
    }
    if (closed) {
      return (tokens.danger, 'Submission window closed');
    }

    final end = DateTime.tryParse(assessment.endDate ?? '')?.toLocal();
    if (end != null && !assessment.isLateSubmissionAllowed) {
      final left = end.difference(now);
      return (tokens.success, 'Open now — closes in ${Fmt.duration(left.inSeconds)}');
    }
    return (tokens.success, 'Open now');
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // Label above value rather than a right-aligned pair: a formatted
    // timestamp is too long to share a row and was being ellipsised away.
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 16, color: scheme.mutedForeground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style:
                    theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tinted callout — the proctoring and window banners.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: tone.foreground),
                ),
                const SizedBox(height: 3),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
