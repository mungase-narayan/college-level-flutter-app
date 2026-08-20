import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';

/// Port of `AssessmentViewDialog` — the read-only detail.
///
/// Opened by tapping a row, which is what the web does; the results screen is
/// reached through the row menu instead.
Future<void> showAssessmentViewSheet(
  BuildContext context, {
  required String assessmentId,
}) =>
    showAppSheet<void>(
      context,
      title: 'Details',
      builder: (_) => _AssessmentView(assessmentId: assessmentId),
    );

class _AssessmentView extends StatefulWidget {
  const _AssessmentView({required this.assessmentId});

  final String assessmentId;

  @override
  State<_AssessmentView> createState() => _AssessmentViewState();
}

class _AssessmentViewState extends State<_AssessmentView> {
  TeacherAssessmentDetail? _detail;
  Failure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await sl<TeacherAssessmentUseCases>().getDetail(widget.assessmentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((f) => _failure = f, (d) {
        _failure = null;
        _detail = d;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppListSkeleton(rows: 4, lines: 2);
    final failure = _failure;
    if (failure != null) return AppErrorView(failure: failure, onRetry: _load);

    final detail = _detail!;
    final a = detail.assessment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(detail: detail),
        const SizedBox(height: 14),
        _Window(startDate: a.startDate, endDate: a.endDate),
        const SizedBox(height: 12),
        _Numbers(detail: detail),
        const SizedBox(height: 12),
        _Rules(detail: detail),
        if (a.isQuestionType) ...[
          const SizedBox(height: 18),
          _Questions(questions: detail.questions),
        ],
        if (detail.fileIds.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            'Attachments',
            trailing: '${detail.fileIds.length}',
          ),
          const SizedBox(height: 8),
          for (final id in detail.fileIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AttachmentTile(fileId: id),
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final TeacherAssessmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = detail.assessment;
    final description = (a.description ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.title, style: theme.textTheme.titleMedium),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AppBadge(
              AssessmentStatus.label(a.status),
              shade: AssessmentStatus.shade(a.status),
              dense: true,
            ),
            AppBadge(
              AssessmentCategory.label(a.category),
              shade: AssessmentCategory.shade(a.category),
              dense: true,
            ),
            AppBadge(
              AssessmentType.label(a.type),
              shade: AssessmentType.shade(a.type),
              dense: true,
            ),
            if (a.isSemesterWide) const AppBadge('Semester-wide', dense: true),
            if (a.resultsPublished)
              const AppBadge(
                'Results published',
                shade: TwColors.emerald,
                dense: true,
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens → Due as one strip.
///
/// The old layout put these on two unrelated rows, which hid the thing a
/// teacher actually reads them for: how long the paper is open.
class _Window extends StatelessWidget {
  const _Window({required this.startDate, required this.endDate});

  final String startDate;
  final String endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final span = _span(startDate, endDate);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Endpoint(label: 'Opens', iso: startDate),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: scheme.mutedForeground,
                ),
              ),
              Expanded(
                child: _Endpoint(label: 'Due', iso: endDate, alignEnd: true),
              ),
            ],
          ),
          if (span != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 13,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text('Open for $span', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// How long the window is, in the coarsest unit that still reads honestly.
  /// Null when either end is unparseable or the dates are inverted.
  static String? _span(String from, String to) {
    final start = DateTime.tryParse(from);
    final end = DateTime.tryParse(to);
    if (start == null || end == null) return null;

    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return null;
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    if (hours < 24) {
      final rest = minutes % 60;
      return rest == 0 ? '$hours hr' : '$hours hr $rest min';
    }
    final days = hours ~/ 24;
    return days == 1 ? '1 day' : '$days days';
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.iso,
    this.alignEnd = false,
  });

  final String label;
  final String iso;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final align = alignEnd ? TextAlign.end : TextAlign.start;

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall, textAlign: align),
        const SizedBox(height: 3),
        Text(
          Fmt.dmy(iso),
          textAlign: align,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.foreground,
          ),
        ),
        Text(Fmt.time(iso), style: theme.textTheme.labelSmall, textAlign: align),
      ],
    );
  }
}

/// The numbers a teacher scans for, as tiles rather than another label row.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.detail});

  final TeacherAssessmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final a = detail.assessment;
    final duration = detail.durationMinutes;

    return AppStatGrid(
      columns: 3,
      tiles: [
        AppStatTile(
          label: 'Marks',
          // The server owns this for a question paper, so it is summed from
          // the attached questions rather than echoed back.
          value: '${detail.derivedTotalMarks}',
          icon: Icons.star_outline_rounded,
          caption: a.passingMarks == null ? null : 'pass ${a.passingMarks}',
        ),
        AppStatTile(
          label: 'Attempts',
          value: '${detail.maxAttempt}',
          icon: Icons.repeat_rounded,
          shade: TwColors.blue,
        ),
        // A time limit is a quiz concept; an assignment has none to show.
        if (duration != null && duration > 0)
          AppStatTile(
            label: 'Time limit',
            // The unit rides in the value rather than a caption: a caption on
            // one tile stretches the whole row, leaving the other two with a
            // dead band under their numbers.
            value: '$duration min',
            icon: Icons.timer_outlined,
            shade: TwColors.amber,
          ),
      ],
    );
  }
}

/// The on/off rules, as chips.
///
/// Nine label rows spent a full line each on "Not allowed"; a chip that is
/// simply absent says the same thing in no space at all.
class _Rules extends StatelessWidget {
  const _Rules({required this.detail});

  final TeacherAssessmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = <Widget>[
      if (detail.isLateSubmissionAllowed)
        AppBadge(
          detail.latePenalty > 0
              ? 'Late allowed · −${detail.latePenalty}%'
              : 'Late allowed',
          icon: Icons.schedule_rounded,
          shade: TwColors.amber,
          dense: true,
        ),
      if (detail.isAllowResubmission)
        const AppBadge(
          'Resubmission',
          icon: Icons.refresh_rounded,
          shade: TwColors.blue,
          dense: true,
        ),
      if (detail.isProctored)
        AppBadge(
          detail.maxViolations == null
              ? 'Proctored'
              : 'Proctored · max ${detail.maxViolations}',
          icon: Icons.shield_outlined,
          shade: TwColors.violet,
          dense: true,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Rules'),
        const SizedBox(height: 8),
        if (rules.isEmpty)
          Text(
            'No late submission, no resubmission, not proctored.',
            style: theme.textTheme.labelSmall,
          )
        else
          Wrap(spacing: 6, runSpacing: 6, children: rules),
      ],
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.questions});

  final List<AssessmentQuestionRow> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = questions.fold<int>(0, (sum, q) => sum + (q.points ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Questions',
          trailing: questions.isEmpty
              ? '0'
              : '${questions.length} · $points pts',
        ),
        const SizedBox(height: 8),
        if (questions.isEmpty)
          Text(
            'No questions added yet.',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontStyle: FontStyle.italic),
          )
        else
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuestionCard(question: questions[i], number: i + 1),
            ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.number});

  final AssessmentQuestionRow question;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final difficulty = question.difficulty;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered, so the order the students will see is legible.
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.title ?? 'Untitled question',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (question.type != null)
                      AppBadge(QuestionType.label(question.type!), dense: true),
                    if (difficulty != null)
                      AppBadge(
                        QuestionDifficulty.label(difficulty),
                        shade: QuestionDifficulty.shade(difficulty),
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${question.points ?? 0} pt',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// An uppercase caption with an optional count on the right, so the sheet's
/// sections read as sections instead of running together.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: scheme.border, height: 1)),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Text(trailing!, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}
