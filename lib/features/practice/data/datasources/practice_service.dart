import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../models/practice_models.dart';

/// Raw HTTP for the student practice endpoints — the port of
/// `src/api/student-practice`.
class PracticeService {
  const PracticeService(this._client);

  final DioClient _client;

  /// `GET /student/practice/questions`.
  ///
  /// `sort` accepts `recent | popular | difficulty`; `attemptStatus` accepts
  /// `not_attempted | attempted | solved | incorrect`.
  Future<Paginated<PracticeQuestionListItemModel>> listQuestions({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
    String? difficulty,
    String? courseId,
    String? attemptStatus,
    bool? bookmarked,
    String sort = 'recent',
  }) async {
    final response = await _client.get(
      ApiUrls.practiceQuestions,
      query: {
        'page': page,
        'limit': limit,
        // The backend reads free text from `q`, not `search`.
        'q': search,
        'type': type,
        'difficulty': difficulty,
        'courseId': courseId,
        'attemptStatus': attemptStatus,
        // Sent as a string — the validator parses "true"/"false".
        'bookmarked': bookmarked == null ? null : '$bookmarked',
        'sort': sort,
      },
      parse: (data) => Paginated<PracticeQuestionListItemModel>.fromJson(
        data,
        PracticeQuestionListItemModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `GET /student/practice/questions/:id`.
  Future<PracticeQuestionDetailModel> getQuestion(String id) async {
    final response = await _client.get(
      ApiUrls.practiceQuestion(id),
      parse: (data) => PracticeQuestionDetailModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `GET /student/practice/summary`.
  Future<PracticeSummaryModel> getSummary() async {
    final response = await _client.get(
      ApiUrls.practiceSummary,
      parse: (data) =>
          PracticeSummaryModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/analytics`.
  Future<PracticeAnalyticsModel> getAnalytics() async {
    final response = await _client.get(
      ApiUrls.practiceAnalytics,
      parse: (data) =>
          PracticeAnalyticsModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/daily-challenge` — today's set.
  Future<DailyChallengeModel> getDailyChallenge() async {
    final response = await _client.get(
      ApiUrls.dailyChallenge,
      parse: (data) =>
          DailyChallengeModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/daily-challenge/history?limit=` (1–30).
  Future<List<DailyChallengeDayModel>> getDailyChallengeHistory({int limit = 14}) async {
    final response = await _client.get(
      ApiUrls.dailyChallengeHistory,
      query: {'limit': limit},
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(DailyChallengeDayModel.fromJson)
              .toList(growable: false) ??
          const <DailyChallengeDayModel>[],
    );
    return response.data;
  }

  /// `POST|DELETE /student/practice/questions/:id/bookmark`.
  Future<void> setBookmarked({required String questionId, required bool bookmarked}) async {
    final path = ApiUrls.practiceQuestionBookmark(questionId);
    if (bookmarked) {
      await _client.post(path, parse: (_) => null);
    } else {
      await _client.delete(path, parse: (_) => null);
    }
  }
}
