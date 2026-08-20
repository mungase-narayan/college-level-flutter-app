import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/student_assessment.dart';

/// Port of `courses/detail/components/assessment-board.tsx`.
///
/// Groups items by submission status into Not Started → In Progress →
/// Submitted → Evaluated and renders **only the non-empty sections**.
///
/// A 1-second clock drives the "Opens in / closes in" countdowns so a card
/// flips from locked to open without the student refreshing.
class AssessmentBoard extends StatefulWidget {
  const AssessmentBoard({
    super.key,
    required this.items,
    required this.kind,
    this.onOpen,
  });

  final List<StudentAssessment> items;

  /// `Quiz` or `Assignment` — used in the row labels and empty copy.
  final String kind;
  final ValueChanged<StudentAssessment>? onOpen;

  @override
  State<AssessmentBoard> createState() => _AssessmentBoardState();
}

class _AssessmentBoardState extends State<AssessmentBoard> {
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
    final grouped = <String, List<StudentAssessment>>{};
    for (final item in widget.items) {
      grouped.putIfAbsent(item.statusKey, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final status in AssessmentStatus.order)
          if (grouped[status]?.isNotEmpty ?? false) ...[
            _SectionHeader(status: status, count: grouped[status]!.length),
            const SizedBox(height: 10),
            for (final item in grouped[status]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AssessmentCard(
                  item: item,
                  now: _now,
                  kind: widget.kind,
                  onTap: () => widget.onOpen?.call(item),
                ),
              ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

/// `STATUS_META` — tinted icon chip, label, count pill, and hint.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.status, required this.count});

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final (shade, icon) = switch (status) {
      AssessmentStatus.notStarted => (TwColors.slate, Icons.schedule_rounded),
      AssessmentStatus.inProgress => (TwColors.amber, Icons.timer_outlined),
      AssessmentStatus.submitted => (TwColors.blue, Icons.send_rounded),
      _ => (TwColors.emerald, Icons.verified_rounded),
    };
    final tone = tokens.tone(shade);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 16, color: tone.foreground),
        ),
        const SizedBox(width: 10),
        Text(AssessmentStatus.label(status), style: theme.textTheme.titleSmall),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: context.scheme.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count', style: theme.textTheme.labelSmall),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            AssessmentStatus.hint(status),
            style: theme.textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.item,
    required this.now,
    required this.kind,
    required this.onTap,
  });

  final StudentAssessment item;
  final DateTime now;
  final String kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final outcome = item.outcomeText();
    final window = _windowStatus(context);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.isProctored) ...[
                const SizedBox(width: 8),
                AppBadge('Proctored', shade: TwColors.amber, dense: true),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge('${item.totalMarks} marks', dense: true),
              if (item.durationMinutes != null)
                AppBadge('${item.durationMinutes} min', dense: true),
              if (item.endDate != null)
                AppBadge('Due ${Fmt.dmy(item.endDate)}', dense: true),
            ],
          ),

          // The live window row — this is what the 1 s clock keeps current.
          // The state and the countdown are separate elements: a tinted pill
          // says *what* the window is doing, the text beside it says *when*.
          if (window != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: window.tone.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: window.tone.foreground,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        window.label,
                        style: TextStyle(
                          color: window.tone.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (window.detail != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      window.detail!,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  outcome,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: outcome.contains('/')
                        ? tokens.success.foreground
                        : scheme.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                item.actionText(now),
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  /// Port of `notStartedStatus` — only meaningful before an attempt starts.
  ///
  /// Returns the window *state* and the *timing* separately so the card can
  /// render them as two elements instead of one run-on sentence.
  _WindowStatus? _windowStatus(BuildContext context) {
    if (item.statusKey != AssessmentStatus.notStarted) return null;
    final tokens = context.tokens;

    if (item.notOpenYet(now)) {
      final start = DateTime.tryParse(item.startDate ?? '')?.toLocal();
      final left = start == null ? Duration.zero : start.difference(now);
      return _WindowStatus(
        tone: tokens.warning,
        label: 'Not open',
        detail: 'Opens in ${Fmt.duration(left.inSeconds)}',
      );
    }

    if (item.isWindowClosed(now)) {
      return _WindowStatus(tone: tokens.danger, label: 'Closed');
    }

    if (item.isLateSubmissionAllowed) {
      return _WindowStatus(
        tone: tokens.success,
        label: 'Open',
        detail: 'Late submission allowed',
      );
    }

    final end = DateTime.tryParse(item.endDate ?? '')?.toLocal();
    if (end != null) {
      final left = end.difference(now);
      return _WindowStatus(
        tone: tokens.success,
        label: 'Open',
        detail: 'Closes in ${Fmt.duration(left.inSeconds)}',
      );
    }

    return _WindowStatus(tone: tokens.success, label: 'Open');
  }
}

/// The window state of a not-yet-started assessment.
class _WindowStatus {
  const _WindowStatus({required this.tone, required this.label, this.detail});

  final StatusTone tone;

  /// The pill: Open · Not open · Closed.
  final String label;

  /// The countdown beside it, when there is one.
  final String? detail;
}
