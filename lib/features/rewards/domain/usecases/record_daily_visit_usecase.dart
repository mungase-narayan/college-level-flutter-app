import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/rewards_repository.dart';

/// Fired once when the student shell mounts — the port of `DailyVisitTracker`.
///
/// The React version is deliberately fire-and-forget (`.catch(() => {})`): a
/// failed visit call must never interrupt the student, and the backend is
/// idempotent per day, so retrying tomorrow costs nothing.
class RecordDailyVisitUseCase implements UseCase<Unit, NoParams> {
  const RecordDailyVisitUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) =>
      _repository.recordDailyVisit();
}
