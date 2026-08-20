import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../domain/entities/academic_calendar.dart';

/// The calendar's own card: what it is, who it is for, and the download.
///
/// A plain [AppCard] rather than [AppSectionCard], which would put the download
/// in the title row and squeeze it against a long title on a phone. The web
/// stacks them too — `flex-col` until `sm`, with the button full-width below.
class AcademicCalendarHeader extends StatelessWidget {
  const AcademicCalendarHeader({
    super.key,
    required this.calendar,
    required this.onDownload,
  });

  final AcademicCalendar calendar;

  /// Offered even when the calendar has no entries, as on the web — the export
  /// is what tells the student there is nothing to print.
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final scope = calendar.scope;
    final termRange = calendar.termRange;
    final description = calendar.description;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(calendar.displayTitle, style: theme.textTheme.titleMedium),
          if (scope.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(scope, style: theme.textTheme.bodySmall),
          ],
          if (termRange != null) ...[
            const SizedBox(height: 2),
            Text('Term: $termRange', style: theme.textTheme.labelSmall),
          ],
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Download',
            variant: AppButtonVariant.outline,
            icon: Icons.file_download_outlined,
            expand: true,
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}
