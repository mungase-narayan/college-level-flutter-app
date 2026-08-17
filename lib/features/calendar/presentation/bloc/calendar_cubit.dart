import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';
import '../../domain/usecases/calendar_usecases.dart';

/// Everything the calendar draws.
///
/// The anchor date, the view and the filter all live in the emitted state
/// rather than in fields beside it — a cubit drops an emission equal to the
/// current state, so anything the UI renders has to be part of that equality.
class CalendarState extends Equatable {
  const CalendarState({
    required this.date,
    required this.view,
    this.filter = CalendarFilter.all,
    this.entries = const [],
    this.status = RemoteStatus.initial,
    this.failure,
    this.isFetching = false,
  });

  /// The day the current view is anchored on.
  final DateTime date;
  final CalendarViewMode view;
  final CalendarFilter filter;

  /// Everything the last successful fetch returned, unfiltered and sorted by
  /// resolved local start.
  final List<CalendarEntry> entries;

  final RemoteStatus status;
  final Failure? failure;

  /// A fetch is in flight while previous entries stay on screen — the web's
  /// `keepPreviousData`, so paging months never blanks the grid.
  final bool isFetching;

  bool get isInitialLoading =>
      status == RemoteStatus.loading && entries.isEmpty && failure == null;

  /// The window the current view covers.
  CalendarRange get range => CalendarDates.rangeFor(view, date);

  /// [entries] narrowed by the filter strip.
  List<CalendarEntry> get visibleEntries =>
      entries.where(filter.matches).toList(growable: false);

  /// The visible entries that start on [day], in time order.
  List<CalendarEntry> entriesOn(DateTime day) => visibleEntries
      .where((entry) => entry.startsOn(day))
      .toList(growable: false);

  CalendarState copyWith({
    DateTime? date,
    CalendarViewMode? view,
    CalendarFilter? filter,
    List<CalendarEntry>? entries,
    RemoteStatus? status,
    Failure? failure,
    bool clearFailure = false,
    bool? isFetching,
  }) =>
      CalendarState(
        date: date ?? this.date,
        view: view ?? this.view,
        filter: filter ?? this.filter,
        entries: entries ?? this.entries,
        status: status ?? this.status,
        failure: clearFailure ? null : (failure ?? this.failure),
        isFetching: isFetching ?? this.isFetching,
      );

  @override
  List<Object?> get props => [
        date,
        view,
        filter,
        entries,
        status,
        failure,
        isFetching,
      ];
}

/// The student calendar — the port of `CalendarView` mounted read-only.
class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit({
    required GetCalendarUseCase getCalendar,
    CalendarViewMode initialView = CalendarViewMode.day,
    DateTime? today,
  })  : _getCalendar = getCalendar,
        super(
          CalendarState(date: today ?? DateTime.now(), view: initialView),
        );

  final GetCalendarUseCase _getCalendar;

  /// Guards against an earlier, slower fetch landing after a later one and
  /// repainting the grid with the wrong range.
  int _requestId = 0;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    final request = ++_requestId;
    final view = state.view;
    final date = state.date;

    emit(state.copyWith(
      status: RemoteStatus.loading,
      isFetching: true,
      clearFailure: true,
    ));

    final result = await _getCalendar(CalendarQueryParams.of(view, date));
    if (isClosed || request != _requestId) return;

    result.fold(
      // The last-known grid stays; an empty one would read as "nothing is
      // scheduled", which is a different and wrong statement.
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isFetching: false,
      )),
      (entries) => emit(state.copyWith(
        status: RemoteStatus.success,
        entries: entries,
        isFetching: false,
        clearFailure: true,
      )),
    );
  }

  /// Switches grid. The window changes with the view, so this refetches.
  Future<void> setView(CalendarViewMode view) {
    if (view == state.view) return Future.value();
    emit(state.copyWith(view: view));
    return load();
  }

  /// Purely client-side — see [CalendarFilter].
  void setFilter(CalendarFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
  }

  /// Steps one day/week/month/year, per the current view.
  Future<void> shift(int delta) {
    emit(state.copyWith(date: CalendarDates.shift(state.view, state.date, delta)));
    return load();
  }

  Future<void> goToToday() {
    final now = DateTime.now();
    if (CalendarDates.isSameDay(now, state.date)) return Future.value();
    emit(state.copyWith(date: now));
    return load();
  }

  /// Tapping a day in the month grid drills into that day.
  Future<void> openDay(DateTime day) {
    emit(state.copyWith(date: day, view: CalendarViewMode.day));
    return load();
  }

  /// The classes in the anchored date's week, for the printable timetable.
  ///
  /// The web keeps a second week-scoped query running at all times to have
  /// this ready; fetching it when the button is actually pressed costs one
  /// request a session instead of one per navigation. Returns null when the
  /// fetch fails.
  Future<List<CalendarEntry>?> weekEntries() async {
    if (state.view == CalendarViewMode.week) return state.entries;

    final result = await _getCalendar(
      CalendarQueryParams.of(CalendarViewMode.week, state.date),
    );
    return result.fold((_) => null, (entries) => entries);
  }

  /// Tapping a month in the year grid drills into that month.
  Future<void> openMonth(DateTime month) {
    emit(state.copyWith(date: month, view: CalendarViewMode.month));
    return load();
  }
}
