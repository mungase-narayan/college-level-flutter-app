import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../domain/repositories/rewards_repository.dart';
import '../datasources/rewards_service.dart';

class RewardsRepositoryImpl with RepositoryGuard implements RewardsRepository {
  const RewardsRepositoryImpl(this._service);

  final RewardsService _service;

  @override
  Future<Either<Failure, Unit>> recordDailyVisit() => guard(() async {
        await _service.recordDailyVisit();
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> useTicket(String setId) => guard(() async {
        await _service.useTicket(setId);
        return unit;
      });
}
