import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/teacher_course.dart';

/// The section switcher that scopes the whole course-detail screen.
///
/// One instance for all seven tabs, matching the web's single `<Select>` in the
/// tab bar — every tab below reads whatever this resolves, and changing it
/// reloads the tree and rescopes attendance, assessments and every create body.
class DivisionSelector extends StatelessWidget {
  const DivisionSelector({
    super.key,
    required this.divisions,
    required this.selected,
    required this.onChanged,
  });

  final List<CourseDivision> divisions;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 17,
            color: scheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text('Section', style: theme.textTheme.labelSmall),
          const SizedBox(width: 12),
          Expanded(
            child: AppSelect<String>(
              value: selected.isEmpty ? null : selected,
              hint: 'Select section',
              items: [
                for (final division in divisions)
                  AppSelectItem<String>(
                    value: division.id,
                    label: division.label,
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
