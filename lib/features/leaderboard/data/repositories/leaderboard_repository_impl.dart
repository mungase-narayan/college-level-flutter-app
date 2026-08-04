import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../../badges/domain/entities/badge.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_service.dart';

class LeaderboardRepositoryImpl
    with RepositoryGuard
    implements LeaderboardRepository {
  const LeaderboardRepositoryImpl(this._service);

  final LeaderboardService _service;

  @override
  Future<Either<Failure, LeaderboardPage>> getLeaderboard({
    String scope = LeaderboardScope.school,
    String period = LeaderboardPeriod.defaultPeriod,
    int page = 1,
    int limit = 20,
  }) =>
      guard(
        () => _service.getLeaderboard(
          scope: scope,
          period: period,
          page: page,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, BadgeCollection>> getBadges() =>
      guard(() => _service.getBadges());
}
