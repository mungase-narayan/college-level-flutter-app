import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/usecases/leaderboard_usecases.dart';

/// The practice leaderboard, narrowed by scope and period.
///
/// Bespoke rather than [PaginatedCubit] because this screen pages by *number*
/// — the web shows explicit page controls — so a new page replaces the rows
/// instead of appending to them.
///
/// The query is deliberately not part of the emitted state: it is what the next
/// request will ask for, while the state is what the last one returned. The page
/// reads [params] directly, the same split `AnnouncementsCubit` uses.
class LeaderboardCubit extends Cubit<RemoteState<LeaderboardStandings>> {
  LeaderboardCubit({required GetLeaderboardUseCase getLeaderboard})
      : _getLeaderboard = getLeaderboard,
        super(const RemoteState());

  final GetLeaderboardUseCase _getLeaderboard;

  LeaderboardParams _params = const LeaderboardParams();

  LeaderboardParams get params => _params;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getLeaderboard(_params);
    if (isClosed) return;

    result.fold(
      // The rows already on screen stay: the page dims while fetching, and a
      // failed fetch should leave the last good standings visible rather than
      // blanking to an error.
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) => emit(RemoteState(status: RemoteStatus.success, data: page)),
    );
  }

  /// Both filters restart at page 1 — `LeaderboardParams.copyWith` does that
  /// itself whenever scope or period is passed.
  Future<void> setScope(String scope) {
    if (scope == _params.scope) return Future.value();
    _params = _params.copyWith(scope: scope);
    return load();
  }

  Future<void> setPeriod(String period) {
    if (period == _params.period) return Future.value();
    _params = _params.copyWith(period: period);
    return load();
  }

  Future<void> setPage(int page) {
    if (page == _params.page || page < 1) return Future.value();
    _params = _params.copyWith(page: page);
    return load();
  }
}
