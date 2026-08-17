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

/// Spends a Time Travel Ticket to re-open a closed daily challenge.
class UseTimeTravelTicketUseCase implements UseCase<Unit, IdParams> {
  const UseTimeTravelTicketUseCase(this._repository);

  final RewardsRepository _repository;

  /// [params].id is the daily set's id.
  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.useTicket(params.id);
}
