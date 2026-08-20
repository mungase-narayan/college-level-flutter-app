import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/daily_challenge.dart';
import '../entities/practice_attempt.dart';
import '../entities/practice_question.dart';
import '../entities/practice_summary.dart';

abstract class PracticeRepository {
  Future<Either<Failure, Paginated<PracticeQuestionListItem>>> listQuestions({
    int page,
    int limit,
    String? search,
    String? type,
    String? difficulty,
    String? courseId,
    String? attemptStatus,
    bool? bookmarked,
    String sort,
  });

  Future<Either<Failure, PracticeQuestionDetail>> getQuestion(String id);

  /// The attempt history plus the question with its answer key revealed.
  Future<Either<Failure, PracticeAttemptHistory>> listAttempts(String id);

  /// The id of the next (or a random) question, or null when there is nowhere
  /// to go.
  Future<Either<Failure, String?>> navigate(String id, {String mode});

  /// Runs code against the sample cases only. Nothing is stored.
  Future<Either<Failure, PracticeCodingResult>> run({
    required String id,
    required String code,
    required String language,
  });

  /// Runs code once against the student's own input, with no judging.
  Future<Either<Failure, PracticeCustomRunResult>> runCustom({
    required String id,
    required String code,
    required String language,
    String? stdin,
  });

  /// Grades an attempt and returns it with the revealed question.
  Future<Either<Failure, PracticeSubmitResult>> submit({
    required String id,
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
    int? timeTakenSec,
  });

  /// Course options for the list's Course filter.
  Future<Either<Failure, PracticeFilterOptions>> getFilters();

  Future<Either<Failure, PracticeSummary>> getSummary();

  Future<Either<Failure, PracticeAnalytics>> getAnalytics();

  Future<Either<Failure, DailyChallenge>> getDailyChallenge();

  Future<Either<Failure, List<DailyChallengeDay>>> getDailyChallengeHistory({int limit});

  /// A past day's challenge, in the same shape as today's.
  Future<Either<Failure, DailyChallenge>> getDailyChallengeByDate(String date);

  /// The month grid. Omit [month] to let the server pick the current one in
  /// its own timezone.
  Future<Either<Failure, DailyCalendar>> getDailyChallengeCalendar({String? month});

  /// Answers one question of a set.
  Future<Either<Failure, DailyChallengeSubmitResult>> submitDailyChallenge({
    required String setId,
    required String questionId,
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
    int? timeTakenSec,
  });

  Future<Either<Failure, Unit>> setBookmarked({
    required String questionId,
    required bool bookmarked,
  });
}
