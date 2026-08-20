import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/submission.dart';

/// Port of `proctor-report.tsx`.
///
/// Shown only when a proctored attempt has something to report — no
/// violations, no auto-submit and no prior reset means there is nothing here
/// worth a panel.
class ProctorPanel extends StatelessWidget {
  const ProctorPanel({
    super.key,
    required this.detail,
    required this.canReattempt,
    required this.windowClosed,
    required this.isReattempting,
    required this.onAllowReattempt,
    this.maxViolations,
  });

  final SubmissionDetail detail;

  /// The attempt is gradeable and the window is still open.
  final bool canReattempt;

  /// Gradeable, but the window has closed — reopening would achieve nothing.
  final bool windowClosed;

  final bool isReattempting;
  final VoidCallback onAllowReattempt;
  final int? maxViolations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submission = detail.submission;
    final events = detail.proctorEvents;
    final counts = detail.violationsByType;

    if (events.isEmpty &&
        !submission.autoSubmitted &&
        submission.violationResetCount == 0) {
      return const SizedBox.shrink();
    }

    final tone = context.tokens.tone(TwColors.amber);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border.all(color: tone.foreground.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Proctoring · ${events.length} violation'
                  '${events.length == 1 ? '' : 's'}'
                  '${maxViolations == null ? '' : ' of $maxViolations allowed'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (submission.violationResetCount > 0)
                    AppBadge(
                      'Reset ×${submission.violationResetCount}',
                      shade: TwColors.amber,
                      dense: true,
                    ),
                  if (submission.autoSubmitted)
                    const AppBadge(
                      'Auto-submitted',
                      shade: TwColors.amber,
                      dense: true,
                    ),
                ],
              ),
            ],
          ),
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in counts.entries)
                  AppBadge(
                    '${ProctorEventType.label(entry.key)} · ${entry.value}',
                    shade: TwColors.amber,
                    dense: true,
                  ),
              ],
            ),
          ],
          if (canReattempt) ...[
            const SizedBox(height: 12),
            Text(
              'Clear the violations and reopen this attempt so the student '
              'can resume.',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Allow re-attempt',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              expand: true,
              isLoading: isReattempting,
              onPressed: onAllowReattempt,
            ),
          ],
          if (windowClosed) ...[
            const SizedBox(height: 12),
            Text(
              'The window has closed, so this attempt can no longer be '
              'reopened.',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
