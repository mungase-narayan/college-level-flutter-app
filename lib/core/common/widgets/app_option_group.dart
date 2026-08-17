import 'package:flutter/material.dart';

import 'app_button.dart';

import '../../config/theme/app_theme.dart';
import '../../design/animations/glass_press.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/theme/glass_specs.dart';
import '../../design/theme/glass_typography.dart';
import '../../design/widgets/liquid_glass_container.dart';
import '../../design/widgets/liquid_glass_list_tile.dart';

/// One row of an [AppOptionGroup].
class AppOptionItem<T> {
  const AppOptionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });

  final T value;
  final String label;

  /// Shown in a tinted rounded square at the leading edge, the way iOS Settings
  /// presents its row icons. A glanceable second cue beside the label.
  final IconData? icon;

  /// A second line under the label, for an option whose name does not carry its
  /// whole meaning.
  final String? description;
}

/// A single-select list of options presented as one inset-grouped pane.
///
/// This is the iOS idiom for "pick exactly one of these" inside a sheet — the
/// shape of Files' *Sort By* and Mail's filter list — and it replaces the row of
/// pill chips the filter sheets used to carry. Chips are a Material pattern that
/// reads as a *toolbar* of independent toggles; a checkmark list says only one
/// value can be active, gives every option the full width of the sheet (so no
/// label has to be shortened to fit a pill), and grows to any number of options
/// without wrapping into ragged lines.
///
/// [T] is normally nullable, because the "no filter" option ("All", "Any
/// difficulty") carries `null` as its value.
class AppOptionGroup<T> extends StatelessWidget {
  const AppOptionGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.header,
    this.footer,
  });

  final List<AppOptionItem<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Muted label above the pane.
  final String? header;

  /// Explanatory text below the pane.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) return _glass(context);
    return _material(context);
  }

  Widget _glass(BuildContext context) {
    final scheme = context.scheme;

    return LiquidGlassSection(
      header: header,
      footer: footer,
      // Filter sheets stack several of these; the default gap leaves the panes
      // reading as separate screens rather than one list.
      margin: const EdgeInsets.only(bottom: GlassSpacing.md),
      children: [
        for (final option in options)
          Semantics(
            selected: option.value == selected,
            inMutuallyExclusiveGroup: true,
            child: LiquidGlassListTile(
              title: option.label,
              leadingIcon: option.icon,
              subtitle: option.description,
              onTap: () => onSelected(option.value),
              // The checkmark alone carries selection, as it does in a grouped
              // iOS list — tinting the label too would read as a link.
              trailing: option.value == selected
                  ? Icon(Icons.check_rounded, size: 20, color: scheme.primary)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final header = this.header;
    final footer = this.footer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                header,
                style: GlassTypography.sectionHeader(scheme.mutedForeground),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: scheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, option) in options.indexed) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, indent: 16, color: scheme.border),
                  InkWell(
                    onTap: () => onSelected(option.value),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(i == 0 ? AppTheme.radiusLg : 0),
                      bottom: Radius.circular(
                        i == options.length - 1 ? AppTheme.radiusLg : 0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          if (option.icon != null) ...[
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                option.icon,
                                size: 17,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(option.label, style: theme.textTheme.bodyMedium),
                                if (option.description != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    option.description!,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (option.value == selected)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(footer, style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

/// A full-width row that performs an action, styled as its own grouped pane —
/// the "Reset" / "Clear All" row iOS puts at the foot of a filter sheet.
class AppOptionActionRow extends StatelessWidget {
  const AppOptionActionRow({
    super.key,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Renders in the destructive colour, for a row that discards something.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final enabled = onPressed != null;
    final tint = destructive ? scheme.destructive : scheme.primary;
    final color =
        enabled ? tint : scheme.mutedForeground.withValues(alpha: 0.55);

    final label = Text(
      this.label,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );

    if (context.useGlass) {
      // Built from the primitive rather than from a list tile: the row's whole
      // content is one centred label, and a tile lays its slots out from the
      // leading edge.
      return LiquidGlassContainer(
        radius: GlassRadius.lg,
        child: GlassPressable(
          onTap: onPressed,
          // A row-shaped pane cannot scale without tearing away from the groups
          // above it; opacity carries the press, as it does for a table row.
          pressedScale: 1.0,
          pressedOpacity: 0.55,
          semanticLabel: this.label,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Center(child: label),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
        child: label,
      ),
    );
  }
}

/// The two buttons every filter sheet ends with.
///
/// They live at the foot rather than in the sheet's toolbar: on a tall phone
/// the top corners are the hardest part of the display to reach, and these are
/// the buttons the sheet exists to have pressed. Reset takes the place a Cancel
/// button would occupy — dismissing is already a swipe away, while clearing the
/// filters is the thing a user actually wants a button for.
class AppFilterActions extends StatelessWidget {
  const AppFilterActions({super.key, required this.onReset, required this.onApply});

  /// Null when there is nothing to clear, which disables the button rather than
  /// implying otherwise.
  final VoidCallback? onReset;

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Reset',
              variant: AppButtonVariant.outline,
              expand: true,
              onPressed: onReset,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: 'Apply',
              expand: true,
              // The confirming action on the right, where iOS puts it.
              onPressed: onApply,
            ),
          ),
        ],
      ),
    );
  }
}
