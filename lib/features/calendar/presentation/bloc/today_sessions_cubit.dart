import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';
import '../../domain/usecases/calendar_usecases.dart';

/// Where a session sits relative to now.
enum SessionPhase { done, live, upcoming }

SessionPhase phaseOf(CalendarEntry session, DateTime now) {
  if (!now.isBefore(session.end)) return SessionPhase.done;
  if (!now.isBefore(session.start)) return SessionPhase.live;
  return SessionPhase.upcoming;
}

/// Today's timetable, picked out of the calendar payload.
///
/// Classes only — events, meetings and tasks are not sessions — and only the
/// occurrence that starts on [day]. Occurrence ids are stable
/// (`"{slotId}:{date}"`), so they also de-duplicate a slot that the server
/// expanded twice.
List<CalendarEntry> todaySessions(List<CalendarEntry> entries, DateTime day) {
  final byId = <String, CalendarEntry>{};
  for (final entry in entries) {
    if (entry.source != CalendarSource.timetable) continue;
    if (!CalendarDates.isSameDay(entry.start, day)) continue;
    byId.putIfAbsent(entry.id, () => entry);
  }
  return byId.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

/// The dashboard's "Today's sessions" card.
///
/// Its own cubit rather than another field on [DashboardCubit]: it reads a
/// different endpoint, and a failure here must not take the dashboard down with
/// it.
class TodaySessionsCubit extends Cubit<RemoteState<List<CalendarEntry>>> {
  TodaySessionsCubit({required GetCalendarUseCase getCalendar, DateTime? today})
      : _getCalendar = getCalendar,
        day = today ?? DateTime.now(),
        super(const RemoteState());

  final GetCalendarUseCase _getCalendar;

  /// The day the card describes, fixed at construction — the card is not
  /// expected to outlive a day.
  final DateTime day;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: RemoteStatus.loading, clearFailure: true));

    // Padded by a day on each side, as the web does: the server expands
    // recurrences against its own local dates, so a tight 24-hour window can
    // miss an edge occurrence. Today's are picked out of the result.
    final range = CalendarRange(
      CalendarDates.startOfDay(day).subtract(const Duration(days: 1)),
      CalendarDates.endOfDay(day).add(const Duration(days: 1)),
    );

    final result = await _getCalendar(
      CalendarQueryParams(range: range, view: CalendarViewMode.day),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
      )),
      (entries) => emit(RemoteState(
        status: RemoteStatus.success,
        data: todaySessions(entries, day),
      )),
    );
  }
}
