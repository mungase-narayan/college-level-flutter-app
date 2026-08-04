import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/daily_challenge.dart';
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

  Future<Either<Failure, PracticeSummary>> getSummary();

  Future<Either<Failure, PracticeAnalytics>> getAnalytics();

  Future<Either<Failure, DailyChallenge>> getDailyChallenge();

  Future<Either<Failure, List<DailyChallengeDay>>> getDailyChallengeHistory({int limit});

  Future<Either<Failure, Unit>> setBookmarked({
    required String questionId,
    required bool bookmarked,
  });
}
