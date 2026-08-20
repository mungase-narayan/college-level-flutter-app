import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/submission.dart';

/// Grading, which lives on `/teacher/assignments` rather than the
/// `/assessments` router that [TeacherAssessmentRepository] uses.
abstract class TeacherGradingRepository {
  Future<Either<Failure, AssignmentOverview>> getOverview({
    required String assessmentId,
    int page,
    int limit,
    String? search,
    String sortBy,
    String sortOrder,
  });

  Future<Either<Failure, List<QuestionStat>>> getStatistics(
    String assessmentId,
  );

  Future<Either<Failure, ResultSheet>> getResultSheet(String assessmentId);

  Future<Either<Failure, ({SubmissionDetail detail, SubmissionNote note})>>
      getSubmission({
    required String assessmentId,
    required String submissionId,
  });

  Future<Either<Failure, void>> evaluate({
    required String assessmentId,
    required String submissionId,
    required EvaluationInput input,
  });

  Future<Either<Failure, void>> allowReattempt({
    required String assessmentId,
    required String submissionId,
  });
}
