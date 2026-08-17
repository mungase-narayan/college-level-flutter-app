import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';
import '../bloc/calendar_cubit.dart';
import '../widgets/calendar_entry_sheet.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/calendar_timeline.dart';
import '../widgets/calendar_year_view.dart';
import '../widgets/timetable_pdf.dart';

/// Port of `CalendarView` mounted as `role="student"` — the student's live
/// timetable and events, read-only.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// What the open sheet has staged so far — nothing reaches the grid until
  /// Apply, so a dismissed sheet leaves no trace. The same arrangement the
  /// Quizzes and Practice filter sheets use.
  final _draft = ValueNotifier(
    const _CalendarOptions(view: CalendarViewMode.day, filter: CalendarFilter.all),
  );

  @override
  void initState() {
    super.initState();
    context.read<CalendarCubit>().load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _openOptions(CalendarCubit cubit) async {
    _draft.value = _CalendarOptions(
      view: cubit.state.view,
      filter: cubit.state.filter,
    );

    // Cancel and Apply sit at the foot of the sheet rather than in its toolbar:
    // on a tall phone the top corners are the hardest place to reach, and these
    // are the two buttons this sheet exists to have pressed.
    final applied = await showAppSheet<_CalendarOptions>(
      context,
      title: 'Filters',
      builder: (context) => _OptionsSheet(draft: _draft),
    );
    if (applied == null || !mounted) return;

    // Filter first: it is client-side, so applying it before the view change
    // means the one refetch lands with the right filter already set.
    cubit.setFilter(applied.filter);
    await cubit.setView(applied.view);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CalendarCubit>();
    final bottomInset = context.glassContentInsets.bottom;

    return StudentScaffold(
      child: BlocBuilder<CalendarCubit, CalendarState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              state: state,
              cubit: cubit,
              onOptions: () => _openOptions(cubit),
            ),
            Expanded(child: _Body(state: state, bottomInset: bottomInset)),
          ],
        ),
      ),
    );
  }
}

/// The view and the type filter, staged together.
class _CalendarOptions {
  const _CalendarOptions({required this.view, required this.filter});

  final CalendarViewMode view;
  final CalendarFilter filter;

  _CalendarOptions copyWith({CalendarViewMode? view, CalendarFilter? filter}) =>
      _CalendarOptions(view: view ?? this.view, filter: filter ?? this.filter);
}

/// The view and the type filter, in one sheet.
///
/// The web spends two full rows on these — a segmented switcher and a scrolling
/// pill strip — which on a phone is most of the space above the grid. Both are
/// pick-one lists, so they collapse into the inset-grouped panes this app
/// already uses for exactly that.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.draft});

  static const _viewIcons = {
    CalendarViewMode.day: Icons.view_day_outlined,
    CalendarViewMode.week: Icons.view_week_outlined,
    CalendarViewMode.month: Icons.calendar_month_outlined,
    CalendarViewMode.year: Icons.calendar_today_outlined,
  };

  static const _filterIcons = {
    CalendarFilter.all: Icons.grid_view_rounded,
    CalendarFilter.classes: Icons.school_outlined,
    CalendarFilter.event: Icons.star_outline_rounded,
    CalendarFilter.meeting: Icons.groups_outlined,
    CalendarFilter.task: Icons.check_box_outlined,
  };

  final ValueNotifier<_CalendarOptions> draft;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_CalendarOptions>(
      valueListenable: draft,
      // No scroll view and no padding of its own: `showAppSheet` already wraps
      // the body in `Flexible(SingleChildScrollView(...))` on both branches, so
      // adding either here would nest a second scrollable and inset the panes
      // twice.
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppOptionGroup<CalendarViewMode>(
            header: 'View',
            selected: value.view,
            onSelected: (view) => draft.value = value.copyWith(view: view),
            options: [
              for (final view in CalendarViewMode.values)
                AppOptionItem(
                  value: view,
                  label: view.label,
                  icon: _viewIcons[view],
                ),
            ],
          ),
          AppOptionGroup<CalendarFilter>(
            header: 'Show',
            selected: value.filter,
            onSelected: (filter) => draft.value = value.copyWith(filter: filter),
            options: [
              for (final filter in CalendarFilter.values)
                AppOptionItem(
                  value: filter,
                  label: filter.label,
                  icon: _filterIcons[filter],
                ),
            ],
          ),
          AppFilterActions(
            // The view is not a filter, so Reset clears only what "Show" holds.
            onReset: value.filter == CalendarFilter.all
                ? null
                : () => draft.value = value.copyWith(filter: CalendarFilter.all),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}

/// Range title, Today, the arrows, and the view switcher.
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.cubit,
    required this.onOptions,
  });

  final CalendarState state;
  final CalendarCubit cubit;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final isFiltered = state.filter != CalendarFilter.all;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rangeTitle(state.view, state.date),
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // With the switcher and the filter strip both folded into the
                // sheet, this line is what says which of them is active.
                Text(
                  '${state.view.label} · ${state.filter.label}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isFiltered ? scheme.primary : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // The only progress indicator the web shows, kept for the same
          // reason: paging keeps the old grid, so this is the sole hint that a
          // fetch is running.
          if (state.isFetching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // Student-only on the web too — teachers and admins get no export
          // from this screen.
          _HeaderIcon(
            icon: Icons.file_download_outlined,
            tooltip: "Download the week's timetable (Mon–Fri) as PDF",
            onPressed: () => _downloadTimetable(context, cubit),
          ),
          _HeaderIcon(
            icon: Icons.tune_rounded,
            tooltip: 'View and filter',
            // Tinted while filtered, so a thin grid never looks unexplained.
            tinted: isFiltered,
            onPressed: onOptions,
          ),
          _HeaderIcon(
            icon: Icons.today_rounded,
            tooltip: 'Today',
            onPressed: cubit.goToToday,
          ),
          _HeaderIcon(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous',
            onPressed: () => cubit.shift(-1),
          ),
          _HeaderIcon(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next',
            onPressed: () => cubit.shift(1),
          ),
        ],
      ),
    );
  }
}

/// One of the five actions in the header. Compact so all five and the range
/// title share a single row on a phone.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tinted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 21,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(icon, color: tinted ? scheme.primary : null),
    );
  }
}

/// Builds and hands over the week's class timetable.
Future<void> _downloadTimetable(BuildContext context, CalendarCubit cubit) async {
  final auth = context.read<AuthBloc>().state;
  final user = auth.user;
  final fullName = user?.fullName?.trim() ?? '';
  final name = fullName.isNotEmpty
      ? fullName
      : [user?.firstName, user?.lastName]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' ');

  final weekDays = CalendarDates.rangeFor(
    CalendarViewMode.week,
    cubit.state.date,
  ).days;

  final entries = await cubit.weekEntries();
  if (!context.mounted) return;
  if (entries == null) {
    AppToast.error(context, 'Could not load this week’s timetable.');
    return;
  }

  final built = await shareWeekTimetablePdf(
    entries: entries,
    weekDays: weekDays,
    schoolName: auth.school?.name ?? 'Weekly Timetable',
    personName: name,
  );
  if (!context.mounted || built) return;
  AppToast.error(context, 'No classes scheduled for this week.');
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.bottomInset});

  final CalendarState state;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AppListSkeleton(rows: 4),
      );
    }

    // A failure with nothing cached is the only case that replaces the grid;
    // otherwise the last-known entries stay and the failure is transient.
    if (state.status == RemoteStatus.failure && state.entries.isEmpty) {
      return AppErrorView(
        failure: state.failure!,
        onRetry: context.read<CalendarCubit>().load,
      );
    }

    void openEntry(CalendarEntry entry) =>
        showCalendarEntrySheet(context, entry);

    final cubit = context.read<CalendarCubit>();

    return switch (state.view) {
      CalendarViewMode.day ||
      CalendarViewMode.week =>
        _TimelineBody(state: state, bottomInset: bottomInset, onTap: openEntry),
      CalendarViewMode.month => Padding(
          padding: const EdgeInsets.only(left: 12, right: 16),
          child: Builder(
            builder: (context) {
              // Six weeks of cells would each re-scan the whole month, so
              // group once here instead.
              final byDay = <String, List<CalendarEntry>>{};
              for (final entry in state.visibleEntries) {
                final key = '${entry.start.year}-${entry.start.month}-'
                    '${entry.start.day}';
                byDay.putIfAbsent(key, () => []).add(entry);
              }
              return CalendarMonthView(
                month: state.date,
                days: state.range.days,
                entriesOn: (day) =>
                    byDay['${day.year}-${day.month}-${day.day}'] ?? const [],
                onTapDay: cubit.openDay,
                onTapEntry: openEntry,
                bottomPadding: bottomInset,
              );
            },
          ),
        ),
      CalendarViewMode.year => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: CalendarYearView(
            year: state.date.year,
            entries: state.visibleEntries,
            onTapMonth: cubit.openMonth,
            bottomPadding: bottomInset,
          ),
        ),
    };
  }
}

/// Day and Week. The hour grid stays even when nothing is scheduled — it is
/// the thing that makes "free" legible — with a quiet note layered over it.
class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.state,
    required this.bottomInset,
    required this.onTap,
  });

  final CalendarState state;
  final double bottomInset;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = state.view == CalendarViewMode.day
        ? [CalendarDates.startOfDay(state.date)]
        : state.range.days;
    final isEmpty = days.every((day) => state.entriesOn(day).isEmpty);

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 12),
      child: Stack(
        children: [
          CalendarTimeline(
            key: ValueKey('${state.view}-${state.range.from}'),
            days: days,
            entriesOn: state.entriesOn,
            onTapEntry: onTap,
            bottomPadding: bottomInset,
          ),
          if (isEmpty)
            Positioned(
              top: 64,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.scheme.muted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      state.filter == CalendarFilter.all
                          ? 'Nothing scheduled'
                          : 'No ${state.filter.label.toLowerCase()} here',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `headerTitle` in `components/calendar/utils.ts`.
String rangeTitle(CalendarViewMode view, DateTime date) {
  switch (view) {
    case CalendarViewMode.day:
      // The web spells the weekday out in full; abbreviated, it leaves room
      // for the five actions that share this row on a phone.
      return DateFormat('EEE, d MMM yyyy').format(date);
    case CalendarViewMode.week:
      final range = CalendarDates.rangeFor(view, date);
      final sameMonth = range.from.month == range.to.month &&
          range.from.year == range.to.year;
      final from = sameMonth
          ? DateFormat('d').format(range.from)
          : DateFormat('d MMM').format(range.from);
      return '$from – ${DateFormat('d MMM yyyy').format(range.to)}';
    case CalendarViewMode.month:
      return DateFormat('MMMM yyyy').format(date);
    case CalendarViewMode.year:
      return '${date.year}';
  }
}
