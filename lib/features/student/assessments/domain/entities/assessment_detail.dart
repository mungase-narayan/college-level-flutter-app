import 'package:equatable/equatable.dart';

import 'student_assessment.dart';

/// `GET /student/assignments/:id`.
///
/// The backend swaps the question projection depending on state: once the
/// attempt is finished **and** results are published it adds the answer key
/// (`answers`, `explanation`, `modelAnswer`); before that those fields are
/// absent and per-question grading is stripped from [answers].
class AssessmentDetail extends Equatable {
  const AssessmentDetail({
    required this.assessment,
    required this.resultsPublished,
    this.questions = const [],
    this.answers = const [],
    this.submission,
  });

  final StudentAssessment assessment;
  final bool resultsPublished;
  final List<AssessmentQuestion> questions;

  /// The student's saved per-question answers, keyed by assessment question.
  final List<QuestionAnswer> answers;
  final AttemptSubmission? submission;

  bool get hasStarted => submission != null;

  bool get isSubmitted =>
      submission?.status == AssessmentStatus.submitted ||
      submission?.status == AssessmentStatus.evaluated;

  /// Which screen to show — the port of the React `detail.tsx` branching.
  ///
  /// A closed window without a submission is read-only too: there is nothing
  /// left to attempt.
  AssessmentView viewFor(DateTime now) {
    if (isSubmitted) return AssessmentView.review;
    if (assessment.isWindowClosed(now)) return AssessmentView.closed;
    if (hasStarted) return AssessmentView.attempt;
    return AssessmentView.intro;
  }

  /// The saved answer for a question, if any.
  QuestionAnswer? answerFor(String assessmentQuestionId) {
    for (final answer in answers) {
      if (answer.assessmentQuestionId == assessmentQuestionId) return answer;
    }
    return null;
  }

  /// Answers indexed by `assessmentQuestionId`, for the attempt runner.
  Map<String, QuestionAnswer> get answersByQuestion => {
        for (final answer in answers) answer.assessmentQuestionId: answer,
      };

  /// Replaces one answer, returning a new detail.
  ///
  /// The runner edits through this rather than mutating a map on the side:
  /// answers are part of the emitted state, so a changed answer changes state
  /// equality and the UI actually rebuilds.
  AssessmentDetail withAnswer(QuestionAnswer answer) {
    final next = [
      for (final existing in answers)
        if (existing.assessmentQuestionId != answer.assessmentQuestionId) existing,
      answer,
    ];
    return copyWith(answers: next);
  }

  AssessmentDetail copyWith({
    List<QuestionAnswer>? answers,
    AttemptSubmission? submission,
  }) =>
      AssessmentDetail(
        assessment: assessment,
        resultsPublished: resultsPublished,
        questions: questions,
        answers: answers ?? this.answers,
        submission: submission ?? this.submission,
      );

  @override
  List<Object?> get props =>
      [assessment, resultsPublished, questions, answers, submission];
}

enum AssessmentView { intro, attempt, review, closed }

/// One question inside an assessment.
class AssessmentQuestion extends Equatable {
  const AssessmentQuestion({
    required this.assessmentQuestionId,
    required this.questionId,
    required this.title,
    required this.type,
    required this.points,
    this.order = 0,
    this.description,
    this.difficulty,
    this.options = const [],
    this.answerType,
    this.attachments = const [],
    this.correctAnswers,
    this.explanation,
    this.modelAnswer,
  });

  /// The id the submit payload references — **not** the question id.
  final String assessmentQuestionId;
  final String questionId;
  final String title;

  /// `mcq | true_false | subjective | coding`.
  final String type;
  final int points;
  final int order;
  final String? description;
  final String? difficulty;
  final List<AnswerOption> options;

  /// `single | multiple` for MCQs.
  final String? answerType;
  final List<String> attachments;

  /// Review-only: present once results are published.
  final List<String>? correctAnswers;
  final String? explanation;
  final String? modelAnswer;

  bool get isObjective => type == 'mcq' || type == 'true_false';
  bool get allowsMultiple => answerType == 'multiple';

  String get typeLabel => switch (type) {
        'mcq' => 'MCQ',
        'true_false' => 'True / False',
        'subjective' => 'Subjective',
        'coding' => 'Coding',
        _ => type,
      };

  @override
  List<Object?> get props => [assessmentQuestionId, questionId, title, type, points];
}

class AnswerOption extends Equatable {
  const AnswerOption({required this.id, required this.text});

  final String id;
  final String text;

  @override
  List<Object?> get props => [id, text];
}

/// The student's answer to one question.
class QuestionAnswer extends Equatable {
  const QuestionAnswer({
    required this.assessmentQuestionId,
    required this.questionId,
    this.id,
    this.questionType,
    this.selectedAnswers = const [],
    this.answerText,
    this.code,
    this.language,
    this.studentNote,
    this.isCorrect,
    this.score,
    this.maxScore,
    this.feedback,
    this.testCasesPassed,
    this.testCasesTotal,
  });

  final String assessmentQuestionId;
  final String questionId;
  final String? id;
  final String? questionType;
  final List<String> selectedAnswers;
  final String? answerText;
  final String? code;
  final String? language;
  final String? studentNote;

  /// Null until results are published — grading is stripped before that.
  final bool? isCorrect;
  final int? score;
  final int? maxScore;
  final String? feedback;
  final int? testCasesPassed;
  final int? testCasesTotal;

  /// Whether this counts as answered, matching the React `isAnswered`.
  bool get isAnswered {
    switch (questionType) {
      case 'mcq':
      case 'true_false':
        return selectedAnswers.isNotEmpty;
      case 'coding':
        return (code ?? '').trim().isNotEmpty;
      default:
        return (answerText ?? '').trim().isNotEmpty;
    }
  }

  QuestionAnswer copyWith({
    List<String>? selectedAnswers,
    String? answerText,
    String? code,
  }) =>
      QuestionAnswer(
        assessmentQuestionId: assessmentQuestionId,
        questionId: questionId,
        id: id,
        questionType: questionType,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        answerText: answerText ?? this.answerText,
        code: code ?? this.code,
        language: language,
        studentNote: studentNote,
        isCorrect: isCorrect,
        score: score,
        maxScore: maxScore,
        feedback: feedback,
        testCasesPassed: testCasesPassed,
        testCasesTotal: testCasesTotal,
      );

  @override
  List<Object?> get props => [
        assessmentQuestionId,
        questionId,
        selectedAnswers,
        answerText,
        code,
        isCorrect,
        score,
      ];
}

/// The submission row on the detail payload — richer than the list variant.
class AttemptSubmission extends Equatable {
  const AttemptSubmission({
    required this.id,
    required this.status,
    required this.attempt,
    this.totalScore,
    this.maxScore,
    this.timeSpentSeconds = 0,
    this.startedAt,
    this.submittedAt,
    this.evaluatedAt,
    this.note,
    this.feedback,
    this.isLate = false,
    this.violationCount = 0,
    this.autoSubmitted = false,
    this.fileIds = const [],
  });

  final String id;
  final String status;
  final int attempt;
  final int? totalScore;
  final int? maxScore;
  final int timeSpentSeconds;
  final String? startedAt;
  final String? submittedAt;
  final String? evaluatedAt;
  final String? note;
  final String? feedback;
  final bool isLate;
  final int violationCount;
  final bool autoSubmitted;

  /// Files the student handed in. Seeds the attachment list when a draft is
  /// resumed, and is what the review screen lists.
  final List<String> fileIds;

  @override
  List<Object?> get props =>
      [id, status, attempt, totalScore, maxScore, submittedAt, note, fileIds];
}
