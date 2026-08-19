import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../badges/domain/entities/badge.dart';
import '../entities/leaderboard.dart';
import '../repositories/leaderboard_repository.dart';

class GetLeaderboardUseCase implements UseCase<LeaderboardStandings, LeaderboardParams> {
  const GetLeaderboardUseCase(this._repository);

  final LeaderboardRepository _repository;

  @override
  Future<Either<Failure, LeaderboardStandings>> call(LeaderboardParams params) =>
      _repository.getLeaderboard(
        scope: params.scope,
        period: params.period,
        page: params.page,
        limit: params.limit,
      );
}

class LeaderboardParams extends Equatable {
  const LeaderboardParams({
    this.scope = LeaderboardScope.school,
    this.period = LeaderboardPeriod.defaultPeriod,
    this.page = 1,
    this.limit = 20,
  });

  final String scope;
  final String period;
  final int page;
  final int limit;

  LeaderboardParams copyWith({String? scope, String? period, int? page}) =>
      LeaderboardParams(
        scope: scope ?? this.scope,
        period: period ?? this.period,
        // A scope or period change always restarts at page 1.
        page: page ?? ((scope != null || period != null) ? 1 : this.page),
        limit: limit,
      );

  @override
  List<Object?> get props => [scope, period, page, limit];
}

class GetBadgesUseCase implements UseCase<BadgeCollection, NoParams> {
  const GetBadgesUseCase(this._repository);

  final LeaderboardRepository _repository;

  @override
  Future<Either<Failure, BadgeCollection>> call(NoParams params) =>
      _repository.getBadges();
}
