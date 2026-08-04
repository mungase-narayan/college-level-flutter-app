import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_challenge.dart';
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

  PracticeQueryParams copyWith({
    int? page,
    String? search,
    String? type,
    String? difficulty,
    String? attemptStatus,
    bool? bookmarked,
    String? sort,
    bool clearType = false,
    bool clearDifficulty = false,
    bool clearAttemptStatus = false,
    bool clearBookmarked = false,
  }) =>
      PracticeQueryParams(
        page: page ?? this.page,
        limit: limit,
        search: search ?? this.search,
        type: clearType ? null : (type ?? this.type),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        courseId: courseId,
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
