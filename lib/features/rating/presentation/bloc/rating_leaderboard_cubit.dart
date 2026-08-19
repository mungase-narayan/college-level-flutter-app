import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/contest_rating.dart';
import '../../domain/usecases/get_my_rating_usecase.dart';

/// The school's rated students, paged by number.
///
/// Numbered paging rather than append-on-scroll, matching the web's page
/// controls — so a new page replaces the rows instead of extending them.
class RatingLeaderboardCubit extends Cubit<RemoteState<RatingLeaderboard>> {
  RatingLeaderboardCubit({
    required GetRatingLeaderboardUseCase getRatingLeaderboard,
  })  : _getRatingLeaderboard = getRatingLeaderboard,
        super(const RemoteState());

  final GetRatingLeaderboardUseCase _getRatingLeaderboard;

  RatingLeaderboardParams _params = const RatingLeaderboardParams();

  /// Not part of the emitted state: this is what the next request will ask for,
  /// while the state is what the last one returned.
  RatingLeaderboardParams get params => _params;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getRatingLeaderboard(_params);
    if (isClosed) return;

    result.fold(
      // The rows already on screen stay put — a dropped page should dim the
      // list, not replace a good standing with an error.
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) => emit(RemoteState(status: RemoteStatus.success, data: page)),
    );
  }

  Future<void> setPage(int page) {
    if (page == _params.page || page < 1) return Future.value();
    _params = _params.copyWith(page: page);
    return load();
  }
}
