import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/rewards.dart';
import '../models/rewards_models.dart';

/// Raw HTTP for the rewards endpoints — the port of `src/api/rewards`.
class RewardsService {
  const RewardsService(this._client);

  final DioClient _client;

  /// `POST /rewards/visit`.
  ///
  /// Idempotent per IST day server-side — the first call each day credits +1
  /// point and later ones are no-ops, so the client can fire it freely on
  /// entering the student shell.
  ///
  /// The response carries the fresh wallet, but nothing consumes it: the award
  /// is deliberately silent and the Wallet tab re-fetches on entry.
  Future<void> recordDailyVisit() async {
    await _client.post(ApiUrls.rewardsVisit, parse: (_) => null);
  }

  /// `POST /rewards/tickets/use` — spends one Time Travel Ticket to re-open a
  /// daily challenge whose window has closed.
  ///
  /// The ticket is a paid item bought with coins, and the spend is immediate
  /// and irreversible, so the caller confirms first.
  Future<void> useTicket(String setId) async {
    await _client.post(
      ApiUrls.rewardsUseTicket,
      body: {'setId': setId},
      parse: (_) => null,
    );
  }

  /// `GET /rewards/wallet` — balance plus the unused-ticket count.
  Future<WalletModel> getWallet() async {
    final response = await _client.get(
      ApiUrls.rewardsWallet,
      parse: (data) =>
          WalletModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /rewards/wallet/transactions` — the ledger, newest first.
  Future<Paginated<PointTransactionModel>> listTransactions({
    int page = 1,
    int limit = RewardsMeta.transactionsPageSize,
  }) async {
    final response = await _client.get(
      ApiUrls.rewardsTransactions,
      query: {'page': page, 'limit': limit},
      parse: (data) => Paginated<PointTransactionModel>.fromJson(
        data,
        PointTransactionModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `GET /rewards/store` — the catalogue and the balance it is priced against.
  Future<StoreModel> getStore() async {
    final response = await _client.get(
      ApiUrls.rewardsStore,
      parse: (data) =>
          StoreModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /rewards/store/:productId/purchase`.
  ///
  /// 400 when the balance is short, 404 when the product is gone or inactive —
  /// both surface as the server's own message through the error interceptor.
  Future<void> purchase(String productId) async {
    await _client.post(ApiUrls.rewardsPurchase(productId), parse: (_) => null);
  }

  /// `GET /rewards/orders` — every purchase, newest first. Not paginated.
  Future<List<RewardOrder>> listOrders() async {
    final response = await _client.get(
      ApiUrls.rewardsOrders,
      parse: RewardOrderModel.listFromJson,
    );
    return response.data;
  }

  /// `GET /rewards/orders/:id/messages` — oldest first. Reading also marks the
  /// admin's messages read, which is what clears the unread badge.
  Future<List<OrderMessage>> listOrderMessages(String orderId) async {
    final response = await _client.get(
      ApiUrls.rewardsOrderMessages(orderId),
      parse: OrderMessageModel.listFromJson,
    );
    return response.data;
  }

  /// `POST /rewards/orders/:id/messages` — the server caps content at 2000.
  Future<void> sendOrderMessage(String orderId, String content) async {
    await _client.post(
      ApiUrls.rewardsOrderMessages(orderId),
      body: {'content': content},
      parse: (_) => null,
    );
  }
}
