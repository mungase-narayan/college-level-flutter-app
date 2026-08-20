import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/rewards.dart';
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

class GetWalletUseCase implements UseCase<Wallet, NoParams> {
  const GetWalletUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, Wallet>> call(NoParams params) =>
      _repository.getWallet();
}

class ListTransactionsUseCase
    implements UseCase<Paginated<PointTransaction>, PageParams> {
  const ListTransactionsUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, Paginated<PointTransaction>>> call(PageParams params) =>
      _repository.listTransactions(page: params.page, limit: params.limit);
}

class GetStoreUseCase implements UseCase<Store, NoParams> {
  const GetStoreUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, Store>> call(NoParams params) => _repository.getStore();
}

class PurchaseProductUseCase implements UseCase<Unit, IdParams> {
  const PurchaseProductUseCase(this._repository);

  final RewardsRepository _repository;

  /// [params].id is the product's id.
  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.purchase(params.id);
}

class ListOrdersUseCase implements UseCase<List<RewardOrder>, NoParams> {
  const ListOrdersUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, List<RewardOrder>>> call(NoParams params) =>
      _repository.listOrders();
}

class ListOrderMessagesUseCase
    implements UseCase<List<OrderMessage>, IdParams> {
  const ListOrderMessagesUseCase(this._repository);

  final RewardsRepository _repository;

  /// [params].id is the order's id.
  @override
  Future<Either<Failure, List<OrderMessage>>> call(IdParams params) =>
      _repository.listOrderMessages(params.id);
}

class SendOrderMessageUseCase implements UseCase<Unit, SendMessageParams> {
  const SendOrderMessageUseCase(this._repository);

  final RewardsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SendMessageParams params) =>
      _repository.sendOrderMessage(params.orderId, params.content);
}

class SendMessageParams extends Equatable {
  const SendMessageParams({required this.orderId, required this.content});

  final String orderId;
  final String content;

  @override
  List<Object?> get props => [orderId, content];
}
