import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';

/// Raw HTTP for the rewards endpoints — the port of `src/api/rewards`.
///
/// Only the daily-visit call is needed by the shell; the Wallet tab extends
/// this service with the store, orders, and transaction calls.
class RewardsService {
  const RewardsService(this._client);

  final DioClient _client;

  /// `POST /rewards/visit`.
  ///
  /// Idempotent per IST day server-side — the first call each day credits +1
  /// point and later ones are no-ops, so the client can fire it freely on
  /// entering the student shell.
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
}
