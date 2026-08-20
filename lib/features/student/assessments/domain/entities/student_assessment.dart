import 'package:equatable/equatable.dart';

/// One row of `GET /student/assignments?courseId=…` — or of
/// `GET /student/assignments/all`, which returns the same row plus [course] and
/// [creator].
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
    this.course,
    this.creator,
    this.fileIds = const [],
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

  /// Which course this belongs to. Only the cross-course list carries it — in a
  /// course's own tab the course is the page you are already on.
  final AssessmentCourseRef? course;

  /// The teacher who set it. Cross-course list only, and null when the server
  /// cannot resolve the author.
  final AssessmentCreatorRef? creator;

  /// The brief the teacher attached — the question paper, a rubric, a starter
  /// file. Empty for most assessments.
  final List<String> fileIds;

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

  // `endDate` and `resultsPublished` are in here alongside the obvious fields
  // because both change *on their own*: a teacher extends a deadline or
  // publishes results without anything else about the row moving. Leaving them
  // out makes the refreshed list compare equal to the stale one, and bloc drops
  // an emission equal to the current state — the card would keep the old due
  // date until the page was rebuilt for some unrelated reason.
  @override
  List<Object?> get props => [
        id,
        title,
        category,
        type,
        totalMarks,
        endDate,
        resultsPublished,
        submission,
        course,
        creator,
        fileIds,
      ];
}

/// The course an assessment belongs to, as the cross-course list carries it.
class AssessmentCourseRef extends Equatable {
  const AssessmentCourseRef({
    required this.id,
    required this.name,
    required this.code,
    this.colorCode,
  });

  final String id;
  final String name;

  /// The short code shown on the card's chip — `CS201`.
  final String code;

  /// The course's own colour, as `#RRGGBB`. Null for a course that has none, in
  /// which case the chip falls back to a neutral tint.
  final String? colorCode;

  @override
  List<Object?> get props => [id, name, code, colorCode];
}

/// The teacher who authored an assessment.
class AssessmentCreatorRef extends Equatable {
  const AssessmentCreatorRef({required this.name, this.avatar});

  final String name;
  final String? avatar;

  @override
  List<Object?> get props => [name, avatar];
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
