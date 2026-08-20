import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/rewards.dart';

abstract class RewardsRepository {
  /// Records the once-per-day visit that awards +1 point.
  Future<Either<Failure, Unit>> recordDailyVisit();

  /// Spends a Time Travel Ticket on a closed daily-challenge set.
  Future<Either<Failure, Unit>> useTicket(String setId);

  Future<Either<Failure, Wallet>> getWallet();

  Future<Either<Failure, Paginated<PointTransaction>>> listTransactions({
    int page,
    int limit,
  });

  Future<Either<Failure, Store>> getStore();

  /// Spends points on a product. Fails with the server's message when the
  /// balance is short or the product is no longer available.
  Future<Either<Failure, Unit>> purchase(String productId);

  Future<Either<Failure, List<RewardOrder>>> listOrders();

  Future<Either<Failure, List<OrderMessage>>> listOrderMessages(String orderId);

  Future<Either<Failure, Unit>> sendOrderMessage(String orderId, String content);
}
