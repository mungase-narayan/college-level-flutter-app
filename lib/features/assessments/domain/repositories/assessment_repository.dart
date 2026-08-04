import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/assessment_detail.dart';
import '../entities/student_assessment.dart';

abstract class AssessmentRepository {
  /// Assignments for a course, or quizzes when [category] is `quiz`.
  Future<Either<Failure, List<StudentAssessment>>> listForCourse({
    required String courseId,
    String? category,
    String? courseMaterialId,
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
