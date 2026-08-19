import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/leaderboard.dart';

/// Scope chips with the period folded into a single filter button beside them.
///
/// The web spends a whole row on a period dropdown. On a phone that row is too
/// expensive for one control, so period moves behind the filter button and the
/// active value stays readable in the "Your rank" subtitle below.
class LeaderboardToolbar extends StatelessWidget {
  const LeaderboardToolbar({
    super.key,
    required this.scope,
    required this.period,
    required this.onScopeChanged,
    required this.onPeriodChanged,
  });

  final String scope;
  final String period;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onPeriodChanged;

  Future<void> _pickPeriod(BuildContext context) async {
    final picked = await showAppSheet<String>(
      context,
      title: 'Period',
      builder: (sheetContext) => AppOptionGroup<String>(
        selected: period,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
        options: [
          for (final option in LeaderboardPeriod.options)
            AppOptionItem(value: option, label: LeaderboardPeriod.label(option)),
        ],
      ),
    );
    if (picked != null) onPeriodChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: AppFilterChips<String>(
              selected: scope,
              onSelected: onScopeChanged,
              wrap: true,
              options: [
                for (final option in LeaderboardScope.options)
                  AppFilterChipOption(
                    value: option,
                    label: LeaderboardScope.label(option),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            // A dot marks a period other than the default, so a narrowed board
            // is never silently narrowed.
            isActive: period != LeaderboardPeriod.defaultPeriod,
            onTap: () => _pickPeriod(context),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Semantics(
      button: true,
      label: 'Filter by period',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? scheme.primary.withValues(alpha: 0.10) : scheme.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? scheme.primary.withValues(alpha: 0.45) : scheme.border,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: isActive ? scheme.primary : scheme.mutedForeground,
              ),
              if (isActive)
                Positioned(
                  right: -2,
                  top: -1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.card, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
