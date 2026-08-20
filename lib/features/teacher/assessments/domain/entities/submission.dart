import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// One learner's attempt, as the overview lists it.
///
/// The overview payload also carries a per-question `results` matrix that the
/// web fetches and never renders; it is not parsed here either.
class SubmissionRow extends Equatable {
  const SubmissionRow({
    required this.id,
    required this.studentId,
    required this.status,
    required this.fullName,
    this.attempt = 1,
    this.totalScore,
    this.maxScore,
    this.isLate = false,
    this.violationCount = 0,
    this.violationResetCount = 0,
    this.autoSubmitted = false,
    this.timeSpentSeconds = 0,
    this.submittedAt,
    this.evaluatedAt,
    this.rollNumber,
    this.prnNumber,
    this.email,
    this.avatar,
  });

  /// The **submission** id — what the review screen is opened with.
  final String id;
  final String studentId;
  final String status;
  final String fullName;
  final int attempt;

  /// Null until anything has been scored.
  final int? totalScore;
  final int? maxScore;

  final bool isLate;
  final int violationCount;
  final int violationResetCount;
  final bool autoSubmitted;

  /// Accumulated active time on the attempt.
  final int timeSpentSeconds;

  final String? submittedAt;
  final String? evaluatedAt;
  final String? rollNumber;
  final String? prnNumber;
  final String? email;
  final String? avatar;

  /// Roll number where there is one, otherwise the email — the second line of
  /// every learner row.
  String get identifier => (rollNumber ?? '').isNotEmpty
      ? rollNumber!
      : (email ?? '');

  bool get inProgress => status == SubmissionStatus.inProgress;

  /// Null when nothing is scored out of anything, which the row shows as a
  /// dash rather than 0%.
  double? get fraction {
    final max = maxScore;
    if (max == null || max <= 0) return null;
    return (totalScore ?? 0) / max;
  }

  @override
  List<Object?> get props => [
        id,
        status,
        fullName,
        totalScore,
        maxScore,
        timeSpentSeconds,
        violationCount,
      ];
}

/// `GET /teacher/assignments/:id/overview` — the learner page plus its rollup.
class AssignmentOverview extends Equatable {
  const AssignmentOverview({
    required this.learners,
    required this.total,
    required this.evaluated,
    required this.page,
    required this.totalPages,
    this.avgPercent,
  });

  final List<SubmissionRow> learners;

  /// Attempts, not enrolled students — a learner who never started is absent.
  final int total;
  final int evaluated;
  final int page;
  final int totalPages;

  /// Null until something has been scored.
  final int? avgPercent;

  @override
  List<Object?> get props => [learners, total, evaluated, avgPercent, page];
}

/// One question's rollup across every submitted attempt.
class QuestionStat extends Equatable {
  const QuestionStat({
    required this.assessmentQuestionId,
    required this.questionId,
    required this.order,
    required this.title,
    required this.type,
    required this.points,
    required this.totalResponses,
    required this.correct,
    required this.incorrect,
    this.accuracy,
    this.options = const [],
  });

  final String assessmentQuestionId;
  final String questionId;
  final int order;
  final String title;
  final String type;
  final int points;
  final int totalResponses;
  final int correct;
  final int incorrect;

  /// Null for a question the server cannot auto-grade — coding and subjective.
  final int? accuracy;

  final List<QuestionOptionStat> options;

  bool get isAutoGraded => accuracy != null;
  bool get hasResults => correct + incorrect > 0;

  /// Choice questions are the only ones with an option distribution to show.
  bool get isChoice => QuestionStatShade.isChoice(type);

  @override
  List<Object?> get props => [
        assessmentQuestionId,
        title,
        type,
        points,
        totalResponses,
        correct,
        incorrect,
        accuracy,
        options,
      ];
}

class QuestionOptionStat extends Equatable {
  const QuestionOptionStat({
    required this.id,
    required this.label,
    required this.count,
    required this.percent,
    required this.isCorrect,
  });

  final String id;
  final String label;
  final int count;
  final int percent;
  final bool isCorrect;

  @override
  List<Object?> get props => [id, label, count, percent, isCorrect];
}

/// The accuracy bands the chart and the badges share.
class QuestionStatShade {
  const QuestionStatShade._();

  static bool isChoice(String type) =>
      type == 'mcq' || type == 'true_false';

  static TwShade forAccuracy(int accuracy) => accuracy >= 70
      ? TwColors.emerald
      : accuracy >= 40
          ? TwColors.amber
          : TwColors.rose;
}

/// `GET /teacher/assignments/:id/submissions/:sid` — one attempt in full.
class SubmissionDetail extends Equatable {
  const SubmissionDetail({
    required this.submission,
    required this.answers,
    this.proctorEvents = const [],
  });

  final SubmissionRow submission;
  final List<SubmissionAnswer> answers;
  final List<ProctorEvent> proctorEvents;

  /// Violations grouped by kind, which is all the panel reports.
  Map<String, int> get violationsByType {
    final counts = <String, int>{};
    for (final event in proctorEvents) {
      counts[event.eventType] = (counts[event.eventType] ?? 0) + 1;
    }
    return counts;
  }

  @override
  List<Object?> get props => [submission, answers, proctorEvents];
}

/// The submission-type extras, which only that shape carries.
class SubmissionNote extends Equatable {
  const SubmissionNote({this.note, this.fileIds = const [], this.feedback});

  final String? note;
  final List<String> fileIds;
  final String? feedback;

  @override
  List<Object?> get props => [note, fileIds, feedback];
}

/// One answered question inside a submission.
class SubmissionAnswer extends Equatable {
  const SubmissionAnswer({
    required this.id,
    required this.assessmentQuestionId,
    required this.questionId,
    required this.questionType,
    required this.questionTitle,
    required this.questionPoints,
    this.selectedAnswers = const [],
    this.answerText,
    this.attachments = const [],
    this.code,
    this.language,
    this.studentNote,
    this.isCorrect,
    this.score,
    this.maxScore,
    this.testCasesPassed,
    this.testCasesTotal,
    this.feedback,
    this.questionDescription,
    this.questionOptions = const [],
    this.questionAnswers = const [],
    this.questionModelAnswer,
  });

  /// The **answer** id. Every grading edit is keyed by it, and it is what
  /// `questionEvaluations[].questionSubmissionId` carries.
  final String id;

  final String assessmentQuestionId;
  final String questionId;
  final String questionType;
  final String questionTitle;
  final int questionPoints;

  final List<String> selectedAnswers;
  final String? answerText;
  final List<String> attachments;
  final String? code;
  final String? language;
  final String? studentNote;

  final bool? isCorrect;
  final int? score;
  final int? maxScore;

  /// Coding auto-grade. Null for every other type, and for a coding answer
  /// that was never run.
  final int? testCasesPassed;
  final int? testCasesTotal;

  final String? feedback;
  final String? questionDescription;
  final List<AnswerOption> questionOptions;

  /// The ids of the correct options, for a choice question.
  final List<String> questionAnswers;

  final String? questionModelAnswer;

  bool get isChoice => QuestionStatShade.isChoice(questionType);

  /// Whether the student actually put something in.
  bool get hasContent =>
      selectedAnswers.isNotEmpty ||
      (answerText ?? '').trim().isNotEmpty ||
      (code ?? '').trim().isNotEmpty ||
      attachments.isNotEmpty;

  /// True only for a coding answer that was actually run.
  bool get hasTestCases =>
      questionType == 'coding' &&
      testCasesTotal != null &&
      testCasesTotal! > 0;

  /// `round(passed / total × points)` — what the auto-grader would award.
  int get testCaseScore => hasTestCases
      ? ((testCasesPassed ?? 0) / testCasesTotal! * questionPoints).round()
      : 0;

  /// The score to seed the input with: what is stored, else the coding ratio,
  /// so partial credit is visible rather than reading as ungraded.
  int? get seededScore => score ?? (hasTestCases ? testCaseScore : null);

  /// The correct/wrong toggle's seed, on the same rule.
  bool? get seededMark =>
      isCorrect ??
      (hasTestCases ? (testCasesPassed ?? 0) >= testCasesTotal! : null);

  @override
  List<Object?> get props => [
        id,
        questionType,
        questionTitle,
        questionPoints,
        selectedAnswers,
        answerText,
        code,
        isCorrect,
        score,
        testCasesPassed,
        testCasesTotal,
        feedback,
      ];
}

class AnswerOption extends Equatable {
  const AnswerOption({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

class ProctorEvent extends Equatable {
  const ProctorEvent({required this.id, required this.eventType, this.occurredAt});

  final String id;
  final String eventType;
  final String? occurredAt;

  @override
  List<Object?> get props => [id, eventType, occurredAt];
}

/// `submission.status`.
class SubmissionStatus {
  const SubmissionStatus._();

  static const inProgress = 'in_progress';

  /// Auto-scored, but still awaiting the manual half.
  static const submitted = 'submitted';

  static const evaluated = 'evaluated';

  static String label(String value) => switch (value) {
        inProgress => 'In progress',
        submitted => 'Needs review',
        evaluated => 'Evaluated',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        inProgress => TwColors.blue,
        submitted => TwColors.amber,
        evaluated => TwColors.emerald,
        _ => TwColors.slate,
      };
}

/// The eight signals a proctored attempt can trip.
class ProctorEventType {
  const ProctorEventType._();

  static String label(String value) => switch (value) {
        'fullscreen_exit' => 'Exited fullscreen',
        'tab_switch' => 'Switched tab',
        'window_blur' => 'Left window',
        'copy' => 'Copied content',
        'paste' => 'Pasted content',
        'right_click' => 'Right-clicked',
        'resize' => 'Resized window',
        'print' => 'Attempted to print',
        _ => value,
      };
}

/// How a learner ended up, on the exported result sheet.
class AssignmentOutcome {
  const AssignmentOutcome._();

  static const pass = 'pass';
  static const fail = 'fail';
  static const notAttempted = 'not_attempted';

  /// Scored but not yet passed or failed — the sheet calls it "Evaluated".
  static const pending = 'pending';

  static String label(String value) => switch (value) {
        pass => 'Pass',
        fail => 'Fail',
        notAttempted => 'Not Attempted',
        pending => 'Evaluated',
        _ => value,
      };
}

/// One row of `GET /teacher/assignments/:id/results` — every eligible student,
/// including the ones who never attempted.
class ResultRow extends Equatable {
  const ResultRow({
    required this.studentId,
    required this.fullName,
    required this.attempted,
    required this.outcome,
    required this.totalScore,
    this.rollNumber,
    this.maxScore,
    this.timeSpentSeconds = 0,
    this.submittedAt,
  });

  final String studentId;
  final String fullName;
  final bool attempted;
  final String outcome;
  final int totalScore;
  final String? rollNumber;
  final int? maxScore;
  final int timeSpentSeconds;
  final String? submittedAt;

  @override
  List<Object?> get props => [
        studentId,
        fullName,
        attempted,
        outcome,
        totalScore,
        maxScore,
        timeSpentSeconds,
      ];
}

class ResultSheet extends Equatable {
  const ResultSheet({
    required this.title,
    required this.totalMarks,
    required this.rows,
    this.passingMarks,
  });

  final String title;
  final int totalMarks;
  final List<ResultRow> rows;
  final int? passingMarks;

  @override
  List<Object?> get props => [title, totalMarks, rows, passingMarks];
}

/// The evaluate body, which switches shape on the assessment's type.
class EvaluationInput extends Equatable {
  const EvaluationInput({this.feedback, this.overallScore, this.questions});

  final String? feedback;

  /// Submission-type only: one manual total for the whole attempt.
  final int? overallScore;

  /// Question-type only.
  final List<QuestionEvaluation>? questions;

  Map<String, dynamic> toJson() => {
        'feedback': (feedback ?? '').isEmpty ? null : feedback,
        if (overallScore != null) 'overallScore': overallScore,
        if (questions != null)
          'questionEvaluations': [for (final q in questions!) q.toJson()],
      };

  @override
  List<Object?> get props => [feedback, overallScore, questions];
}

class QuestionEvaluation extends Equatable {
  const QuestionEvaluation({
    required this.questionSubmissionId,
    required this.score,
    this.feedback,
    this.isCorrect,
  });

  /// The answer id, not the question's or the join row's.
  final String questionSubmissionId;
  final int score;
  final String? feedback;
  final bool? isCorrect;

  Map<String, dynamic> toJson() => {
        'questionSubmissionId': questionSubmissionId,
        'score': score,
        'feedback': (feedback ?? '').isEmpty ? null : feedback,
        'isCorrect': isCorrect,
      };

  @override
  List<Object?> get props => [questionSubmissionId, score, feedback, isCorrect];
}
