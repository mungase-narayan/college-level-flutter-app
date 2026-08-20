import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/assessment_detail.dart';
import '../../domain/entities/student_assessment.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../datasources/assessment_service.dart';

class AssessmentRepositoryImpl
    with RepositoryGuard
    implements AssessmentRepository {
  const AssessmentRepositoryImpl(this._service);

  final AssessmentService _service;

  @override
  Future<Either<Failure, List<StudentAssessment>>> listForCourse({
    required String courseId,
    String? category,
    String? courseMaterialId,
  }) =>
      guard(
        () => _service.listForCourse(
          courseId: courseId,
          category: category,
          courseMaterialId: courseMaterialId,
        ),
      );

  @override
  Future<Either<Failure, Paginated<StudentAssessment>>> listAll({
    String? category,
    String? courseId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) =>
      guard(
        () => _service.listAll(
          category: category,
          courseId: courseId,
          status: status,
          search: search,
          page: page,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, AssessmentDetail>> getDetail(String assessmentId) =>
      guard(() => _service.getDetail(assessmentId));

  @override
  Future<Either<Failure, Unit>> startAttempt(String assessmentId) =>
      guard(() async {
        await _service.startAttempt(assessmentId);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> saveDraft({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
  }) =>
      guard(() async {
        await _service.saveDraft(
          assessmentId: assessmentId,
          answers: answers,
          note: note,
          fileIds: fileIds,
        );
        return unit;
      });

  @override
  Future<Either<Failure, ProctorEventResult>> recordProctorEvent({
    required String assessmentId,
    required String eventType,
    required DateTime occurredAt,
    Map<String, dynamic>? meta,
  }) =>
      guard(() => _service.recordProctorEvent(
            assessmentId: assessmentId,
            eventType: eventType,
            // The server timestamps by receipt otherwise, which would bunch a
            // queued burst of events onto one instant.
            occurredAt: occurredAt.toUtc().toIso8601String(),
            meta: meta,
          ));

  @override
  Future<Either<Failure, Unit>> submit({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
    bool autoSubmitted = false,
  }) =>
      guard(() async {
        await _service.submit(
          assessmentId: assessmentId,
          answers: answers,
          note: note,
          fileIds: fileIds,
          autoSubmitted: autoSubmitted,
        );
        return unit;
      });
}
