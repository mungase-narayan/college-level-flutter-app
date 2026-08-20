import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/submission.dart';
import '../repositories/teacher_grading_repository.dart';

/// The grading surface, grouped the way the screens use it: the results page
/// needs the overview, the statistics and both header actions, and the review
/// screen needs one submission plus the two writes.
class TeacherGradingUseCases {
  const TeacherGradingUseCases(this._repository);

  final TeacherGradingRepository _repository;

  Future<Either<Failure, AssignmentOverview>> overview({
    required String assessmentId,
    int page = 1,
    int limit = 15,
    String? search,
    String sortBy = 'score',
    String sortOrder = 'desc',
  }) =>
      _repository.getOverview(
        assessmentId: assessmentId,
        page: page,
        limit: limit,
        search: search,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

  Future<Either<Failure, List<QuestionStat>>> statistics(String assessmentId) =>
      _repository.getStatistics(assessmentId);

  Future<Either<Failure, ResultSheet>> resultSheet(String assessmentId) =>
      _repository.getResultSheet(assessmentId);

  Future<Either<Failure, ({SubmissionDetail detail, SubmissionNote note})>>
      submission({
    required String assessmentId,
    required String submissionId,
  }) =>
          _repository.getSubmission(
            assessmentId: assessmentId,
            submissionId: submissionId,
          );

  Future<Either<Failure, void>> evaluate({
    required String assessmentId,
    required String submissionId,
    required EvaluationInput input,
  }) =>
      _repository.evaluate(
        assessmentId: assessmentId,
        submissionId: submissionId,
        input: input,
      );

  Future<Either<Failure, void>> allowReattempt({
    required String assessmentId,
    required String submissionId,
  }) =>
      _repository.allowReattempt(
        assessmentId: assessmentId,
        submissionId: submissionId,
      );
}
