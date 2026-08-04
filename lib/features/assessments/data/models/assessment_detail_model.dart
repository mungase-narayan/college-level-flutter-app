import '../../domain/entities/assessment_detail.dart';
import 'student_assessment_model.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];
List<String> _strings(Object? value) =>
    (value as List?)?.map((e) => '$e').toList(growable: false) ?? const [];

/// JSON → [AssessmentDetail].
class AssessmentDetailModel extends AssessmentDetail {
  const AssessmentDetailModel({
    required super.assessment,
    required super.resultsPublished,
    super.questions,
    super.answers,
    super.submission,
  });

  factory AssessmentDetailModel.fromJson(Map<String, dynamic> json) {
    final resultsPublished = json['resultsPublished'] as bool? ?? false;
    final assessmentJson = _map(json['assessment']);

    return AssessmentDetailModel(
      // The list model already knows this row shape; reuse it, injecting the
      // publish flag which lives one level up on the detail payload.
      assessment: StudentAssessmentModel.fromJson({
        ...assessmentJson,
        'resultsPublished': resultsPublished,
      }),
      resultsPublished: resultsPublished,
      questions: _maps(json['questions'])
          .map(AssessmentQuestionModel.fromJson)
          .toList(growable: false),
      answers: _maps(json['answers'])
          .map(QuestionAnswerModel.fromJson)
          .toList(growable: false),
      submission: json['submission'] is Map<String, dynamic>
          ? AttemptSubmissionModel.fromJson(json['submission'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AssessmentQuestionModel extends AssessmentQuestion {
  const AssessmentQuestionModel({
    required super.assessmentQuestionId,
    required super.questionId,
    required super.title,
    required super.type,
    required super.points,
    super.order,
    super.description,
    super.difficulty,
    super.options,
    super.answerType,
    super.attachments,
    super.correctAnswers,
    super.explanation,
    super.modelAnswer,
  });

  factory AssessmentQuestionModel.fromJson(Map<String, dynamic> json) =>
      AssessmentQuestionModel(
        assessmentQuestionId: json['assessmentQuestionId'] as String? ?? '',
        questionId: json['questionId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'mcq',
        points: _int(json['points'], 1),
        order: _int(json['order']),
        description: json['description'] as String?,
        difficulty: json['difficulty'] as String?,
        answerType: json['answerType'] as String?,
        options: _options(json['options']),
        attachments: _strings(json['attachments']),
        // Present only in the review projection.
        correctAnswers:
            json['answers'] == null ? null : _strings(json['answers']),
        explanation: json['explanation'] as String?,
        modelAnswer: json['modelAnswer'] as String?,
      );

  /// `options` is jsonb — a list of objects, or plain strings for a
  /// hand-authored question.
  static List<AnswerOption> _options(Object? value) {
    if (value is! List) return const [];
    final result = <AnswerOption>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is Map) {
        result.add(
          AnswerOption(
            id: '${entry['id'] ?? entry['key'] ?? index}',
            text: '${entry['text'] ?? entry['label'] ?? entry['value'] ?? ''}',
          ),
        );
      } else if (entry is String) {
        result.add(AnswerOption(id: '$index', text: entry));
      }
    }
    return result;
  }
}

class QuestionAnswerModel extends QuestionAnswer {
  const QuestionAnswerModel({
    required super.assessmentQuestionId,
    required super.questionId,
    super.id,
    super.questionType,
    super.selectedAnswers,
    super.answerText,
    super.code,
    super.language,
    super.studentNote,
    super.isCorrect,
    super.score,
    super.maxScore,
    super.feedback,
    super.testCasesPassed,
    super.testCasesTotal,
  });

  factory QuestionAnswerModel.fromJson(Map<String, dynamic> json) =>
      QuestionAnswerModel(
        id: json['id'] as String?,
        assessmentQuestionId: json['assessmentQuestionId'] as String? ?? '',
        questionId: json['questionId'] as String? ?? '',
        questionType: json['questionType'] as String?,
        selectedAnswers: _strings(json['selectedAnswers']),
        answerText: json['answerText'] as String?,
        code: json['code'] as String?,
        language: json['language'] as String?,
        studentNote: json['studentNote'] as String?,
        // Grading is stripped until results publish — keep these nullable.
        isCorrect: json['isCorrect'] as bool?,
        score: _intOrNull(json['score']),
        maxScore: _intOrNull(json['maxScore']),
        feedback: json['feedback'] as String?,
        testCasesPassed: _intOrNull(json['testCasesPassed']),
        testCasesTotal: _intOrNull(json['testCasesTotal']),
      );
}

class AttemptSubmissionModel extends AttemptSubmission {
  const AttemptSubmissionModel({
    required super.id,
    required super.status,
    required super.attempt,
    super.totalScore,
    super.maxScore,
    super.timeSpentSeconds,
    super.startedAt,
    super.submittedAt,
    super.evaluatedAt,
    super.note,
    super.feedback,
    super.isLate,
    super.violationCount,
    super.autoSubmitted,
  });

  factory AttemptSubmissionModel.fromJson(Map<String, dynamic> json) =>
      AttemptSubmissionModel(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'in_progress',
        attempt: _int(json['attempt'], 1),
        totalScore: _intOrNull(json['totalScore']),
        maxScore: _intOrNull(json['maxScore']),
        timeSpentSeconds: _int(json['timeSpentSeconds']),
        startedAt: json['startedAt'] as String?,
        submittedAt: json['submittedAt'] as String?,
        evaluatedAt: json['evaluatedAt'] as String?,
        note: json['note'] as String?,
        feedback: json['feedback'] as String?,
        isLate: json['isLate'] as bool? ?? false,
        violationCount: _int(json['violationCount']),
        autoSubmitted: json['autoSubmitted'] as bool? ?? false,
      );
}
