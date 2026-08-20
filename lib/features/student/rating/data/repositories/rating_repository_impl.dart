import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/contest_rating.dart';
import '../../domain/repositories/rating_repository.dart';
import '../datasources/rating_service.dart';

class RatingRepositoryImpl with RepositoryGuard implements RatingRepository {
  const RatingRepositoryImpl(this._service);

  final RatingService _service;

  @override
  Future<Either<Failure, ContestRating>> getMyRating() =>
      guard(() => _service.getMyRating());

  @override
  Future<Either<Failure, RatingLeaderboard>> getRatingLeaderboard({
    int page = 1,
    int limit = 20,
  }) =>
      guard(() => _service.getRatingLeaderboard(page: page, limit: limit));
}
