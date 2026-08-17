import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/academic_calendar.dart';

/// One month's heading and its entries.
///
/// The month label arrives title case and is uppercased here — the entity holds
/// the data, the widget does the styling, which is the same split the web makes
/// between its `format(…, 'MMMM yyyy')` and its CSS `uppercase`.
class AcademicCalendarMonthSection extends StatelessWidget {
  const AcademicCalendarMonthSection({super.key, required this.month});

  final AcademicCalendarMonth month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            month.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        for (final entry in month.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EntryCard(entry: entry),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final AcademicCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = entry.description;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            AcademicCalendarMeta.typeLabel(entry.type),
            shade: AcademicCalendarMeta.typeShade(entry.type),
            // The web's badge carries a small coloured dot beside the label.
            icon: Icons.circle,
            dense: true,
          ),
          const SizedBox(height: 8),
          Text(entry.title, style: theme.textTheme.titleSmall),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.labelSmall),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: theme.textTheme.labelSmall?.color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.dateRange,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
