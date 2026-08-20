import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/attendance_session.dart';

/// The roster, one student per row with a four-way segmented control.
///
/// A segmented control rather than a dropdown: marking is the whole job of this
/// screen, and every extra tap is paid once per student.
class RosterMarker extends StatelessWidget {
  const RosterMarker({
    super.key,
    required this.records,
    required this.marks,
    required this.readOnly,
    required this.startIndex,
    required this.onMark,
  });

  final List<AttendanceRecord> records;
  final Map<String, String> marks;
  final bool readOnly;

  /// Running number across pages, so row 11 reads "11" and not "1".
  final int startIndex;
  final void Function(String studentId, String status) onMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _StudentRow(
            record: records[i],
            number: startIndex + i + 1,
            selected: marks[records[i].studentId] ?? MarkStatus.present,
            readOnly: readOnly,
            onMark: (status) => onMark(records[i].studentId, status),
          ),
        ],
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.record,
    required this.number,
    required this.selected,
    required this.readOnly,
    required this.onMark,
  });

  final AttendanceRecord record;
  final int number;
  final String selected;
  final bool readOnly;
  final ValueChanged<String> onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final subtitle = record.subtitle;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$number',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              AppAvatar(
                imageUrl: record.avatar,
                name: record.fullName,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fullName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < MarkStatus.options.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _MarkButton(
                    status: MarkStatus.options[i],
                    isSelected: selected == MarkStatus.options[i],
                    enabled: !readOnly,
                    onTap: () => onMark(MarkStatus.options[i]),
                  ),
                ),
              ],
            ],
          ),
          if (readOnly && !record.isMarked) ...[
            const SizedBox(height: 6),
            Text(
              // Honest about the difference: a finalized session can still
              // contain students nobody marked.
              'Not marked',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.status,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String status;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(MarkStatus.shade(status));

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? tone.background : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? tone.foreground : scheme.border,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Text(
            MarkStatus.label(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected ? tone.foreground : scheme.mutedForeground,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
