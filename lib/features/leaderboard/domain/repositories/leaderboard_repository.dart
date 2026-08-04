import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../badges/domain/entities/badge.dart';
import '../entities/leaderboard.dart';

abstract class LeaderboardRepository {
  Future<Either<Failure, LeaderboardPage>> getLeaderboard({
    String scope,
    String period,
    int page,
    int limit,
  });

  Future<Either<Failure, BadgeCollection>> getBadges();
}
