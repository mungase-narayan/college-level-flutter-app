import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/entities/practice_summary.dart';
import '../../domain/repositories/practice_repository.dart';
import '../datasources/practice_service.dart';

class PracticeRepositoryImpl with RepositoryGuard implements PracticeRepository {
  const PracticeRepositoryImpl(this._service);

  final PracticeService _service;

  @override
  Future<Either<Failure, Paginated<PracticeQuestionListItem>>> listQuestions({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
    String? difficulty,
    String? courseId,
    String? attemptStatus,
    bool? bookmarked,
    String sort = 'recent',
  }) =>
      guard(() async {
        final result = await _service.listQuestions(
          page: page,
          limit: limit,
          search: search,
          type: type,
          difficulty: difficulty,
          courseId: courseId,
          attemptStatus: attemptStatus,
          bookmarked: bookmarked,
          sort: sort,
        );
        return Paginated<PracticeQuestionListItem>(
          items: result.items,
          pagination: result.pagination,
        );
      });

  @override
  Future<Either<Failure, PracticeQuestionDetail>> getQuestion(String id) =>
      guard(() => _service.getQuestion(id));

  @override
  Future<Either<Failure, PracticeAttemptHistory>> listAttempts(String id) =>
      guard(() => _service.listAttempts(id));

  @override
  Future<Either<Failure, String?>> navigate(String id, {String mode = 'next'}) =>
      guard(() => _service.navigate(id, mode: mode));

  @override
  Future<Either<Failure, PracticeCodingResult>> run({
    required String id,
    required String code,
    required String language,
  }) =>
      guard(() => _service.run(id: id, code: code, language: language));

  @override
  Future<Either<Failure, PracticeCustomRunResult>> runCustom({
    required String id,
    required String code,
    required String language,
    String? stdin,
  }) =>
      guard(
        () => _service.runCustom(
          id: id,
          code: code,
          language: language,
          stdin: stdin,
        ),
      );

  @override
  Future<Either<Failure, PracticeSubmitResult>> submit({
    required String id,
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
    int? timeTakenSec,
  }) =>
      guard(
        () => _service.submit(
          id: id,
          selectedAnswers: selectedAnswers,
          answerText: answerText,
          attachments: attachments,
          code: code,
          language: language,
          studentNote: studentNote,
          timeTakenSec: timeTakenSec,
        ),
      );

  @override
  Future<Either<Failure, PracticeFilterOptions>> getFilters() =>
      guard(() => _service.getFilters());

  @override
  Future<Either<Failure, PracticeSummary>> getSummary() =>
      guard(() => _service.getSummary());

  @override
  Future<Either<Failure, PracticeAnalytics>> getAnalytics() =>
      guard(() => _service.getAnalytics());

  @override
  Future<Either<Failure, DailyChallenge>> getDailyChallenge() =>
      guard(() => _service.getDailyChallenge());

  @override
  Future<Either<Failure, List<DailyChallengeDay>>> getDailyChallengeHistory({
    int limit = 14,
  }) =>
      guard(() => _service.getDailyChallengeHistory(limit: limit));

  @override
  Future<Either<Failure, DailyChallenge>> getDailyChallengeByDate(String date) =>
      guard(() => _service.getDailyChallengeByDate(date));

  @override
  Future<Either<Failure, DailyCalendar>> getDailyChallengeCalendar({
    String? month,
  }) =>
      guard(() => _service.getDailyChallengeCalendar(month: month));

  @override
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
  }) =>
      guard(
        () => _service.submitDailyChallenge(
          setId: setId,
          questionId: questionId,
          selectedAnswers: selectedAnswers,
          answerText: answerText,
          attachments: attachments,
          code: code,
          language: language,
          studentNote: studentNote,
          timeTakenSec: timeTakenSec,
        ),
      );

  @override
  Future<Either<Failure, Unit>> setBookmarked({
    required String questionId,
    required bool bookmarked,
  }) =>
      guard(() async {
        await _service.setBookmarked(questionId: questionId, bookmarked: bookmarked);
        return unit;
      });
}
