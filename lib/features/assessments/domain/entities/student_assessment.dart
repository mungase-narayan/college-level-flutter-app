import 'package:equatable/equatable.dart';

/// One row of `GET /student/assignments?courseId=…`.
///
/// The endpoint returns the whole `assessments` row plus `resultsPublished` and
/// the student's latest [submission]. Omitting `category` excludes quizzes, so
/// the Assignments and Quiz tabs never bleed into each other.
class StudentAssessment extends Equatable {
  const StudentAssessment({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.totalMarks,
    required this.resultsPublished,
    this.description,
    this.startDate,
    this.endDate,
    this.isLateSubmissionAllowed = false,
    this.latePenalty = 0,
    this.isAllowResubmission = false,
    this.maxAttempt = 1,
    this.isProctored = false,
    this.durationMinutes,
    this.submission,
  });

  final String id;
  final String title;
  final String? description;

  /// `course_assignment | course_material_assignment | quiz | live_quiz`.
  final String category;

  /// `submission` (free-form upload) or `questions` (the attempt runner).
  final String type;
  final int totalMarks;

  /// Scores stay hidden until the teacher publishes results.
  final bool resultsPublished;
  final String? startDate;
  final String? endDate;
  final bool isLateSubmissionAllowed;
  final int latePenalty;
  final bool isAllowResubmission;
  final int maxAttempt;
  final bool isProctored;
  final int? durationMinutes;

  /// The student's latest attempt, or null if they've never started.
  final AssessmentSubmission? submission;

  /// Which board section this belongs in — the port of `statusKeyOf`.
  String get statusKey => submission?.status ?? AssessmentStatus.notStarted;

  /// `!isLateSubmissionAllowed && endDate < now` — the port of
  /// `isAttemptWindowClosed`. A closed window turns Start into View.
  bool isWindowClosed(DateTime now) {
    if (isLateSubmissionAllowed) return false;
    final end = DateTime.tryParse(endDate ?? '');
    return end != null && end.toLocal().isBefore(now);
  }

  bool notOpenYet(DateTime now) {
    final start = DateTime.tryParse(startDate ?? '');
    return start != null && now.isBefore(start.toLocal());
  }

  bool get isSubmitted =>
      statusKey == AssessmentStatus.submitted ||
      statusKey == AssessmentStatus.evaluated;

  /// The label on the row's call to action, matching `actionText`.
  String actionText(DateTime now) {
    if (isSubmitted || isWindowClosed(now)) return 'View';
    if (statusKey == AssessmentStatus.inProgress) return 'Continue';
    return 'Start';
  }

  /// The outcome line, matching `outcomeText`: a score once published,
  /// otherwise what the student is waiting on.
  String outcomeText() {
    switch (statusKey) {
      case AssessmentStatus.evaluated:
        if (!resultsPublished) return 'Result not published';
        final score = submission?.totalScore;
        return score == null
            ? 'Awaiting evaluation'
            : '$score/${submission?.maxScore ?? totalMarks}';
      case AssessmentStatus.submitted:
        return 'Awaiting evaluation';
      case AssessmentStatus.inProgress:
        return 'Continue your attempt';
      default:
        return '';
    }
  }

  @override
  List<Object?> get props => [id, title, category, type, totalMarks, submission];
}

class AssessmentSubmission extends Equatable {
  const AssessmentSubmission({
    required this.id,
    required this.status,
    required this.attempt,
    this.totalScore,
    this.maxScore,
    this.timeSpentSeconds = 0,
    this.submittedAt,
    this.evaluatedAt,
  });

  final String id;

  /// `in_progress | submitted | evaluated`.
  final String status;
  final int attempt;

  /// Null while results are unpublished — the server redacts it.
  final int? totalScore;
  final int? maxScore;
  final int timeSpentSeconds;
  final String? submittedAt;
  final String? evaluatedAt;

  @override
  List<Object?> get props =>
      [id, status, attempt, totalScore, maxScore, timeSpentSeconds];
}

/// The four board sections, in the order the React `STATUS_ORDER` renders them.
class AssessmentStatus {
  const AssessmentStatus._();

  static const notStarted = 'not_started';
  static const inProgress = 'in_progress';
  static const submitted = 'submitted';
  static const evaluated = 'evaluated';

  static const order = [notStarted, inProgress, submitted, evaluated];

  static String label(String status) => switch (status) {
        notStarted => 'Not Started',
        inProgress => 'In Progress',
        submitted => 'Submitted',
        evaluated => 'Evaluated',
        _ => status,
      };

  /// The sub-label on each section header, from `STATUS_META`.
  static String hint(String status) => switch (status) {
        notStarted => 'Yet to attempt',
        inProgress => 'Attempt started',
        submitted => 'Awaiting evaluation',
        evaluated => 'Results published',
        _ => '',
      };
}
