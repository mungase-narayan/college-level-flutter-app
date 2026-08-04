import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// A compact glass capsule — status badge, filter pill, or metadata tag.
///
/// Serves both roles the Material kit splits across `AppBadge` (static status)
/// and `AppFilterChips` (interactive selection): pass [onTap] and [selected] for
/// the latter, omit them for the former.
///
/// [tone] accepts the same [TwShade] values `AppBadge` uses, so the semantic
/// colour mapping already established across the app (emerald = active/present,
/// amber = pending, red = archived/hard) carries over unchanged.
class LiquidGlassChip extends StatelessWidget {
  const LiquidGlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.tone,
    this.dense = false,
    this.count,
  });

  final String label;
  final IconData? icon;

  /// Filter chips only: fills the capsule with the brand tint.
  final bool selected;

  final VoidCallback? onTap;

  /// Semantic status colour. Ignored when [selected], which always wins.
  final TwShade? tone;

  /// Tighter padding and a smaller label, for chips inside a dense list row.
  final bool dense;

  /// A trailing count, as used by the courses and practice filter bars.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    final statusTone = tone == null ? null : context.tokens.tone(tone!);

    final (spec, foreground) = switch ((selected, statusTone)) {
      // Selection wins over status: a selected filter must read as selected.
      (true, _) => (
          glass.card.copyWith(
            tint: scheme.primary.withValues(alpha: glass.isDark ? 0.34 : 0.16),
            borderColor: scheme.primary.withValues(alpha: 0.55),
            highlightColor: scheme.primary.withValues(alpha: 0.40),
          ),
          scheme.primary,
        ),
      (false, final tone?) => (
          glass.control.copyWith(
            tint: tone.background,
            borderColor: tone.foreground.withValues(alpha: 0.28),
            highlightColor: tone.foreground.withValues(alpha: 0.22),
          ),
          tone.foreground,
        ),
      (false, null) => (glass.control, scheme.mutedForeground),
    };

    final labelStyle = (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
        ?.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    final chip = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1.0 : 0.0),
      duration: glass.duration(GlassDurations.fast),
      curve: GlassCurves.easeOutSmooth,
      builder: (context, t, _) => LiquidGlassContainer(
        // Interpolating toward the selected spec makes tapping through a filter
        // bar feel continuous rather than like a series of hard swaps.
        spec: t == 0 || t == 1
            ? spec
            : GlassSpec.lerp(glass.control, spec, t),
        radius: GlassRadius.capsule,
        showShadow: false,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? GlassSpacing.sm + 2 : GlassSpacing.md,
          vertical: dense ? 3 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 12 : 14, color: foreground),
              const SizedBox(width: GlassSpacing.xs + 2),
            ],
            Text(label, style: labelStyle),
            if (count != null) ...[
              const SizedBox(width: GlassSpacing.xs + 1),
              Text(
                '$count',
                style: labelStyle?.copyWith(
                  color: foreground.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return chip;

    return GlassPressable(
      onTap: onTap,
      pressedScale: 0.94,
      borderRadius: BorderRadius.circular(GlassRadius.capsule),
      child: Semantics(selected: selected, child: chip),
    );
  }
}

/// A horizontally wrapping row of filter chips — the glass counterpart to
/// `AppFilterChips`.
class LiquidGlassChipBar<T> extends StatelessWidget {
  const LiquidGlassChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<LiquidGlassChipOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: GlassSpacing.sm,
      runSpacing: GlassSpacing.sm,
      children: [
        for (final option in options)
          LiquidGlassChip(
            label: option.label,
            count: option.count,
            selected: option.value == selected,
            // Re-tapping the active chip clears the filter, matching the
            // behaviour of the Material `AppFilterChips`.
            onTap: () =>
                onSelected(option.value == selected ? null : option.value),
          ),
      ],
    );
  }
}

class LiquidGlassChipOption<T> {
  const LiquidGlassChipOption({
    required this.value,
    required this.label,
    this.count,
  });

  final T? value;
  final String label;
  final int? count;
}
