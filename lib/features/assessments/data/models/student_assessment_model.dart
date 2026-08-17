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
    super.course,
    super.creator,
    super.fileIds,
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
        // Both are sent only by `/student/assignments/all`; a per-course row
        // simply has no such keys, so they stay null there.
        course: json['course'] is Map<String, dynamic>
            ? _courseRef(json['course'] as Map<String, dynamic>)
            : null,
        creator: json['creator'] is Map<String, dynamic>
            ? _creatorRef(json['creator'] as Map<String, dynamic>)
            : null,
        fileIds: _strings(json['fileIds']),
      );
}

/// The API sends `null` rather than `[]` for an assessment with no attachments.
List<String> _strings(Object? value) =>
    (value as List?)?.whereType<String>().toList(growable: false) ??
    const <String>[];

AssessmentCourseRef _courseRef(Map<String, dynamic> json) => AssessmentCourseRef(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      colorCode: json['colorCode'] as String?,
    );

AssessmentCreatorRef _creatorRef(Map<String, dynamic> json) =>
    AssessmentCreatorRef(
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );

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
