import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/bank_question.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/repositories/teacher_assessment_repository.dart';
import '../datasources/teacher_assessment_service.dart';

class TeacherAssessmentRepositoryImpl
    with RepositoryGuard
    implements TeacherAssessmentRepository {
  const TeacherAssessmentRepositoryImpl(this._service);

  final TeacherAssessmentService _service;

  @override
  Future<Either<Failure, List<TeacherAssessment>>> list({
    required String courseId,
    String? divisionId,
    String? courseMaterialId,
  }) =>
      guard(
        () => _service.list(
          courseId: courseId,
          divisionId: divisionId,
          courseMaterialId: courseMaterialId,
        ),
      );

  @override
  Future<Either<Failure, TeacherAssessmentDetail>> getDetail(String id) =>
      guard(() => _service.getDetail(id));

  @override
  Future<Either<Failure, TeacherAssessment>> create(
    Map<String, dynamic> body,
  ) =>
      guard(() => _service.create(body));

  @override
  Future<Either<Failure, void>> update({
    required String id,
    required Map<String, dynamic> body,
  }) =>
      guard(() => _service.update(id: id, body: body));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      guard(() => _service.delete(id));

  @override
  Future<Either<Failure, void>> addQuestion({
    required String assessmentId,
    required String questionId,
  }) =>
      guard(
        () => _service.addQuestion(
          assessmentId: assessmentId,
          questionId: questionId,
        ),
      );

  @override
  Future<Either<Failure, void>> removeQuestion({
    required String assessmentId,
    required String assessmentQuestionId,
  }) =>
      guard(
        () => _service.removeQuestion(
          assessmentId: assessmentId,
          assessmentQuestionId: assessmentQuestionId,
        ),
      );

  @override
  Future<Either<Failure, Paginated<BankQuestion>>> listBankQuestions({
    String? assessmentId,
    int page = 1,
    int limit = 8,
    String? search,
    String? type,
    String? difficulty,
    String? category,
  }) =>
      guard(
        () async {
          final result = await _service.listBankQuestions(
            assessmentId: assessmentId,
            page: page,
            limit: limit,
            search: search,
            type: type,
            difficulty: difficulty,
            category: category,
          );
          return Paginated<BankQuestion>(
            items: result.items,
            pagination: result.pagination,
          );
        },
      );

  @override
  Future<Either<Failure, void>> publishResults({
    required String id,
    required bool publish,
  }) =>
      guard(() => _service.publishResults(id: id, publish: publish));
}
