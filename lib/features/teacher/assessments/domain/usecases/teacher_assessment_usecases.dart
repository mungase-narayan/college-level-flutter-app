import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/bank_question.dart';
import '../entities/teacher_assessment.dart';
import '../repositories/teacher_assessment_repository.dart';

/// The assessment surface, grouped: the list tab needs read plus delete, and
/// the form needs create, update and both question verbs, so splitting these
/// into eight singletons would only add wiring.
class TeacherAssessmentUseCases {
  const TeacherAssessmentUseCases(this._repository);

  final TeacherAssessmentRepository _repository;

  Future<Either<Failure, List<TeacherAssessment>>> list({
    required String courseId,
    String? divisionId,
    String? courseMaterialId,
  }) =>
      _repository.list(
        courseId: courseId,
        divisionId: divisionId,
        courseMaterialId: courseMaterialId,
      );

  Future<Either<Failure, TeacherAssessmentDetail>> getDetail(String id) =>
      _repository.getDetail(id);

  Future<Either<Failure, TeacherAssessment>> create(
    Map<String, dynamic> body,
  ) =>
      _repository.create(body);

  Future<Either<Failure, void>> update({
    required String id,
    required Map<String, dynamic> body,
  }) =>
      _repository.update(id: id, body: body);

  Future<Either<Failure, void>> delete(String id) => _repository.delete(id);

  Future<Either<Failure, void>> addQuestion({
    required String assessmentId,
    required String questionId,
  }) =>
      _repository.addQuestion(
        assessmentId: assessmentId,
        questionId: questionId,
      );

  Future<Either<Failure, void>> removeQuestion({
    required String assessmentId,
    required String assessmentQuestionId,
  }) =>
      _repository.removeQuestion(
        assessmentId: assessmentId,
        assessmentQuestionId: assessmentQuestionId,
      );

  Future<Either<Failure, Paginated<BankQuestion>>> listBankQuestions({
    String? assessmentId,
    int page = 1,
    int limit = 8,
    String? search,
    String? type,
    String? difficulty,
    String? category,
  }) =>
      _repository.listBankQuestions(
        assessmentId: assessmentId,
        page: page,
        limit: limit,
        search: search,
        type: type,
        difficulty: difficulty,
        category: category,
      );

  Future<Either<Failure, void>> publishResults({
    required String id,
    required bool publish,
  }) =>
      _repository.publishResults(id: id, publish: publish);
}
