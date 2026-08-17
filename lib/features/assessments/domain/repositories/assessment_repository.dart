import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/assessment_detail.dart';
import '../entities/student_assessment.dart';

abstract class AssessmentRepository {
  /// Assignments for a course, or quizzes when [category] is `quiz`.
  Future<Either<Failure, List<StudentAssessment>>> listForCourse({
    required String courseId,
    String? category,
    String? courseMaterialId,
  });

  /// The same rows across every enrolled course, paginated and filtered by the
  /// server. Powers the standalone Quizzes screen.
  Future<Either<Failure, Paginated<StudentAssessment>>> listAll({
    String? category,
    String? courseId,
    String? status,
    String? search,
    int page,
    int limit,
  });

  Future<Either<Failure, AssessmentDetail>> getDetail(String assessmentId);

  Future<Either<Failure, Unit>> startAttempt(String assessmentId);

  /// Autosaves the in-progress attempt. [answers] are keyed by
  /// `assessmentQuestionId`.
  Future<Either<Failure, Unit>> saveDraft({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
  });

  Future<Either<Failure, Unit>> submit({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
    bool autoSubmitted,
  });
}
