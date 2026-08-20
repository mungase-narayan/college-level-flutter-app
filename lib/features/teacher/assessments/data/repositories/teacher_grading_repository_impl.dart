import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/submission.dart';
import '../../domain/repositories/teacher_grading_repository.dart';
import '../datasources/teacher_grading_service.dart';

class TeacherGradingRepositoryImpl
    with RepositoryGuard
    implements TeacherGradingRepository {
  const TeacherGradingRepositoryImpl(this._service);

  final TeacherGradingService _service;

  @override
  Future<Either<Failure, AssignmentOverview>> getOverview({
    required String assessmentId,
    int page = 1,
    int limit = 15,
    String? search,
    String sortBy = 'score',
    String sortOrder = 'desc',
  }) =>
      guard(
        () => _service.getOverview(
          assessmentId: assessmentId,
          page: page,
          limit: limit,
          search: search,
          sortBy: sortBy,
          sortOrder: sortOrder,
        ),
      );

  @override
  Future<Either<Failure, List<QuestionStat>>> getStatistics(
    String assessmentId,
  ) =>
      guard(() => _service.getStatistics(assessmentId));

  @override
  Future<Either<Failure, ResultSheet>> getResultSheet(String assessmentId) =>
      guard(() => _service.getResultSheet(assessmentId));

  @override
  Future<Either<Failure, ({SubmissionDetail detail, SubmissionNote note})>>
      getSubmission({
    required String assessmentId,
    required String submissionId,
  }) =>
          guard(
            () async {
              final result = await _service.getSubmission(
                assessmentId: assessmentId,
                submissionId: submissionId,
              );
              return (
                detail: result.detail as SubmissionDetail,
                note: result.note,
              );
            },
          );

  @override
  Future<Either<Failure, void>> evaluate({
    required String assessmentId,
    required String submissionId,
    required EvaluationInput input,
  }) =>
      guard(
        () => _service.evaluate(
          assessmentId: assessmentId,
          submissionId: submissionId,
          body: input.toJson(),
        ),
      );

  @override
  Future<Either<Failure, void>> allowReattempt({
    required String assessmentId,
    required String submissionId,
  }) =>
      guard(
        () => _service.allowReattempt(
          assessmentId: assessmentId,
          submissionId: submissionId,
        ),
      );
}
