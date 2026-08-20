import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/submission.dart';

class SubmissionRowModel extends SubmissionRow {
  const SubmissionRowModel({
    required super.id,
    required super.studentId,
    required super.status,
    required super.fullName,
    super.attempt,
    super.totalScore,
    super.maxScore,
    super.isLate,
    super.violationCount,
    super.violationResetCount,
    super.autoSubmitted,
    super.timeSpentSeconds,
    super.submittedAt,
    super.evaluatedAt,
    super.rollNumber,
    super.prnNumber,
    super.email,
    super.avatar,
  });

  factory SubmissionRowModel.fromJson(Map<String, dynamic> json) =>
      SubmissionRowModel(
        id: asString(json['id']),
        studentId: asString(json['studentId']),
        status: asString(json['status']),
        fullName: asString(json['userFullName']),
        attempt: asIntOrNull(json['attempt']) ?? 1,
        // Null means nothing has been scored, which the row shows as a dash
        // rather than a zero.
        totalScore: asIntOrNull(json['totalScore']),
        maxScore: asIntOrNull(json['maxScore']),
        isLate: asBool(json['isLate']),
        violationCount: asInt(json['violationCount']),
        violationResetCount: asInt(json['violationResetCount']),
        autoSubmitted: asBool(json['autoSubmitted']),
        timeSpentSeconds: asInt(json['timeSpentSeconds']),
        submittedAt: asStringOrNull(json['submittedAt']),
        evaluatedAt: asStringOrNull(json['evaluatedAt']),
        rollNumber: asStringOrNull(json['studentRollNumber']),
        prnNumber: asStringOrNull(json['studentPrnNumber']),
        email: asStringOrNull(json['userEmail']),
        avatar: asStringOrNull(json['userAvatar']),
      );
}

class AssignmentOverviewModel extends AssignmentOverview {
  const AssignmentOverviewModel({
    required super.learners,
    required super.total,
    required super.evaluated,
    required super.page,
    required super.totalPages,
    super.avgPercent,
  });

  factory AssignmentOverviewModel.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final pagination = (json['pagination'] as Map<String, dynamic>?) ?? const {};

    return AssignmentOverviewModel(
      learners: asObjectList(json['learners'])
          .map(SubmissionRowModel.fromJson)
          .toList(growable: false),
      total: asInt(summary['total']),
      evaluated: asInt(summary['evaluated']),
      // Null until something has been scored — not the same as zero.
      avgPercent: asIntOrNull(summary['avgPercent']),
      page: asIntOrNull(pagination['page']) ?? 1,
      totalPages: asIntOrNull(pagination['totalPages']) ?? 1,
    );
  }
}

class QuestionStatModel extends QuestionStat {
  const QuestionStatModel({
    required super.assessmentQuestionId,
    required super.questionId,
    required super.order,
    required super.title,
    required super.type,
    required super.points,
    required super.totalResponses,
    required super.correct,
    required super.incorrect,
    super.accuracy,
    super.options,
  });

  factory QuestionStatModel.fromJson(Map<String, dynamic> json) =>
      QuestionStatModel(
        assessmentQuestionId: asString(json['assessmentQuestionId']),
        questionId: asString(json['questionId']),
        order: asInt(json['order']),
        title: asString(json['title']),
        type: asString(json['type']),
        points: asInt(json['points']),
        totalResponses: asInt(json['totalResponses']),
        correct: asInt(json['correct']),
        incorrect: asInt(json['incorrect']),
        // Null marks a question the server cannot auto-grade, which the card
        // labels "Manual" instead of "0%".
        accuracy: asIntOrNull(json['accuracy']),
        options: asObjectList(json['options'])
            .map(QuestionOptionStatModel.fromJson)
            .toList(growable: false),
      );
}

class QuestionOptionStatModel extends QuestionOptionStat {
  const QuestionOptionStatModel({
    required super.id,
    required super.label,
    required super.count,
    required super.percent,
    required super.isCorrect,
  });

  factory QuestionOptionStatModel.fromJson(Map<String, dynamic> json) =>
      QuestionOptionStatModel(
        id: asString(json['id']),
        label: asString(json['label']),
        count: asInt(json['count']),
        percent: asInt(json['percent']),
        isCorrect: asBool(json['isCorrect']),
      );
}

class SubmissionAnswerModel extends SubmissionAnswer {
  const SubmissionAnswerModel({
    required super.id,
    required super.assessmentQuestionId,
    required super.questionId,
    required super.questionType,
    required super.questionTitle,
    required super.questionPoints,
    super.selectedAnswers,
    super.answerText,
    super.attachments,
    super.code,
    super.language,
    super.studentNote,
    super.isCorrect,
    super.score,
    super.maxScore,
    super.testCasesPassed,
    super.testCasesTotal,
    super.feedback,
    super.questionDescription,
    super.questionOptions,
    super.questionAnswers,
    super.questionModelAnswer,
  });

  factory SubmissionAnswerModel.fromJson(Map<String, dynamic> json) =>
      SubmissionAnswerModel(
        id: asString(json['id']),
        assessmentQuestionId: asString(json['assessmentQuestionId']),
        questionId: asString(json['questionId']),
        questionType: asString(json['questionType']),
        questionTitle: asString(json['questionTitle']),
        questionPoints: asInt(json['questionPoints']),
        selectedAnswers: asStringList(json['selectedAnswers']),
        answerText: asStringOrNull(json['answerText']),
        attachments: asStringList(json['attachments']),
        code: asStringOrNull(json['code']),
        language: asStringOrNull(json['language']),
        studentNote: asStringOrNull(json['studentNote']),
        // All three stay nullable: "not graded" and "graded zero" are
        // different, and the seeding rules turn on the difference.
        isCorrect: json['isCorrect'] is bool ? json['isCorrect'] as bool : null,
        score: asIntOrNull(json['score']),
        maxScore: asIntOrNull(json['maxScore']),
        testCasesPassed: asIntOrNull(json['testCasesPassed']),
        testCasesTotal: asIntOrNull(json['testCasesTotal']),
        feedback: asStringOrNull(json['feedback']),
        questionDescription: asStringOrNull(json['questionDescription']),
        questionOptions: asObjectList(json['questionOptions'])
            .map(
              (o) => AnswerOption(
                id: asString(o['id']),
                label: asString(o['label']),
              ),
            )
            .toList(growable: false),
        questionAnswers: asStringList(json['questionAnswers']),
        questionModelAnswer: asStringOrNull(json['questionModelAnswer']),
      );
}

class SubmissionDetailModel extends SubmissionDetail {
  const SubmissionDetailModel({
    required super.submission,
    required super.answers,
    super.proctorEvents,
  });

  factory SubmissionDetailModel.fromJson(Map<String, dynamic> json) =>
      SubmissionDetailModel(
        submission: SubmissionRowModel.fromJson(
          (json['submission'] as Map<String, dynamic>?) ?? const {},
        ),
        answers: asObjectList(json['answers'])
            .map(SubmissionAnswerModel.fromJson)
            .toList(growable: false),
        proctorEvents: asObjectList(json['proctorEvents'])
            .map(
              (e) => ProctorEvent(
                id: asString(e['id']),
                eventType: asString(e['eventType']),
                occurredAt: asStringOrNull(e['occurredAt']),
              ),
            )
            .toList(growable: false),
      );
}

/// The submission-type extras, read from the same `submission` object.
SubmissionNote submissionNoteFromJson(Map<String, dynamic> json) {
  final submission = (json['submission'] as Map<String, dynamic>?) ?? const {};
  return SubmissionNote(
    note: asStringOrNull(submission['note']),
    fileIds: asStringList(submission['fileIds']),
    feedback: asStringOrNull(submission['feedback']),
  );
}

class ResultRowModel extends ResultRow {
  const ResultRowModel({
    required super.studentId,
    required super.fullName,
    required super.attempted,
    required super.outcome,
    required super.totalScore,
    super.rollNumber,
    super.maxScore,
    super.timeSpentSeconds,
    super.submittedAt,
  });

  factory ResultRowModel.fromJson(Map<String, dynamic> json) => ResultRowModel(
        studentId: asString(json['studentId']),
        fullName: asString(json['fullName']),
        attempted: asBool(json['attempted']),
        outcome: asString(json['outcome']),
        totalScore: asInt(json['totalScore']),
        rollNumber: asStringOrNull(json['rollNumber']),
        maxScore: asIntOrNull(json['maxScore']),
        timeSpentSeconds: asInt(json['timeSpentSeconds']),
        submittedAt: asStringOrNull(json['submittedAt']),
      );
}

class ResultSheetModel extends ResultSheet {
  const ResultSheetModel({
    required super.title,
    required super.totalMarks,
    required super.rows,
    super.passingMarks,
  });

  factory ResultSheetModel.fromJson(Map<String, dynamic> json) {
    final assessment = (json['assessment'] as Map<String, dynamic>?) ?? const {};
    return ResultSheetModel(
      title: asString(assessment['title']),
      totalMarks: asInt(assessment['totalMarks']),
      passingMarks: asIntOrNull(assessment['passingMarks']),
      rows: asObjectList(json['rows'])
          .map(ResultRowModel.fromJson)
          .toList(growable: false),
    );
  }
}
