import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/contest_rating.dart';
import '../../domain/usecases/get_my_rating_usecase.dart';

/// The student's own rating, peak, tier and rated-contest history.
///
/// Separate from [RatingLeaderboardCubit] because the two tabs are independent:
/// paging the leaderboard must not refetch the curve, and a leaderboard failure
/// must not blank the stat tiles.
class RatingCubit extends Cubit<RemoteState<ContestRating>> {
  RatingCubit({required GetMyRatingUseCase getMyRating})
      : _getMyRating = getMyRating,
        super(const RemoteState());

  final GetMyRatingUseCase _getMyRating;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getMyRating(const NoParams());
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (rating) => emit(RemoteState(status: RemoteStatus.success, data: rating)),
    );
  }
}
