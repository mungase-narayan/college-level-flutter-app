import '../../domain/entities/student_assessment.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();

/// JSON → [StudentAssessment].
class StudentAssessmentModel extends StudentAssessment {
  const StudentAssessmentModel({
    required super.id,
    required super.title,
    required super.category,
    required super.type,
    required super.totalMarks,
    required super.resultsPublished,
    super.description,
    super.startDate,
    super.endDate,
    super.isLateSubmissionAllowed,
    super.latePenalty,
    super.isAllowResubmission,
    super.maxAttempt,
    super.isProctored,
    super.durationMinutes,
    super.submission,
  });

  factory StudentAssessmentModel.fromJson(Map<String, dynamic> json) =>
      StudentAssessmentModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        category: json['category'] as String? ?? 'course_assignment',
        type: json['type'] as String? ?? 'submission',
        totalMarks: _int(json['totalMarks']),
        // The server sends this flag alongside the row; fall back to deriving
        // it from the timestamp if it is ever absent.
        resultsPublished:
            json['resultsPublished'] as bool? ?? json['resultsPublishedAt'] != null,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        isLateSubmissionAllowed: json['isLateSubmissionAllowed'] as bool? ?? false,
        latePenalty: _int(json['latePenalty']),
        isAllowResubmission: json['isAllowResubmission'] as bool? ?? false,
        maxAttempt: _int(json['maxAttempt'], 1),
        isProctored: json['isProctored'] as bool? ?? false,
        durationMinutes: _intOrNull(json['durationMinutes']),
        submission: json['submission'] is Map<String, dynamic>
            ? AssessmentSubmissionModel.fromJson(
                json['submission'] as Map<String, dynamic>,
              )
            : null,
      );
}

class AssessmentSubmissionModel extends AssessmentSubmission {
  const AssessmentSubmissionModel({
    required super.id,
    required super.status,
    required super.attempt,
    super.totalScore,
    super.maxScore,
    super.timeSpentSeconds,
    super.submittedAt,
    super.evaluatedAt,
  });

  factory AssessmentSubmissionModel.fromJson(Map<String, dynamic> json) =>
      AssessmentSubmissionModel(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'in_progress',
        attempt: _int(json['attempt'], 1),
        // Null while results are unpublished — the backend redacts the score
        // rather than sending a zero, so don't coerce it.
        totalScore: _intOrNull(json['totalScore']),
        maxScore: _intOrNull(json['maxScore']),
        timeSpentSeconds: _int(json['timeSpentSeconds']),
        submittedAt: json['submittedAt'] as String?,
        evaluatedAt: json['evaluatedAt'] as String?,
      );
}
