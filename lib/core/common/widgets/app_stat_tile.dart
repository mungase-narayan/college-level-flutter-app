import 'dart:math' as math;

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

  /// From three columns up, a phone leaves too little beside the icon.
  static const _stackFromColumns = 3;

  /// Wraps to two lines only when stacked: the tile is narrow there, and a
  /// wrapped label reads far better than a truncated one. Beside the icon it
  /// stays on one line, where wrapping would push the value out of the row's
  /// shared height.
  Widget _label(ThemeData theme, bool stacked) => Text(
        label,
        style: theme.textTheme.labelSmall,
        maxLines: stacked ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final tone = tokens.tone(shade ?? TwColors.violet);
    final stacked = _StatTileLayout.stackedOf(context);

    final badge = icon == null
        ? null
        : Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 17, color: tone.foreground),
          );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      // `min` so the tile is exactly as tall as its content. The grid sizes its
      // rows from that, then stretches the shorter tiles in a row to match the
      // tallest — so a caption on one tile no longer costs every other tile in
      // the grid an empty band.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beside the icon when there is room, stacked under it when there is
          // not. At three columns on a phone a side-by-side label is left with
          // roughly 40pt, which turns "Attempts" into "Atte…" — the label is
          // what names the number, so it is the wrong half to clip.
          //
          // The grid decides, not a LayoutBuilder: the grid shares row heights
          // through IntrinsicHeight, and a LayoutBuilder cannot report an
          // intrinsic height, so measuring here would throw at layout.
          if (badge == null)
            _label(theme, stacked)
          else if (stacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [badge, const SizedBox(height: 8), _label(theme, true)],
            )
          else
            Row(
              children: [
                badge,
                const SizedBox(width: 10),
                Expanded(child: _label(theme, false)),
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

/// Published by [AppStatGrid] so a tile knows how much room it has without
/// measuring — see the note in [AppStatTile.build].
class _StatTileLayout extends InheritedWidget {
  const _StatTileLayout({required this.stacked, required super.child});

  final bool stacked;

  static bool stackedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_StatTileLayout>()
          ?.stacked ??
      false;

  @override
  bool updateShouldNotify(_StatTileLayout old) => old.stacked != stacked;
}

/// Lays stat tiles out in a grid.
///
/// Rows size to their **content**, never to an aspect ratio: an aspect ratio
/// derives height from column width, so adding a column silently shrinks every
/// tile until its content overflows. Sizing from content keeps tiles legible at
/// any column count *and* stops a tile without a caption from carrying the
/// empty band a captioned one needs — which read as a layout bug on the course
/// detail screen, where none of the five tiles has a caption.
///
/// Tiles in the same row still share one height, so a caption on one of them
/// lines the whole row up rather than leaving a ragged edge.
///
/// `columns: 1` stacks them full width — which is what the React grids do on a
/// phone (`grid-cols-1 sm:grid-cols-3`).
///
/// A last row that doesn't fill its columns stretches to the full width instead
/// of leaving a hole beside it. Three tiles in two columns is the common case —
/// a real grid would leave the third stranded at half width next to dead space,
/// which reads as a missing card rather than as a deliberate layout.
class AppStatGrid extends StatelessWidget {
  const AppStatGrid({
    super.key,
    required this.tiles,
    this.columns = 2,
    this.spacing = 12,
  });

  final List<Widget> tiles;
  final int columns;
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

    // Rows rather than a GridView: a grid reserves every cell in the last row,
    // so a trailing tile that doesn't fill its columns leaves visible dead
    // space. Laying rows out by hand lets the last one expand to fill.
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      final end = math.min(start + columns, tiles.length);
      final rowTiles = tiles.sublist(start, end);

      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        // IntrinsicHeight so the row is exactly as tall as its tallest tile,
        // and `stretch` so the shorter ones match it instead of floating.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rowTiles.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: rowTiles[i]),
              ],
            ],
          ),
        ),
      );
    }

    return _StatTileLayout(
      stacked: columns >= AppStatTile._stackFromColumns,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
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
