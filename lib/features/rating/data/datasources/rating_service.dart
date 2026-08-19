import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/contest_rating_model.dart';

/// Raw HTTP for the contest-rating endpoints — the port of the rating half of
/// `src/api/student-contest`.
class RatingService {
  const RatingService(this._client);

  final DioClient _client;

  /// `GET /student/contest-ratings/me` — current rating, tier, and full history.
  Future<ContestRatingModel> getMyRating() async {
    final response = await _client.get(
      ApiUrls.contestRatingMe,
      parse: (data) =>
          ContestRatingModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/contest-ratings/leaderboard` — the school's rated students.
  Future<RatingLeaderboardModel> getRatingLeaderboard({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      ApiUrls.contestRatingLeaderboard,
      query: {'page': page, 'limit': limit},
      parse: (data) => RatingLeaderboardModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }
}
