import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/calendar_entry.dart';

/// The entry detail — the web's `EventDetailsDialog`, presented as this app's
/// sheet. Read-only: students cannot edit or delete anything on the calendar,
/// so the web's footer degrades to a single Close there too.
Future<void> showCalendarEntrySheet(BuildContext context, CalendarEntry entry) {
  return showAppSheet<void>(
    context,
    title: entry.title,
    subtitle: entry.type.label,
    builder: (context) => _CalendarEntryDetails(entry: entry),
  );
}

class _CalendarEntryDetails extends StatelessWidget {
  const _CalendarEntryDetails({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final accent = parseHexColor(entry.accentHex)!;
    final audience = entry.audience;
    final room = entry.room;
    final location = room?.code ?? entry.location;
    final meetingLink = entry.meetingLink;
    final description = entry.description;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The accent card: what kind of thing this is, and when.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(Icons.schedule_rounded, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.type.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEE, d MMM yyyy').format(entry.start),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        entry.isAllDay
                            ? 'All day'
                            : '${DateFormat('h:mm a').format(entry.start)} – '
                                '${DateFormat('h:mm a').format(entry.end)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (entry.recurrenceRule != null)
            AppDetailRow(
              label: 'Repeats',
              value: describeRecurrence(entry.recurrenceRule),
            ),
          if (entry.teacher?.name != null)
            AppDetailRow(label: 'Teacher', value: entry.teacher!.name!),
          if (audience != null)
            AppDetailRow(
              label: 'Audience',
              value: '',
              valueWidget: audience.isSchoolWide
                  ? const AppBadge('Whole school')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final chip in audience.chips) AppBadge(chip),
                      ],
                    ),
            ),
          if (entry.division != null)
            AppDetailRow(label: 'Division', value: entry.division!.display),
          if (entry.course != null)
            AppDetailRow(
              label: 'Course',
              value: [entry.course!.name, entry.course!.code]
                  .whereType<String>()
                  .join(' · '),
            ),
          if (location != null)
            AppDetailRow(
              label: 'Location',
              value: room != null ? room.display : location,
            ),
          if (meetingLink != null)
            AppDetailRow(
              label: 'Meeting link',
              value: meetingLink,
              valueWidget: InkWell(
                onTap: () => _open(context, meetingLink),
                child: Text(
                  meetingLink,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

          if (description != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, 'Could not open this link.');
    }
  }
}

const _dayNames = {
  'MO': 'Mon',
  'TU': 'Tue',
  'WE': 'Wed',
  'TH': 'Thu',
  'FR': 'Fri',
  'SA': 'Sat',
  'SU': 'Sun',
};

/// A readable summary of an RRULE.
///
/// The web runs `RRule.toText()`; there is no equivalent package here, and the
/// rules the backend produces are simple, so this covers FREQ/INTERVAL/BYDAY
/// and falls back to the same `Custom recurrence` string the web uses when it
/// cannot parse one.
String describeRecurrence(String? rule) {
  if (rule == null || rule.trim().isEmpty) return 'Does not repeat';

  final parts = <String, String>{};
  for (final chunk in rule.replaceFirst(RegExp('^RRULE:'), '').split(';')) {
    final pair = chunk.split('=');
    if (pair.length == 2) parts[pair.first.toUpperCase()] = pair.last;
  }

  final freq = parts['FREQ']?.toUpperCase();
  if (freq == null) return 'Custom recurrence';

  final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
  final unit = switch (freq) {
    'DAILY' => interval == 1 ? 'day' : 'days',
    'WEEKLY' => interval == 1 ? 'week' : 'weeks',
    'MONTHLY' => interval == 1 ? 'month' : 'months',
    'YEARLY' => interval == 1 ? 'year' : 'years',
    _ => null,
  };
  if (unit == null) return 'Custom recurrence';

  final buffer = StringBuffer(interval == 1 ? 'Every $unit' : 'Every $interval $unit');

  final byDay = parts['BYDAY'];
  if (byDay != null && byDay.isNotEmpty) {
    final days = byDay
        .split(',')
        .map((day) => _dayNames[day.trim().toUpperCase().replaceAll(RegExp(r'^[+-]?\d+'), '')])
        .whereType<String>()
        .toList();
    if (days.isNotEmpty) buffer.write(' on ${days.join(', ')}');
  }

  final count = int.tryParse(parts['COUNT'] ?? '');
  if (count != null) buffer.write(', $count times');

  return buffer.toString();
}
