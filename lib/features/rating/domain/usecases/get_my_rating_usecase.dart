import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/contest_rating.dart';
import '../repositories/rating_repository.dart';

class GetMyRatingUseCase implements UseCase<ContestRating, NoParams> {
  const GetMyRatingUseCase(this._repository);

  final RatingRepository _repository;

  @override
  Future<Either<Failure, ContestRating>> call(NoParams params) =>
      _repository.getMyRating();
}

class GetRatingLeaderboardUseCase
    implements UseCase<RatingLeaderboard, RatingLeaderboardParams> {
  const GetRatingLeaderboardUseCase(this._repository);

  final RatingRepository _repository;

  @override
  Future<Either<Failure, RatingLeaderboard>> call(
    RatingLeaderboardParams params,
  ) =>
      _repository.getRatingLeaderboard(page: params.page, limit: params.limit);
}

class RatingLeaderboardParams extends Equatable {
  const RatingLeaderboardParams({this.page = 1, this.limit = 20});

  final int page;

  /// The backend caps this at 100.
  final int limit;

  RatingLeaderboardParams copyWith({int? page}) =>
      RatingLeaderboardParams(page: page ?? this.page, limit: limit);

  @override
  List<Object?> get props => [page, limit];
}
