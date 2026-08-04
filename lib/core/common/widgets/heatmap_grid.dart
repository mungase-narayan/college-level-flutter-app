import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/heatmap_calendar.dart';

/// One day's activity count, matching the API's
/// `heatmap.days[] = { date: "YYYY-MM-DD", count: n }`.
class HeatmapDay {
  const HeatmapDay({required this.date, required this.count});

  final String date;
  final int count;

  factory HeatmapDay.fromJson(Map<String, dynamic> json) => HeatmapDay(
        date: json['date'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Port of the React `HeatmapGrid` — the GitHub-style contribution grid on the
/// student dashboard and public profile.
///
/// Rows are weekdays (Sunday at the top), columns are weeks, and the grid is
/// grouped into labelled month blocks that scroll horizontally so a full year fits
/// on a phone. Opens on the most recent month.
///
/// **Nothing after today is drawn.** The API returns whole months including days
/// still to come, so the remaining weekdays of the current week render as empty
/// placeholders rather than as zero-activity days. See [HeatmapCalendar.layout].
///
/// Stateful purely to precompute: the month layout and the date→count index are
/// derived once per data change in [didUpdateWidget], not on every rebuild. The
/// dashboard rebuilds for scroll, theme and refresh, and a year is twelve month
/// layouts plus ~365 map entries each time.
class HeatmapGrid extends StatefulWidget {
  const HeatmapGrid({
    super.key,
    required this.days,
    this.cell = 14,
    this.gap = 3,
    this.monthGap = 10,
    this.showMonthLabels = true,
    this.onDayTap,
    this.today,
  });

  final List<HeatmapDay> days;
  final double cell;

  /// Space between cells, both axes.
  final double gap;

  /// Extra space between month blocks, on top of [gap]. This separation is what
  /// makes the months legible as groups rather than one continuous field.
  final double monthGap;

  final bool showMonthLabels;
  final ValueChanged<HeatmapDay>? onDayTap;

  /// Overrides "now". Injected by tests so the grid's boundary behaviour is
  /// deterministic; production leaves it null and reads the clock.
  final DateTime? today;

  @override
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid> {
  late Map<String, HeatmapDay> _byDate;
  late List<HeatmapMonth> _months;
  late int _max;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Layout depends only on the data and the reference date; the visual params
    // (cell, gap, labels) do not change which days exist.
    if (oldWidget.days != widget.days || oldWidget.today != widget.today) {
      _recompute();
    }
  }

  void _recompute() {
    _byDate = {for (final d in widget.days) d.date: d};
    _max = widget.days.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    final parsed = widget.days
        .map((d) => DateTime.tryParse(d.date))
        .whereType<DateTime>()
        .map(HeatmapCalendar.dateOnly)
        .toList()
      ..sort();

    if (parsed.isEmpty) {
      _months = const [];
      return;
    }

    _months = HeatmapCalendar.layout(
      first: parsed.first,
      last: parsed.last,
      today: widget.today ?? DateTime.now(),
    );
  }

  /// Cells are squares with a soft corner, proportional so the grid can be scaled.
  double get _radius => (widget.cell * 0.28).clamp(2.0, 6.0);

  /// Width of one month's slot: its columns, plus the separation to the next
  /// month. Shared by the grid row and the label row so the two cannot drift.
  double _slotWidth(HeatmapMonth month, {required bool isLast}) =>
      month.columns * widget.cell +
      (month.columns - 1) * widget.gap +
      (isLast ? 0 : widget.gap + widget.monthGap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.days.isEmpty) {
      return Text('No activity yet', style: theme.textTheme.bodySmall);
    }
    if (_months.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // open on the most recent month
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Without this the grid claims the full viewport height whenever the
        // incoming height is bounded, because a horizontally scrolling viewport
        // passes its cross axis straight through.
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two sibling rows rather than a label nested under each block. Both are
          // built from the same per-block slot widths, so the axis is aligned with
          // its columns by construction — a label's own width can never feed back
          // into the grid's layout and shift it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, month) in _months.indexed)
                SizedBox(
                  width: _slotWidth(month, isLast: i == _months.length - 1),
                  child: _MonthColumns(
                    month: month,
                    byDate: _byDate,
                    max: _max,
                    cell: widget.cell,
                    gap: widget.gap,
                    radius: _radius,
                    onDayTap: widget.onDayTap,
                  ),
                ),
            ],
          ),
          if (widget.showMonthLabels) ...[
            SizedBox(height: widget.gap + 5),
            Row(
              children: [
                for (final (i, month) in _months.indexed)
                  SizedBox(
                    width: _slotWidth(month, isLast: i == _months.length - 1),
                    // Centred over the block's columns, as in the web app. Where the
                    // slot is wide enough — every full month — the label centres
                    // properly; a one-column partial month is narrower than its own
                    // label, so it anchors left and paints past the slot instead of
                    // widening it and dragging every other month out of line.
                    child: Center(
                      child: Text(
                        Fmt.monthShort(month.month),
                        style: theme.textTheme.labelSmall,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One month's week columns.
class _MonthColumns extends StatelessWidget {
  const _MonthColumns({
    required this.month,
    required this.byDate,
    required this.max,
    required this.cell,
    required this.gap,
    required this.radius,
    required this.onDayTap,
  });

  final HeatmapMonth month;
  final Map<String, HeatmapDay> byDate;
  final int max;
  final double cell;
  final double gap;
  final double radius;
  final ValueChanged<HeatmapDay>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var col = 0; col < month.columns; col++)
          Padding(
            padding: EdgeInsets.only(right: col == month.columns - 1 ? 0 : gap),
            child: Column(
              children: [
                for (var row = 0; row < 7; row++)
                  Padding(
                    padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
                    child: _cell(scheme, col: col, row: row),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(SchemeColors scheme, {required int col, required int row}) {
    final date = month.dateAt(column: col, row: row);

    // Not a day this block paints: an adjacent month's day, or a date after today.
    // An invisible spacer, so every row stays on its own weekday and the week the
    // grid stops in keeps its shape.
    if (!month.renders(date)) {
      return SizedBox(width: cell, height: cell);
    }

    final key = Fmt.isoDate(date);
    final day = byDate[key];

    final square = Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: heatmapLevelColor(scheme, day?.count ?? 0, max),
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return GestureDetector(
      onTap: day == null || onDayTap == null ? null : () => onDayTap!(day),
      child: Tooltip(
        message: '${day?.count ?? 0} on ${Fmt.dmy(key)}',
        child: square,
      ),
    );
  }
}

/// Five intensity buckets, scaled to the busiest day so a light user still sees
/// contrast.
///
/// Shared with [HeatmapLegend] so the key can never drift from the grid it
/// describes.
Color heatmapLevelColor(SchemeColors scheme, int count, int max) {
  if (count <= 0) return scheme.muted;
  final ratio = max <= 1 ? 1.0 : count / max;
  final alpha = switch (ratio) {
    <= 0.25 => 0.30,
    <= 0.5 => 0.50,
    <= 0.75 => 0.72,
    _ => 1.0,
  };
  return scheme.primary.withValues(alpha: alpha);
}

/// The `Less ▢▢▢▢ More` key rendered beneath the grid.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key, this.swatch = 14, this.gap = 3});

  /// Matches [HeatmapGrid.cell] by default so the key reads as the same material
  /// as the grid rather than as a separate control.
  final double swatch;
  final double gap;

  /// The alpha ladder [heatmapLevelColor] produces, lowest to highest.
  static const _alphas = [0.0, 0.30, 0.50, 0.72, 1.0];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);
    final radius = (swatch * 0.28).clamp(2.0, 6.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: theme.textTheme.labelSmall),
        SizedBox(width: gap + 3),
        for (final (i, alpha) in _alphas.indexed)
          Padding(
            padding: EdgeInsets.only(
              right: i == _alphas.length - 1 ? 0 : gap,
            ),
            child: Container(
              width: swatch,
              height: swatch,
              decoration: BoxDecoration(
                color: alpha == 0
                    ? scheme.muted
                    : scheme.primary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        SizedBox(width: gap + 3),
        Text('More', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
