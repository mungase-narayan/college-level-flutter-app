import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import 'app_card.dart';

/// The stat tile that opens nearly every dashboard and analytics screen in the
/// React app: an icon chip, a big value, a label, and an optional delta line.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.shade,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TwShade? shade;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final tone = tokens.tone(shade ?? TwColors.violet);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      // `min` so the tile shrink-wraps when it is stacked full width and has no
      // height to fill; the grid gives it a fixed extent instead.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, size: 17, color: tone.foreground),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  // Single line: labels are short ("Solved", "Contest rating"),
                  // and letting one wrap would push the value out of a
                  // fixed-height grid cell.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Flexible + scaleDown so an unexpectedly tall text scale shrinks the
          // number rather than overflowing the cell.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style:
                    theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                caption!,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays stat tiles out in a grid.
///
/// Height is a fixed [tileHeight] rather than an aspect ratio: an aspect ratio
/// derives height from column width, so adding a column silently shrinks every
/// tile until its content overflows. A fixed extent keeps tiles legible at any
/// column count.
///
/// `columns: 1` stacks them full width — which is what the React grids do on a
/// phone (`grid-cols-1 sm:grid-cols-3`).
class AppStatGrid extends StatelessWidget {
  const AppStatGrid({
    super.key,
    required this.tiles,
    this.columns = 2,
    this.tileHeight = 118,
    this.spacing = 12,
  });

  final List<Widget> tiles;
  final int columns;
  final double tileHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            tiles[i],
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tiles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (_, index) => tiles[index],
    );
  }
}

/// A labelled key/value row — the shape every "details" panel uses.
class AppDetailRow extends StatelessWidget {
  const AppDetailRow({super.key, required this.label, required this.value, this.valueWidget});

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: valueWidget ??
                Text(
                  value.isEmpty ? '—' : value,
                  style: theme.textTheme.bodyMedium,
                ),
          ),
        ],
      ),
    );
  }
}
