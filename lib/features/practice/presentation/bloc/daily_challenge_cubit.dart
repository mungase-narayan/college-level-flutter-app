import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/usecases/practice_usecases.dart';

/// What the hub draws: today's challenge, the month being browsed, and the
/// recent history.
///
/// All three are rendered, so all three live in the emitted state rather than
/// in fields beside it — the equality trap that has already cost this codebase
/// one silent bug (see `assessment_answer_state_test.dart`).
class DailyChallengeHome extends Equatable {
  const DailyChallengeHome({
    required this.today,
    this.calendar,
    this.history = const [],
    this.isMonthLoading = false,
  });

  final DailyChallenge today;

  /// Null only until the first month lands; a failed month keeps the previous
  /// one on screen rather than blanking the grid.
  final DailyCalendar? calendar;

  final List<DailyChallengeDay> history;
  final bool isMonthLoading;

  DailyChallengeHome copyWith({
    DailyChallenge? today,
    DailyCalendar? calendar,
    List<DailyChallengeDay>? history,
    bool? isMonthLoading,
  }) =>
      DailyChallengeHome(
        today: today ?? this.today,
        calendar: calendar ?? this.calendar,
        history: history ?? this.history,
        isMonthLoading: isMonthLoading ?? this.isMonthLoading,
      );

  @override
  List<Object?> get props => [today, calendar, history, isMonthLoading];
}

/// The Daily Challenge hub.
class DailyChallengeCubit extends Cubit<RemoteState<DailyChallengeHome>> {
  DailyChallengeCubit({
    required GetDailyChallengeUseCase getToday,
    required GetDailyCalendarUseCase getCalendar,
    required GetDailyChallengeHistoryUseCase getHistory,
  })  : _getToday = getToday,
        _getCalendar = getCalendar,
        _getHistory = getHistory,
        super(const RemoteState());

  final GetDailyChallengeUseCase _getToday;
  final GetDailyCalendarUseCase _getCalendar;
  final GetDailyChallengeHistoryUseCase _getHistory;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getToday(const NoParams());
    if (isClosed) return;

    await result.fold(
      (failure) async => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (today) async {
        emit(RemoteState(
          status: RemoteStatus.success,
          data: DailyChallengeHome(today: today),
        ));
        // The calendar and the history are extra: the hero is usable without
        // them, so neither holds up the first paint and neither can fail the
        // screen.
        await Future.wait([loadMonth(), _loadHistory()]);
      },
    );
  }

  /// Loads a month. Null asks the server for its own current month — the only
  /// safe way to say "this month" when days are bucketed in IST.
  Future<void> loadMonth({String? month}) async {
    final current = state.data;
    if (isClosed || current == null) return;

    emit(state.copyWith(data: current.copyWith(isMonthLoading: true)));
    final result = await _getCalendar(MonthParams(month: month));
    if (isClosed) return;

    result.fold(
      // Keep the month already on screen; an empty grid would read as "nothing
      // posted this month", which is a different and wrong statement.
      (_) => emit(state.copyWith(
        data: state.data!.copyWith(isMonthLoading: false),
      )),
      (calendar) => emit(state.copyWith(
        data: state.data!.copyWith(calendar: calendar, isMonthLoading: false),
      )),
    );
  }

  /// Steps the visible month by [delta] months, wrapping the year.
  Future<void> shiftMonth(int delta) {
    final month = state.data?.calendar?.month;
    if (month == null) return loadMonth();

    final parts = month.split('-');
    if (parts.length != 2) return loadMonth();
    final year = int.tryParse(parts.first);
    final index = int.tryParse(parts.last);
    if (year == null || index == null) return loadMonth();

    final shifted = DateTime(year, index + delta);
    final next = '${shifted.year.toString().padLeft(4, '0')}-'
        '${shifted.month.toString().padLeft(2, '0')}';
    return loadMonth(month: next);
  }

  Future<void> _loadHistory() async {
    final result = await _getHistory(8);
    if (isClosed || state.data == null) return;

    result.fold(
      (_) {},
      (days) => emit(state.copyWith(data: state.data!.copyWith(history: days))),
    );
  }
}
