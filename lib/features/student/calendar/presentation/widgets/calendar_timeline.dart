import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';

/// The hours the web's grid renders, and the height of one hour row.
const int kDayStartHour = 7;
const int kDayEndHour = 21;
const double kHourHeight = 56;
const double _gutterWidth = 56;
const double _minBlockHeight = 22;

/// The Day and Week grids — one `TimelineView` on the web, with Day passing a
/// single column.
class CalendarTimeline extends StatefulWidget {
  const CalendarTimeline({
    super.key,
    required this.days,
    required this.entriesOn,
    required this.onTapEntry,
    this.bottomPadding = 0,
  });

  final List<DateTime> days;
  final List<CalendarEntry> Function(DateTime day) entriesOn;
  final ValueChanged<CalendarEntry> onTapEntry;
  final double bottomPadding;

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline> {
  ScrollController? _controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final now = DateTime.now();

    final byDay = {
      for (final day in widget.days) day: widget.entriesOn(day),
    };

    // The web hard-codes 07:00–21:00 and lets anything outside scroll out of
    // sight. Widening the window to cover the outliers costs nothing on the
    // usual day and means an 06:30 lab is never simply invisible.
    var firstHour = kDayStartHour;
    var lastHour = kDayEndHour;
    for (final entries in byDay.values) {
      for (final entry in entries) {
        firstHour = firstHour < entry.start.hour ? firstHour : entry.start.hour;
        final endHour = entry.end.minute > 0 ? entry.end.hour + 1 : entry.end.hour;
        lastHour = lastHour > endHour ? lastHour : endHour;
      }
    }
    lastHour = lastHour > 23 ? 23 : lastHour;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 07:00–21:00 is 784pt, shorter than the viewport now that the header
        // is one row. Rather than leave a dead band under the last hour, grow
        // the window outwards until it fills the screen — every added row is a
        // real hour, so it stays a calendar rather than padding.
        final headerHeight = widget.days.length > 1 ? 54.0 : 0.0;
        final visible =
            ((constraints.maxHeight - headerHeight) / kHourHeight).floor();
        while (lastHour - firstHour < visible && (lastHour < 23 || firstHour > 0)) {
          if (lastHour < 23) {
            lastHour++;
          } else {
            firstHour--;
          }
        }

        final gridHeight = (lastHour - firstHour) * kHourHeight;
        _controller ??= ScrollController(
          initialScrollOffset: _initialOffset(now, firstHour, gridHeight),
        );

        return _build(context, theme, scheme, now, byDay, firstHour, lastHour,
            gridHeight);
      },
    );
  }

  Widget _build(
    BuildContext context,
    ThemeData theme,
    SchemeColors scheme,
    DateTime now,
    Map<DateTime, List<CalendarEntry>> byDay,
    int firstHour,
    int lastHour,
    double gridHeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Week needs column labels; in Day view the single "SUN 16" only
        // repeats the range title above it, so it keeps its space instead.
        if (widget.days.length > 1)
          _DayHeaderRow(days: widget.days, today: now),
        Expanded(
          child: SingleChildScrollView(
            controller: _controller,
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: SizedBox(
              height: gridHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _gutterWidth,
                    child: _HourGutter(
                      firstHour: firstHour,
                      lastHour: lastHour,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: scheme.border.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: _DayColumn(
                          day: day,
                          entries: byDay[day] ?? const [],
                          firstHour: firstHour,
                          lastHour: lastHour,
                          now: now,
                          onTapEntry: widget.onTapEntry,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens near the current hour when today is on screen, so the grid doesn't
  /// land on an empty 7 AM.
  double _initialOffset(DateTime now, int firstHour, double gridHeight) {
    final hasToday = widget.days.any((day) => CalendarDates.isSameDay(day, now));
    if (!hasToday) return 0;
    final offset = (now.hour - firstHour - 1) * kHourHeight;
    return offset.clamp(0.0, gridHeight);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({required this.days, required this.today});

  final List<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _gutterWidth),
          for (final day in days)
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CalendarDates.isSameDay(day, today)
                          ? scheme.primary
                          : Colors.transparent,
                    ),
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: CalendarDates.isSameDay(day, today)
                            ? scheme.primaryForeground
                            : scheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  const _HourGutter({
    required this.firstHour,
    required this.lastHour,
    required this.style,
  });

  final int firstHour;
  final int lastHour;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var hour = firstHour; hour <= lastHour; hour++)
          Positioned(
            top: (hour - firstHour) * kHourHeight - 7,
            right: 8,
            child: Text(
              // The first label would collide with the top edge, exactly as on
              // the web, where it is left blank.
              hour == firstHour
                  ? ''
                  : DateFormat('h a').format(DateTime(2000, 1, 1, hour)),
              style: style,
            ),
          ),
      ],
    );
  }
}

/// One day's hour rows, positioned blocks, and the current-time line.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.entries,
    required this.firstHour,
    required this.lastHour,
    required this.now,
    required this.onTapEntry,
  });

  final DateTime day;
  final List<CalendarEntry> entries;
  final int firstHour;
  final int lastHour;
  final DateTime now;
  final ValueChanged<CalendarEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final placements = layoutDay(entries, day);
    final isToday = CalendarDates.isSameDay(day, now);
    final nowMinutes = now.hour * 60 + now.minute;
    final showNow =
        isToday && nowMinutes >= firstHour * 60 && nowMinutes <= lastHour * 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var hour = firstHour; hour < lastHour; hour++)
              Positioned(
                top: (hour - firstHour) * kHourHeight,
                left: 0,
                right: 0,
                height: kHourHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            for (final placement in placements)
              Positioned(
                top: _topOf(placement),
                left: width * (placement.lane / placement.lanes) + 2,
                width: width / placement.lanes - 4,
                height: _heightOf(placement),
                child: CalendarTimelineBlock(
                  entry: placement.entry,
                  height: _heightOf(placement),
                  // Seven columns on a phone leave ~45pt each, where
                  // "9:00 AM – 10:00 AM" is just a clipped smear.
                  dense: width / placement.lanes < 88,
                  onTap: () => onTapEntry(placement.entry),
                ),
              ),
            if (showNow)
              Positioned(
                top: (nowMinutes - firstHour * 60) / 60 * kHourHeight,
                left: -3,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Expanded(
                      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  double _topOf(CalendarPlacement placement) =>
      (placement.startMinutes - firstHour * 60) / 60 * kHourHeight;

  double _heightOf(CalendarPlacement placement) {
    final raw = (placement.endMinutes - placement.startMinutes) / 60 * kHourHeight;
    return raw < _minBlockHeight ? _minBlockHeight : raw - 2;
  }
}

/// One entry's slot in a day column.
class CalendarPlacement {
  CalendarPlacement(this.entry, this.startMinutes, this.endMinutes);

  final CalendarEntry entry;
  final int startMinutes;
  final int endMinutes;
  int lane = 0;
  int lanes = 1;
}

/// Assigns overlapping entries to side-by-side lanes.
///
/// Entries are swept in start order into the first free lane; a cluster of
/// mutually overlapping entries then shares the cluster's lane count so they
/// come out the same width. Port of `layoutDay` in `timeline-view.tsx`.
List<CalendarPlacement> layoutDay(List<CalendarEntry> entries, DateTime day) {
  final placements = [
    for (final entry in entries)
      CalendarPlacement(entry, entry.startMinutesOn(day), entry.endMinutesOn(day)),
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  final cluster = <CalendarPlacement>[];
  var clusterEnd = -1;

  void closeCluster() {
    if (cluster.isEmpty) return;
    final lanes = cluster.fold<int>(1, (max, p) => p.lane + 1 > max ? p.lane + 1 : max);
    for (final placement in cluster) {
      placement.lanes = lanes;
    }
    cluster.clear();
  }

  for (final placement in placements) {
    if (placement.startMinutes >= clusterEnd) {
      closeCluster();
      clusterEnd = placement.endMinutes;
    } else if (placement.endMinutes > clusterEnd) {
      clusterEnd = placement.endMinutes;
    }

    var lane = 0;
    while (cluster.any((other) =>
        other.lane == lane && other.endMinutes > placement.startMinutes)) {
      lane++;
    }
    placement.lane = lane;
    cluster.add(placement);
  }
  closeCluster();

  return placements;
}

/// A positioned entry in the day/week grid: a tinted card with a time strip.
class CalendarTimelineBlock extends StatelessWidget {
  const CalendarTimelineBlock({
    super.key,
    required this.entry,
    required this.height,
    required this.onTap,
    this.dense = false,
  });

  final CalendarEntry entry;
  final double height;
  final VoidCallback onTap;

  /// A narrow column — drop the meridiem and the end time.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = parseHexColor(entry.accentHex)!;
    final compact = height < 46;
    final subtitle = entry.subtitle;

    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.20),
                  border: Border(
                    bottom: BorderSide(color: accent.withValues(alpha: 0.55)),
                  ),
                ),
                child: Text(
                  dense
                      ? DateFormat('h:mm').format(entry.start)
                      : compact
                          ? _time(entry.start)
                          : '${_time(entry.start)} – ${_time(entry.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              // A one-hour block is 54pt tall, which the title and subtitle
              // together can just exceed. Letting the text lay out at its
              // natural height and clipping the remainder keeps short blocks
              // readable without a debug overflow stripe across them.
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!compact && subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime value) => DateFormat('h:mm a').format(value);
}
