import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../calendar/domain/entities/calendar_entry.dart';
import '../../../calendar/presentation/bloc/today_sessions_cubit.dart';

/// Port of `today-sessions-card.tsx` — today's timetable as a live tracker
/// followed by the rest of the day as a timeline.
///
/// The web hides this below `lg` to keep the mobile dashboard compact; here it
/// is on the phone by request, so it sits directly under the daily challenge
/// where the desktop's right-hand column begins.
///
/// Ticks every 30 seconds so "in progress" and the countdowns stay honest
/// without refetching — the data does not change, only the clock does.
class TodaySessionsCard extends StatefulWidget {
  const TodaySessionsCard({super.key});

  @override
  State<TodaySessionsCard> createState() => _TodaySessionsCardState();
}

class _TodaySessionsCardState extends State<TodaySessionsCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    context.read<TodaySessionsCubit>().load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Opens the calendar on the session's own day, in the day view.
  void _open(CalendarEntry session) =>
      context.push('/student/calendar?date=${Fmt.isoDate(session.start)}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = context.read<TodaySessionsCubit>().day;

    return BlocBuilder<TodaySessionsCubit, RemoteState<List<CalendarEntry>>>(
      builder: (context, state) {
        final sessions = state.data ?? const <CalendarEntry>[];
        final doneCount =
            sessions.where((s) => phaseOf(s, _now) == SessionPhase.done).length;

        // A failed load says nothing useful on a dashboard card, so it reads as
        // an empty day rather than an error the student cannot act on.
        final isLoading = state.isInitialLoading;

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                day: day,
                doneCount: doneCount,
                total: sessions.length,
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppListSkeleton(rows: 3, lines: 1),
                )
              else if (sessions.isEmpty)
                const _EmptyDay()
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: _Tracker(sessions: sessions, now: _now),
                ),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, session) in sessions.indexed)
                        _TimelineRow(
                          session: session,
                          phase: phaseOf(session, _now),
                          isLast: i == sessions.length - 1,
                          onTap: () => _open(session),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.day,
    required this.doneCount,
    required this.total,
  });

  final DateTime day;
  final int doneCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 7),
                    // Flexible so a large accessibility text scale ellipsises
                    // the title rather than overflowing the header row.
                    Flexible(
                      child: Text(
                        "Today's sessions",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMM').format(day),
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$doneCount/$total done',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.muted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(
              Icons.local_cafe_outlined,
              size: 22,
              color: scheme.mutedForeground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Text('No classes today', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Nothing is scheduled on your timetable. A good window to clear '
            'pending work or practice.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Whatever is running right now — or the next thing, or "all done".
class _Tracker extends StatelessWidget {
  const _Tracker({required this.sessions, required this.now});

  final List<CalendarEntry> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final live = sessions
        .where((s) => phaseOf(s, now) == SessionPhase.live)
        .firstOrNull;
    final next = sessions
        .where((s) => phaseOf(s, now) == SessionPhase.upcoming)
        .firstOrNull;

    if (live != null) {
      final total = live.end.difference(live.start).inMilliseconds;
      final elapsed = now.difference(live.start).inMilliseconds;
      final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
      final emerald = TwColors.emerald.s500;

      // A plain tinted box: the web's `border-l-4` accent edge is dropped by
      // request. Keep the border uniform — Flutter refuses to paint a
      // non-uniform one under a borderRadius, and the throw lands after the
      // background fill, leaving a green rectangle with nothing in it.
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: emerald.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: emerald.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _PulseDot(color: emerald),
                const SizedBox(width: 8),
                Text(
                  'IN PROGRESS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_gap(live.end.difference(now))} left',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              live.course?.name ?? live.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaBit(
                  icon: Icons.schedule_rounded,
                  label: '${_time(live.start)} – ${_time(live.end)}',
                ),
                if (live.room?.code case final room? when room.isNotEmpty)
                  _MetaBit(icon: Icons.meeting_room_outlined, label: room),
                if (live.teacher?.name case final teacher?
                    when teacher.isNotEmpty)
                  _MetaBit(icon: Icons.person_outline_rounded, label: teacher),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: emerald.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(emerald),
              ),
            ),
          ],
        ),
      );
    }

    if (next != null) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.muted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UP NEXT',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              next.course?.name ?? next.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Starts at ${_time(next.start)} · in '
              '${_gap(next.start.difference(now))}',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: TwColors.emerald.s500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All ${sessions.length} sessions done for today.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The web's `animate-ping` halo around the live dot.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - _controller.value) * 0.7,
              child: Container(
                width: 10 * (1 + _controller.value),
                height: 10 * (1 + _controller.value),
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            child!,
          ],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MetaBit extends StatelessWidget {
  const _MetaBit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.textTheme.labelSmall?.color),
        const SizedBox(width: 3),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// One row of the day's timeline: a rail dot, the class, and its start time.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.session,
    required this.phase,
    required this.isLast,
    required this.onTap,
  });

  final CalendarEntry session;
  final SessionPhase phase;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final isDone = phase == SessionPhase.done;

    final dotColor = switch (phase) {
      SessionPhase.done => scheme.mutedForeground.withValues(alpha: 0.3),
      SessionPhase.live => TwColors.emerald.s500,
      SessionPhase.upcoming => scheme.primary,
    };

    final meta = [
      session.course?.code,
      session.room?.code ?? session.room?.name,
      session.teacher?.name,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    // The web's `ring-4` sits *outside* the dot; a Border here
                    // eats into it and leaves a 4px speck instead.
                    boxShadow: [
                      BoxShadow(
                        color: phase == SessionPhase.live
                            ? TwColors.emerald.s500.withValues(alpha: 0.15)
                            : scheme.card,
                        spreadRadius: 3.5,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 2),
                      color: scheme.border.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 2 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            session.course?.name ?? session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isDone ? scheme.mutedForeground : null,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              decorationColor:
                                  scheme.mutedForeground.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _time(session.start),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.isEmpty ? _time(session.end) : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime value) =>
    DateFormat('h:mm a').format(value).toUpperCase();

/// `1h 05m` / `42m` — compact enough for the live line.
String _gap(Duration duration) {
  final minutes = duration.isNegative ? 0 : (duration.inSeconds / 60).round();
  final hours = minutes ~/ 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}
