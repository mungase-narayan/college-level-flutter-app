import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// One row of `GET /assessments` — an assignment or a quiz.
///
/// Both tabs read the **same** payload and split it on [category]; there is no
/// server-side filter for it.
class TeacherAssessment extends Equatable {
  const TeacherAssessment({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.status,
    required this.totalMarks,
    required this.startDate,
    required this.endDate,
    this.description,
    this.passingMarks,
    this.courseId,
    this.divisionId,
    this.divisionName,
    this.resultsPublishedAt,
    this.submissionCount = 0,
    this.evaluatedCount = 0,
  });

  final String id;
  final String title;
  final String category;
  final String type;
  final String status;
  final int totalMarks;
  final String startDate;
  final String endDate;
  final String? description;
  final int? passingMarks;
  final String? courseId;

  /// Null when the assessment is semester-wide rather than section-scoped.
  final String? divisionId;
  final String? divisionName;

  /// Set once scores are released to students; null means withheld.
  final String? resultsPublishedAt;
  final int submissionCount;
  final int evaluatedCount;

  bool get isQuiz => AssessmentCategory.isQuiz(category);
  bool get isQuestionType => type == AssessmentType.questions;
  bool get resultsPublished => resultsPublishedAt != null;

  /// Semester-wide assessments carry no division and reach every section.
  bool get isSemesterWide => divisionId == null;

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        type,
        status,
        totalMarks,
        passingMarks,
        startDate,
        endDate,
        resultsPublishedAt,
        submissionCount,
        evaluatedCount,
      ];
}

/// `GET /assessments/:id` — the row plus everything the form and the results
/// header need.
class TeacherAssessmentDetail extends Equatable {
  const TeacherAssessmentDetail({
    required this.assessment,
    required this.maxAttempt,
    required this.questions,
    this.courseMaterialId,
    this.isLateSubmissionAllowed = false,
    this.latePenalty = 0,
    this.isAllowResubmission = false,
    this.isProctored = false,
    this.durationMinutes,
    this.maxViolations,
    this.proctoringConfig,
    this.fileIds = const [],
    this.creatorName,
  });

  final TeacherAssessment assessment;
  final int maxAttempt;
  final List<AssessmentQuestionRow> questions;
  final String? courseMaterialId;
  final bool isLateSubmissionAllowed;
  final int latePenalty;
  final bool isAllowResubmission;
  final bool isProctored;
  final int? durationMinutes;
  final int? maxViolations;

  /// The six enforcement signals, keyed by [ProctoringSignal]. Null when the
  /// assessment is not proctored.
  final Map<String, bool>? proctoringConfig;
  final List<String> fileIds;
  final String? creatorName;

  String get id => assessment.id;

  /// For question-typed assessments the marks come from the attached questions —
  /// the server recomputes and overwrites whatever the client sent.
  int get derivedTotalMarks => assessment.isQuestionType
      ? questions.fold(0, (sum, q) => sum + (q.points ?? 0))
      : assessment.totalMarks;

  @override
  List<Object?> get props => [assessment, maxAttempt, questions, isProctored];
}

/// A question attached to an assessment.
class AssessmentQuestionRow extends Equatable {
  const AssessmentQuestionRow({
    required this.id,
    required this.questionId,
    required this.order,
    this.title,
    this.type,
    this.difficulty,
    this.points,
  });

  /// The **join-row** id. Detaching a question uses this, not [questionId] —
  /// passing the wrong one fails silently.
  final String id;
  final String questionId;
  final int order;
  final String? title;
  final String? type;
  final String? difficulty;
  final int? points;

  @override
  List<Object?> get props => [id, questionId, order, title, points];
}

/// `assessment.category`.
class AssessmentCategory {
  const AssessmentCategory._();

  static const courseAssignment = 'course_assignment';
  static const courseMaterialAssignment = 'course_material_assignment';
  static const quiz = 'quiz';

  /// Readable and filterable, but this app never creates one — the web's form
  /// cannot produce it either.
  static const liveQuiz = 'live_quiz';

  /// The two categories the Quiz tab owns; everything else is an assignment.
  static bool isQuiz(String value) => value == quiz || value == liveQuiz;

  static String label(String value) => switch (value) {
        courseAssignment => 'Course Assignment',
        courseMaterialAssignment => 'Material Assignment',
        quiz => 'Quiz',
        liveQuiz => 'Live Quiz',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        courseAssignment => TwColors.indigo,
        courseMaterialAssignment => TwColors.teal,
        quiz => TwColors.amber,
        liveQuiz => TwColors.rose,
        _ => TwColors.slate,
      };
}

/// `assessment.type` — immutable once created.
class AssessmentType {
  const AssessmentType._();

  static const submission = 'submission';
  static const questions = 'questions';

  static const options = [submission, questions];

  static String label(String value) => switch (value) {
        submission => 'Submission',
        questions => 'Questions',
        _ => value,
      };

  static TwShade shade(String value) =>
      value == questions ? TwColors.violet : TwColors.blue;
}

/// `assessment.status`.
class AssessmentStatus {
  const AssessmentStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const closed = 'closed';
  static const inactive = 'inactive';
  static const archived = 'archived';

  static const options = [draft, active, closed, inactive, archived];

  static String label(String value) => switch (value) {
        draft => 'Draft',
        active => 'Active',
        closed => 'Closed',
        inactive => 'Inactive',
        archived => 'Archived',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        draft => TwColors.slate,
        active => TwColors.emerald,
        closed => TwColors.rose,
        inactive => TwColors.amber,
        archived => TwColors.slate,
        _ => TwColors.slate,
      };
}

/// The six proctoring signals, in the order the form lists them.
class ProctoringSignal {
  const ProctoringSignal._();

  static const fullscreen = 'fullscreen';
  static const tabSwitch = 'tabSwitch';
  static const copyPaste = 'copyPaste';
  static const rightClick = 'rightClick';
  static const resize = 'resize';
  static const print = 'print';

  static const options = [
    fullscreen,
    tabSwitch,
    copyPaste,
    rightClick,
    resize,
    print,
  ];

  /// All on — what the server applies when a quiz is proctored with no config.
  static Map<String, bool> get defaults => {
        for (final signal in options) signal: true,
      };

  static String label(String value) => switch (value) {
        fullscreen => 'Enforce fullscreen',
        tabSwitch => 'Detect tab switch / minimize',
        copyPaste => 'Block copy & paste',
        rightClick => 'Block right-click',
        resize => 'Detect window resize',
        print => 'Block printing',
        _ => value,
      };
}

/// Question types, shared by the bank picker and the grading screen.
class QuestionType {
  const QuestionType._();

  static const mcq = 'mcq';
  static const trueFalse = 'true_false';
  static const subjective = 'subjective';
  static const coding = 'coding';

  static const options = [mcq, trueFalse, subjective, coding];

  /// Whether the answer is picked from options rather than written.
  static bool isChoice(String value) => value == mcq || value == trueFalse;

  static String label(String value) => switch (value) {
        mcq => 'MCQ',
        trueFalse => 'True/False',
        subjective => 'Subjective',
        coding => 'Coding',
        _ => value,
      };
}

/// Question difficulty, used by the bank picker.
class QuestionDifficulty {
  const QuestionDifficulty._();

  static const easy = 'easy';
  static const medium = 'medium';
  static const hard = 'hard';

  static const options = [easy, medium, hard];

  static String label(String value) => switch (value) {
        easy => 'Easy',
        medium => 'Medium',
        hard => 'Hard',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        easy => TwColors.emerald,
        medium => TwColors.amber,
        hard => TwColors.rose,
        _ => TwColors.slate,
      };
}

/// Question category, used by the bank picker's filter.
class QuestionCategory {
  const QuestionCategory._();

  static const practice = 'practice';
  static const exam = 'exam';
  static const other = 'other';

  static const options = [practice, exam, other];

  static String label(String value) => switch (value) {
        practice => 'Practice',
        exam => 'Exam',
        other => 'Other',
        _ => value,
      };
}
