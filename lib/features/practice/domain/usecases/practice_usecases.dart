import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_challenge.dart';
import '../entities/practice_attempt.dart';
import '../entities/practice_question.dart';
import '../entities/practice_summary.dart';
import '../repositories/practice_repository.dart';

/// Browse the practice bank.
class ListPracticeQuestionsUseCase
    implements UseCase<Paginated<PracticeQuestionListItem>, PracticeQueryParams> {
  const ListPracticeQuestionsUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, Paginated<PracticeQuestionListItem>>> call(
    PracticeQueryParams params,
  ) =>
      _repository.listQuestions(
        page: params.page,
        limit: params.limit,
        search: params.search,
        type: params.type,
        difficulty: params.difficulty,
        courseId: params.courseId,
        attemptStatus: params.attemptStatus,
        bookmarked: params.bookmarked,
        sort: params.sort,
      );
}

class PracticeQueryParams extends Equatable {
  const PracticeQueryParams({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.type,
    this.difficulty,
    this.courseId,
    this.attemptStatus,
    this.bookmarked,
    this.sort = 'recent',
  });

  final int page;
  final int limit;
  final String? search;
  final String? type;
  final String? difficulty;
  final String? courseId;
  final String? attemptStatus;
  final bool? bookmarked;
  final String sort;

  /// How many user-set filters are on — the number on the sheet's badge.
  /// Search has its own visible field, so it does not count.
  int get activeFilterCount =>
      (sort != 'recent' ? 1 : 0) +
      (type != null ? 1 : 0) +
      (difficulty != null ? 1 : 0) +
      (courseId != null ? 1 : 0) +
      (attemptStatus != null ? 1 : 0) +
      (bookmarked == true ? 1 : 0);

  PracticeQueryParams copyWith({
    int? page,
    String? search,
    String? type,
    String? difficulty,
    String? courseId,
    String? attemptStatus,
    bool? bookmarked,
    String? sort,
    bool clearType = false,
    bool clearDifficulty = false,
    bool clearCourse = false,
    bool clearAttemptStatus = false,
    bool clearBookmarked = false,
  }) =>
      PracticeQueryParams(
        page: page ?? this.page,
        limit: limit,
        search: search ?? this.search,
        type: clearType ? null : (type ?? this.type),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        // Was pinned to the current value, so the Course filter could never be
        // set at all — the sheet had no control for it to notice.
        courseId: clearCourse ? null : (courseId ?? this.courseId),
        attemptStatus:
            clearAttemptStatus ? null : (attemptStatus ?? this.attemptStatus),
        bookmarked: clearBookmarked ? null : (bookmarked ?? this.bookmarked),
        sort: sort ?? this.sort,
      );

  @override
  List<Object?> get props =>
      [page, limit, search, type, difficulty, courseId, attemptStatus, bookmarked, sort];
}

class GetPracticeQuestionUseCase implements UseCase<PracticeQuestionDetail, IdParams> {
  const GetPracticeQuestionUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeQuestionDetail>> call(IdParams params) =>
      _repository.getQuestion(params.id);
}

class GetPracticeSummaryUseCase implements UseCase<PracticeSummary, NoParams> {
  const GetPracticeSummaryUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeSummary>> call(NoParams params) =>
      _repository.getSummary();
}

class GetPracticeAnalyticsUseCase implements UseCase<PracticeAnalytics, NoParams> {
  const GetPracticeAnalyticsUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeAnalytics>> call(NoParams params) =>
      _repository.getAnalytics();
}

class GetDailyChallengeUseCase implements UseCase<DailyChallenge, NoParams> {
  const GetDailyChallengeUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, DailyChallenge>> call(NoParams params) =>
      _repository.getDailyChallenge();
}

class GetDailyChallengeHistoryUseCase
    implements UseCase<List<DailyChallengeDay>, int> {
  const GetDailyChallengeHistoryUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, List<DailyChallengeDay>>> call(int limit) =>
      _repository.getDailyChallengeHistory(limit: limit);
}

/// Toggles a bookmark on a practice question.
class SetBookmarkedUseCase implements UseCase<Unit, SetBookmarkedParams> {
  const SetBookmarkedUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetBookmarkedParams params) =>
      _repository.setBookmarked(
        questionId: params.questionId,
        bookmarked: params.bookmarked,
      );
}

class SetBookmarkedParams extends Equatable {
  const SetBookmarkedParams({required this.questionId, required this.bookmarked});

  final String questionId;
  final bool bookmarked;

  @override
  List<Object?> get props => [questionId, bookmarked];
}

/// The attempt history for one question, with its answer key revealed.
class GetPracticeAttemptsUseCase
    implements UseCase<PracticeAttemptHistory, IdParams> {
  const GetPracticeAttemptsUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeAttemptHistory>> call(IdParams params) =>
      _repository.listAttempts(params.id);
}

/// Where to go after this question. Returns null when the bank has nowhere
/// else to send the student.
class NavigatePracticeUseCase implements UseCase<String?, PracticeNavigateParams> {
  const NavigatePracticeUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, String?>> call(PracticeNavigateParams params) =>
      _repository.navigate(params.questionId, mode: params.mode);
}

class PracticeNavigateParams extends Equatable {
  const PracticeNavigateParams({required this.questionId, this.mode = 'next'});

  final String questionId;

  /// `next` walks the bank newest-first and wraps; `random` picks any other.
  final String mode;

  @override
  List<Object?> get props => [questionId, mode];
}

/// Runs code against the question's sample cases. Nothing is stored and no
/// attempt is used up.
class RunPracticeCodeUseCase
    implements UseCase<PracticeCodingResult, RunCodeParams> {
  const RunPracticeCodeUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeCodingResult>> call(RunCodeParams params) =>
      _repository.run(
        id: params.questionId,
        code: params.code,
        language: params.language,
      );
}

/// Runs code once against input the student typed, with no judging.
class RunPracticeCustomUseCase
    implements UseCase<PracticeCustomRunResult, RunCodeParams> {
  const RunPracticeCustomUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeCustomRunResult>> call(RunCodeParams params) =>
      _repository.runCustom(
        id: params.questionId,
        code: params.code,
        language: params.language,
        stdin: params.stdin,
      );
}

class RunCodeParams extends Equatable {
  const RunCodeParams({
    required this.questionId,
    required this.code,
    required this.language,
    this.stdin,
  });

  final String questionId;
  final String code;
  final String language;

  /// Custom runs only.
  final String? stdin;

  @override
  List<Object?> get props => [questionId, code, language, stdin];
}

/// Grades an attempt. The response carries the question with its answers
/// revealed, whatever the verdict.
class SubmitPracticeUseCase
    implements UseCase<PracticeSubmitResult, SubmitPracticeParams> {
  const SubmitPracticeUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeSubmitResult>> call(
    SubmitPracticeParams params,
  ) =>
      _repository.submit(
        id: params.questionId,
        selectedAnswers: params.draft.selectedAnswers.isEmpty
            ? null
            : params.draft.selectedAnswers,
        answerText: params.draft.answerText,
        attachments:
            params.draft.attachments.isEmpty ? null : params.draft.attachments,
        code: params.draft.code,
        language: params.draft.language,
        studentNote: params.draft.studentNote,
        timeTakenSec: params.timeTakenSec,
      );
}

class SubmitPracticeParams extends Equatable {
  const SubmitPracticeParams({
    required this.questionId,
    required this.draft,
    this.timeTakenSec,
  });

  final String questionId;
  final PracticeAnswerDraft draft;

  /// Measured from when the screen opened — the server stores it for the
  /// student's own time stats.
  final int? timeTakenSec;

  @override
  List<Object?> get props => [questionId, draft, timeTakenSec];
}

/// The Course options behind the list's filter sheet.
class GetPracticeFiltersUseCase
    implements UseCase<PracticeFilterOptions, NoParams> {
  const GetPracticeFiltersUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, PracticeFilterOptions>> call(NoParams params) =>
      _repository.getFilters();
}

/// A past day's challenge.
class GetDailyChallengeByDateUseCase implements UseCase<DailyChallenge, IdParams> {
  const GetDailyChallengeByDateUseCase(this._repository);

  final PracticeRepository _repository;

  /// [params].id is the `YYYY-MM-DD` date, as the server spells it.
  @override
  Future<Either<Failure, DailyChallenge>> call(IdParams params) =>
      _repository.getDailyChallengeByDate(params.id);
}

/// The month grid behind the hub's calendar.
class GetDailyCalendarUseCase implements UseCase<DailyCalendar, MonthParams> {
  const GetDailyCalendarUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, DailyCalendar>> call(MonthParams params) =>
      _repository.getDailyChallengeCalendar(month: params.month);
}

class MonthParams extends Equatable {
  const MonthParams({this.month});

  /// `YYYY-MM`. Null asks the server for its current month — the only safe way
  /// to get "this month" when the server buckets days in IST.
  final String? month;

  @override
  List<Object?> get props => [month];
}

/// Answers one question of a daily set.
class SubmitDailyChallengeUseCase
    implements UseCase<DailyChallengeSubmitResult, DailySubmitParams> {
  const SubmitDailyChallengeUseCase(this._repository);

  final PracticeRepository _repository;

  @override
  Future<Either<Failure, DailyChallengeSubmitResult>> call(
    DailySubmitParams params,
  ) =>
      _repository.submitDailyChallenge(
        setId: params.setId,
        questionId: params.questionId,
        selectedAnswers: params.draft.selectedAnswers.isEmpty
            ? null
            : params.draft.selectedAnswers,
        answerText: params.draft.answerText,
        attachments:
            params.draft.attachments.isEmpty ? null : params.draft.attachments,
        code: params.draft.code,
        language: params.draft.language,
        studentNote: params.draft.studentNote,
        timeTakenSec: params.timeTakenSec,
      );
}

class DailySubmitParams extends Equatable {
  const DailySubmitParams({
    required this.setId,
    required this.questionId,
    required this.draft,
    this.timeTakenSec,
  });

  final String setId;
  final String questionId;
  final PracticeAnswerDraft draft;
  final int? timeTakenSec;

  @override
  List<Object?> get props => [setId, questionId, draft, timeTakenSec];
}
