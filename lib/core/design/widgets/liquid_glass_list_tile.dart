import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_press.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../theme/glass_typography.dart';
import 'liquid_glass_container.dart';

/// A row inside a [LiquidGlassSection].
///
/// Draws no surface of its own — the enclosing section owns the glass and the
/// corner radius, and the rows are separated by hairlines. That is what makes an
/// iOS inset-grouped list read as one continuous pane of glass rather than as a
/// stack of separate cards.
class LiquidGlassListTile extends StatelessWidget {
  const LiquidGlassListTile({
    super.key,
    required this.title,
    this.leading,
    this.leadingIcon,
    this.leadingTint,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.showChevron = false,
    this.destructive = false,
    this.enabled = true,
  });

  final String title;

  /// A custom leading widget. Takes precedence over [leadingIcon].
  final Widget? leading;

  /// Rendered in a rounded tinted square, the way iOS Settings presents its
  /// row icons.
  final IconData? leadingIcon;

  /// Fill colour of the icon square. Defaults to the brand tint.
  final Color? leadingTint;

  final String? subtitle;

  /// A custom trailing widget — typically a [LiquidGlassSwitch].
  final Widget? trailing;

  /// Secondary value shown at the trailing edge, as in Settings' "Version 1.0".
  final String? trailingText;

  final VoidCallback? onTap;

  /// The `›` disclosure indicator. Set for rows that navigate.
  final bool showChevron;

  /// Renders the title and icon in the destructive colour.
  final bool destructive;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    final foreground = destructive ? scheme.destructive : scheme.foreground;
    final subtitle = this.subtitle;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      final tint = leadingTint ?? (destructive ? scheme.destructive : scheme.primary);
      leadingWidget = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: glass.isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(leadingIcon, size: 17, color: tint),
      );
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GlassSpacing.lg,
        vertical: GlassSpacing.md,
      ),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: GlassSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: GlassSpacing.sm),
            // `Flexible`, not a bare `Text`: an unconstrained trailing value takes
            // its full intrinsic width, squeezing the title's `Expanded` toward
            // zero until the title wraps character-by-character. Loose fit means a
            // short value still takes only what it needs, so this costs nothing in
            // the common case and caps a long one at half the row.
            Flexible(
              child: Text(
                trailingText!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.mutedForeground),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: GlassSpacing.sm),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: GlassSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.mutedForeground.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.45, child: row);
    }

    if (onTap == null) return row;

    return GlassPressable(
      onTap: onTap,
      // A row inside a section cannot scale — it would tear away from its
      // neighbours and break the continuous pane. Opacity alone carries the
      // feedback, which is exactly what iOS does for a table row.
      pressedScale: 1.0,
      pressedOpacity: 0.55,
      semanticLabel: title,
      child: row,
    );
  }
}

/// An iOS inset-grouped list section: one pane of glass containing hairline-
/// separated rows, with an optional header above and footer below.
///
/// This is the primary layout of the Settings and Profile screens.
class LiquidGlassSection extends StatelessWidget {
  const LiquidGlassSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.only(bottom: GlassSpacing.xl),
  });

  final List<Widget> children;

  /// Shown above the pane in muted, slightly-tracked type.
  final String? header;

  /// Explanatory text below the pane — the place to put the "why" of a setting.
  final String? footer;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;
    final header = this.header;
    final footer = this.footer;

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(
                left: GlassSpacing.lg,
                right: GlassSpacing.lg,
                bottom: GlassSpacing.sm,
              ),
              child: Text(
                header,
                style: GlassTypography.sectionHeader(scheme.mutedForeground),
              ),
            ),
          LiquidGlassContainer(
            radius: GlassRadius.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0)
                    // Inset from the leading edge so the separator starts where
                    // the text does, as iOS does. Hairline weight, not 1dp.
                    Padding(
                      padding: const EdgeInsets.only(left: GlassSpacing.lg),
                      child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: glass.card.borderColor,
                      ),
                    ),
                  child,
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(
                left: GlassSpacing.lg,
                right: GlassSpacing.lg,
                top: GlassSpacing.sm,
              ),
              child: Text(
                footer,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
