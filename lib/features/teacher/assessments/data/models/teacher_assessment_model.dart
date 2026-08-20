import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/teacher_assessment.dart';

class TeacherAssessmentModel extends TeacherAssessment {
  const TeacherAssessmentModel({
    required super.id,
    required super.title,
    required super.category,
    required super.type,
    required super.status,
    required super.totalMarks,
    required super.startDate,
    required super.endDate,
    super.description,
    super.passingMarks,
    super.courseId,
    super.divisionId,
    super.divisionName,
    super.resultsPublishedAt,
    super.submissionCount,
    super.evaluatedCount,
  });

  factory TeacherAssessmentModel.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentModel(
        id: asString(json['id']),
        title: asString(json['title']),
        category: asString(json['category']),
        type: asString(json['type']),
        status: asString(json['status']),
        totalMarks: asInt(json['totalMarks']),
        startDate: asString(json['startDate']),
        endDate: asString(json['endDate']),
        description: asStringOrNull(json['description']),
        // Null is meaningful — "no pass mark set" is not the same as zero.
        passingMarks: asIntOrNull(json['passingMarks']),
        courseId: asStringOrNull(json['courseId']),
        divisionId: asStringOrNull(json['divisionId']),
        divisionName: asStringOrNull(json['divisionName']) ??
            asStringOrNull(json['divisionCode']),
        resultsPublishedAt: asStringOrNull(json['resultsPublishedAt']),
        submissionCount: asInt(json['submissionCount']),
        evaluatedCount: asInt(json['evaluatedCount']),
      );
}

class AssessmentQuestionRowModel extends AssessmentQuestionRow {
  const AssessmentQuestionRowModel({
    required super.id,
    required super.questionId,
    required super.order,
    super.title,
    super.type,
    super.difficulty,
    super.points,
  });

  factory AssessmentQuestionRowModel.fromJson(Map<String, dynamic> json) =>
      AssessmentQuestionRowModel(
        // The join-row id, which is what detaching needs.
        id: asString(json['id']),
        questionId: asString(json['questionId']),
        order: asInt(json['order']),
        title: asStringOrNull(json['questionTitle']),
        type: asStringOrNull(json['questionType']),
        difficulty: asStringOrNull(json['questionDifficulty']),
        points: asIntOrNull(json['questionPoints']),
      );
}

class TeacherAssessmentDetailModel extends TeacherAssessmentDetail {
  const TeacherAssessmentDetailModel({
    required super.assessment,
    required super.maxAttempt,
    required super.questions,
    super.courseMaterialId,
    super.isLateSubmissionAllowed,
    super.latePenalty,
    super.isAllowResubmission,
    super.isProctored,
    super.durationMinutes,
    super.maxViolations,
    super.proctoringConfig,
    super.fileIds,
    super.creatorName,
  });

  /// The detail payload is a list row with the extra columns folded in
  /// alongside, so the row is parsed from the same object.
  factory TeacherAssessmentDetailModel.fromJson(Map<String, dynamic> json) {
    final config = json['proctoringConfig'];

    return TeacherAssessmentDetailModel(
      assessment: TeacherAssessmentModel.fromJson(json),
      maxAttempt: asIntOrNull(json['maxAttempt']) ?? 1,
      questions: asObjectList(json['questions'])
          .map(AssessmentQuestionRowModel.fromJson)
          .toList(growable: false),
      courseMaterialId: asStringOrNull(json['courseMaterialId']),
      isLateSubmissionAllowed: asBool(json['isLateSubmissionAllowed']),
      latePenalty: asInt(json['latePenalty']),
      isAllowResubmission: asBool(json['isAllowResubmission']),
      isProctored: asBool(json['isProctored']),
      durationMinutes: asIntOrNull(json['durationMinutes']),
      maxViolations: asIntOrNull(json['maxViolations']),
      proctoringConfig: config is Map<String, dynamic>
          ? {
              for (final signal in ProctoringSignal.options)
                signal: asBool(config[signal]),
            }
          : null,
      fileIds: asStringList(json['fileIds']),
      creatorName: asStringOrNull(json['creatorName']),
    );
  }
}
