import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/bank_question.dart';
import '../entities/teacher_assessment.dart';

abstract class TeacherAssessmentRepository {
  Future<Either<Failure, List<TeacherAssessment>>> list({
    required String courseId,
    String? divisionId,
    String? courseMaterialId,
  });

  Future<Either<Failure, TeacherAssessmentDetail>> getDetail(String id);

  /// Returns the created assessment so the caller can attach questions to it.
  Future<Either<Failure, TeacherAssessment>> create(Map<String, dynamic> body);

  Future<Either<Failure, void>> update({
    required String id,
    required Map<String, dynamic> body,
  });

  Future<Either<Failure, void>> delete(String id);

  Future<Either<Failure, void>> addQuestion({
    required String assessmentId,
    required String questionId,
  });

  /// [assessmentQuestionId] is the join-row id, not the question id.
  Future<Either<Failure, void>> removeQuestion({
    required String assessmentId,
    required String assessmentQuestionId,
  });

  /// Pickable questions. Passing [assessmentId] uses the bank endpoint, which
  /// excludes what is already attached; omitting it falls back to the
  /// teacher's active questions, which do not.
  Future<Either<Failure, Paginated<BankQuestion>>> listBankQuestions({
    String? assessmentId,
    int page,
    int limit,
    String? search,
    String? type,
    String? difficulty,
    String? category,
  });

  Future<Either<Failure, void>> publishResults({
    required String id,
    required bool publish,
  });
}
