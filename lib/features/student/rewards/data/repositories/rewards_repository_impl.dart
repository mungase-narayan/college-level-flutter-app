import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/rewards.dart';
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

  @override
  Future<Either<Failure, Wallet>> getWallet() => guard(_service.getWallet);

  @override
  Future<Either<Failure, Paginated<PointTransaction>>> listTransactions({
    int page = 1,
    int limit = RewardsMeta.transactionsPageSize,
  }) =>
      guard(() => _service.listTransactions(page: page, limit: limit));

  @override
  Future<Either<Failure, Store>> getStore() => guard(_service.getStore);

  @override
  Future<Either<Failure, Unit>> purchase(String productId) => guard(() async {
        await _service.purchase(productId);
        return unit;
      });

  @override
  Future<Either<Failure, List<RewardOrder>>> listOrders() =>
      guard(_service.listOrders);

  @override
  Future<Either<Failure, List<OrderMessage>>> listOrderMessages(
    String orderId,
  ) =>
      guard(() => _service.listOrderMessages(orderId));

  @override
  Future<Either<Failure, Unit>> sendOrderMessage(
    String orderId,
    String content,
  ) =>
      guard(() async {
        await _service.sendOrderMessage(orderId, content);
        return unit;
      });
}
