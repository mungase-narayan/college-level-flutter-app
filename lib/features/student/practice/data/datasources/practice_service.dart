import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
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

  /// `GET /student/practice/questions/:id/attempts` — the history, newest
  /// first, plus the question with its answer key revealed.
  ///
  /// Note the reveal is unconditional: calling this hands over the correct
  /// answers even with zero attempts, so the *screen* is what gates the
  /// explanation, not the server.
  Future<PracticeAttemptHistory> listAttempts(String id) async {
    final response = await _client.get(
      ApiUrls.practiceQuestionAttempts(id),
      parse: (data) =>
          attemptHistoryFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/questions/:id/navigate?mode=next|random`.
  ///
  /// Returns null when there is nowhere to go — a bank of one. `next` walks the
  /// pool newest-first and wraps around; neither mode skips solved questions.
  Future<String?> navigate(String id, {String mode = 'next'}) async {
    final response = await _client.get(
      ApiUrls.practiceQuestionNavigate(id),
      query: {'mode': mode},
      parse: (data) =>
          ((data as Map<String, dynamic>?) ?? const {})['questionId'] as String?,
    );
    return response.data;
  }

  /// `POST /student/practice/questions/:id/run` — the **sample** cases only.
  /// Nothing is stored and no attempt is consumed.
  ///
  /// Runs synchronously against the code runner and can take ~20s before the
  /// server gives up, so callers must keep the button disabled meanwhile.
  Future<PracticeCodingResult> run({
    required String id,
    required String code,
    required String language,
  }) async {
    final response = await _client.post(
      ApiUrls.practiceQuestionRun(id),
      body: {'code': code, 'language': language},
      parse: (data) =>
          codingResultFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /student/practice/questions/:id/run-custom` — one execution against
  /// the student's own stdin, with no judging.
  Future<PracticeCustomRunResult> runCustom({
    required String id,
    required String code,
    required String language,
    String? stdin,
  }) async {
    final response = await _client.post(
      ApiUrls.practiceQuestionRunCustom(id),
      body: {'code': code, 'language': language, 'stdin': ?stdin},
      parse: (data) =>
          customRunFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /student/practice/questions/:id/submit` — grades the attempt and
  /// returns it alongside the now-revealed question.
  ///
  /// Every field is optional on the wire and an empty body scores zero, so the
  /// caller decides what a given question type needs.
  Future<PracticeSubmitResult> submit({
    required String id,
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
    int? timeTakenSec,
  }) async {
    final response = await _client.post(
      ApiUrls.practiceQuestionSubmit(id),
      body: {
        'selectedAnswers': ?selectedAnswers,
        'answerText': ?answerText,
        'attachments': ?attachments,
        'code': ?code,
        'language': ?language,
        'studentNote': ?studentNote,
        'timeTakenSec': ?timeTakenSec,
      },
      parse: (data) =>
          submitResultFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/filters` — the course list behind the Course
  /// filter. Types, difficulties and statuses are fixed enums, not facets.
  Future<PracticeFilterOptions> getFilters() async {
    final response = await _client.get(
      ApiUrls.practiceFilters,
      parse: (data) =>
          filterOptionsFromJson((data as Map<String, dynamic>?) ?? const {}),
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

  /// `GET /student/practice/daily-challenge/by-date/:date` — the same shape as
  /// today's, for any past day. A future date has nothing to return.
  Future<DailyChallengeModel> getDailyChallengeByDate(String date) async {
    final response = await _client.get(
      ApiUrls.dailyChallengeByDate(date),
      parse: (data) =>
          DailyChallengeModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /student/practice/daily-challenge/calendar?month=YYYY-MM`.
  ///
  /// The server buckets days in IST, so [month] must be one it gave us — never
  /// one computed from the device clock.
  Future<DailyCalendar> getDailyChallengeCalendar({String? month}) async {
    final response = await _client.get(
      ApiUrls.dailyChallengeCalendar,
      query: {'month': month},
      parse: (data) =>
          dailyCalendarFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /student/practice/daily-challenge/:setId/submit` — one question at a
  /// time, unlike a quiz.
  Future<DailyChallengeSubmitResult> submitDailyChallenge({
    required String setId,
    required String questionId,
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
    int? timeTakenSec,
  }) async {
    final response = await _client.post(
      ApiUrls.dailyChallengeSubmit(setId),
      body: {
        'questionId': questionId,
        'selectedAnswers': ?selectedAnswers,
        'answerText': ?answerText,
        'attachments': ?attachments,
        'code': ?code,
        'language': ?language,
        'studentNote': ?studentNote,
        'timeTakenSec': ?timeTakenSec,
      },
      parse: (data) => dailySubmitResultFromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
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
