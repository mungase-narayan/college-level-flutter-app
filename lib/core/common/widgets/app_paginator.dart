import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_chip.dart';
import '../../network/api_response.dart';

/// Port of the React `TablePagination` — `Showing x–y of n` plus prev/next.
///
/// Most mobile lists here use infinite scroll instead ([AppLoadMoreFooter]);
/// this is for the screens where the React app shows explicit page controls.
class AppPaginator extends StatelessWidget {
  const AppPaginator({super.key, required this.pagination, required this.onPageChanged});

  final Pagination pagination;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pagination.totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final from = ((pagination.page - 1) * pagination.limit) + 1;
    final to = (pagination.page * pagination.limit).clamp(0, pagination.total);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $from–$to of ${pagination.total}',
              style: theme.textTheme.labelSmall,
            ),
          ),
          IconButton(
            onPressed: pagination.page > 1
                ? () => onPageChanged(pagination.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          Text(
            '${pagination.page} / ${pagination.totalPages}',
            style: theme.textTheme.labelMedium,
          ),
          IconButton(
            onPressed: pagination.hasNextPage
                ? () => onPageChanged(pagination.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

/// Footer for an infinite-scrolling list: a spinner while the next page is in
/// flight, an end-of-list note once everything is loaded.
class AppLoadMoreFooter extends StatelessWidget {
  const AppLoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.endLabel = 'That\'s everything',
  });

  final bool isLoading;
  final bool hasMore;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (hasMore) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(endLabel, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

/// A row of filter chips — the mobile form of the React filter bars and status
/// tab strips.
///
/// Scrolls horizontally in a 38pt strip by default, which is right for a filter
/// bar pinned above a list. Set [wrap] when the chips live inside a sheet, where
/// a horizontal scroller hides options behind a gesture nobody looks for.
class AppFilterChips<T> extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.wrap = false,
  });

  final List<AppFilterChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Lays the chips out over multiple lines instead of one scrolling strip, so
  /// every option is visible at once.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);

    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _chip(context, option, scheme: scheme, theme: theme),
        ],
      );
    }

    if (context.useGlass) {
      // Same 38pt strip and same horizontal scroll, so the filter bars above the
      // Courses and Practice lists keep their exact geometry.
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final option = options[index];
            return Center(
              child: LiquidGlassChip(
                label: option.label,
                count: option.count,
                selected: option.value == selected,
                onTap: () => onSelected(option.value),
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return ChoiceChip(
            label: Text(
              option.count == null ? option.label : '${option.label} (${option.count})',
            ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(option.value),
            backgroundColor: scheme.muted,
            selectedColor: scheme.primary.withValues(alpha: 0.16),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: isSelected ? scheme.primary : scheme.mutedForeground,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? scheme.primary.withValues(alpha: 0.4) : Colors.transparent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          );
        },
      ),
    );
  }
}

/// One chip, in whichever style the platform calls for. Shared by both layouts so
/// the wrap and the strip can never drift apart visually.
extension _AppFilterChipBuilder<T> on AppFilterChips<T> {
  Widget _chip(
    BuildContext context,
    AppFilterChipOption<T> option, {
    required SchemeColors scheme,
    required ThemeData theme,
  }) {
    final isSelected = option.value == selected;

    if (context.useGlass) {
      return LiquidGlassChip(
        label: option.label,
        count: option.count,
        selected: isSelected,
        onTap: () => onSelected(option.value),
      );
    }

    return ChoiceChip(
      label: Text(
        option.count == null ? option.label : '${option.label} (${option.count})',
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onSelected(option.value),
      backgroundColor: scheme.muted,
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: isSelected ? scheme.primary : scheme.mutedForeground,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? scheme.primary.withValues(alpha: 0.4) : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }
}

class AppFilterChipOption<T> {
  const AppFilterChipOption({required this.value, required this.label, this.count});

  final T value;
  final String label;
  final int? count;
}
