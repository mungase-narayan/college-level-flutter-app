import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/assessment_detail.dart';
import '../repositories/assessment_repository.dart';

class GetAssessmentDetailUseCase implements UseCase<AssessmentDetail, IdParams> {
  const GetAssessmentDetailUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, AssessmentDetail>> call(IdParams params) =>
      _repository.getDetail(params.id);
}

class StartAttemptUseCase implements UseCase<Unit, IdParams> {
  const StartAttemptUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.startAttempt(params.id);
}

class SaveAttemptUseCase implements UseCase<Unit, AttemptPayload> {
  const SaveAttemptUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AttemptPayload params) =>
      _repository.saveDraft(
        assessmentId: params.assessmentId,
        answers: params.answers,
        note: params.note,
        fileIds: params.fileIds,
      );
}

class SubmitAttemptUseCase implements UseCase<Unit, AttemptPayload> {
  const SubmitAttemptUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AttemptPayload params) => _repository.submit(
        assessmentId: params.assessmentId,
        answers: params.answers,
        note: params.note,
        fileIds: params.fileIds,
        autoSubmitted: params.autoSubmitted,
      );
}

/// The body shared by the save and submit endpoints.
class AttemptPayload extends Equatable {
  const AttemptPayload({
    required this.assessmentId,
    this.answers,
    this.note,
    this.fileIds,
    this.autoSubmitted = false,
  });

  final String assessmentId;

  /// Keyed by `assessmentQuestionId` — the id the server matches on.
  final List<Map<String, dynamic>>? answers;
  final String? note;
  final List<String>? fileIds;

  /// True when a proctoring violation forced the submission.
  final bool autoSubmitted;

  @override
  List<Object?> get props => [assessmentId, answers, note, fileIds, autoSubmitted];
}
