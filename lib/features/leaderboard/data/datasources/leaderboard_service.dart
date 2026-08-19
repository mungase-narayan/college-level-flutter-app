import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../../../badges/data/models/badge_model.dart';
import '../models/leaderboard_model.dart';

/// Raw HTTP for the practice leaderboard and badge endpoints.
///
/// Both live under `/student/practice` and are read by the Leaderboard tab,
/// the Badges tab, and the dashboard highlights.
class LeaderboardService {
  const LeaderboardService(this._client);

  final DioClient _client;

  /// `GET /student/practice/leaderboard`.
  ///
  /// `scope` ∈ school|batch|department (the API also allows `semester`);
  /// `period` ∈ today|weekly|monthly|yearly|all_time.
  Future<LeaderboardStandingsModel> getLeaderboard({
    String scope = 'school',
    String period = 'all_time',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      ApiUrls.practiceLeaderboard,
      query: {'scope': scope, 'period': period, 'page': page, 'limit': limit},
      parse: (data) =>
          LeaderboardStandingsModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/badges` — earned rows plus the code-defined catalog.
  Future<BadgeCollectionModel> getBadges() async {
    final response = await _client.get(
      ApiUrls.practiceBadges,
      parse: (data) =>
          BadgeCollectionModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }
}
