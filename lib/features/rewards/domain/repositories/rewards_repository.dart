import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

abstract class RewardsRepository {
  /// Records the once-per-day visit that awards +1 point.
  Future<Either<Failure, Unit>> recordDailyVisit();
}
