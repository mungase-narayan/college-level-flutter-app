import 'package:equatable/equatable.dart';

import 'practice_question.dart';

/// What a submitted attempt amounts to.
///
/// The server sends no verdict field — it sends `status` plus a nullable
/// `isCorrect`, and the three meaningful states fall out of the pair. Deriving
/// it once here keeps every screen from re-deriving it slightly differently.
enum PracticeVerdict {
  /// Awaiting a human, or awaiting a code runner that was not available.
  pending,
  correct,
  wrong,
}

/// One row of `practice_submissions` — a single attempt at a question.
class PracticeAttempt extends Equatable {
  const PracticeAttempt({
    required this.id,
    required this.questionId,
    required this.questionType,
    required this.attempt,
    required this.status,
    this.isCorrect,
    this.score,
    this.maxScore,
    this.pointsAwarded = 0,
    this.selectedAnswers = const [],
    this.answerText,
    this.attachments = const [],
    this.code,
    this.language,
    this.studentNote,
    this.feedback,
    this.codingResult,
    this.timeTakenSec,
    this.submittedAt,
  });

  final String id;
  final String questionId;
  final String questionType;

  /// 1-based, and monotonic per question — attempts are unlimited.
  final int attempt;

  /// `pending_review | evaluated`.
  final String status;

  /// Null while pending: an ungraded attempt is not a wrong one.
  final bool? isCorrect;

  final int? score;
  final int? maxScore;

  /// Only ever non-zero on the *first* solve; a re-solve earns nothing.
  final int pointsAwarded;

  final List<String> selectedAnswers;
  final String? answerText;
  final List<String> attachments;
  final String? code;
  final String? language;
  final String? studentNote;

  /// Teacher's remark on a reviewed answer.
  final String? feedback;

  final PracticeCodingResult? codingResult;
  final int? timeTakenSec;
  final String? submittedAt;

  bool get isPending => status == 'pending_review';

  PracticeVerdict get verdict {
    if (isPending) return PracticeVerdict.pending;
    return isCorrect == true ? PracticeVerdict.correct : PracticeVerdict.wrong;
  }

  @override
  List<Object?> get props => [id, attempt, status, isCorrect, score, pointsAwarded];
}

/// The outcome of running code against test cases — from `/run` (sample cases
/// only) or stored on a submitted attempt (every case, sample and hidden).
class PracticeCodingResult extends Equatable {
  const PracticeCodingResult({
    required this.passed,
    required this.total,
    this.compileError = false,
    this.allPassed = false,
    this.cases = const [],
    this.failureReason,
  });

  final int passed;
  final int total;
  final bool compileError;
  final bool allPassed;
  final List<PracticeCaseResult> cases;

  /// The server's own sentence — "Wrong Answer on test case 3 (2/5 passed)",
  /// "Compilation error: …". Null when everything passed.
  final String? failureReason;

  @override
  List<Object?> get props => [passed, total, compileError, allPassed, cases];
}

/// One test case's result.
///
/// Input and output are populated **only for sample cases**; a hidden case
/// reports nothing but whether it passed and how long it took.
class PracticeCaseResult extends Equatable {
  const PracticeCaseResult({
    required this.testCaseId,
    required this.status,
    required this.passed,
    this.isSample = false,
    this.timeSec,
    this.memoryKb,
    this.stdin,
    this.stdout,
    this.stderr,
    this.expectedOutput,
  });

  final String testCaseId;

  /// The runner's own description: `Accepted`, `Wrong Answer`,
  /// `Time Limit Exceeded`, `Runtime Error (NZEC)` …
  final String status;

  final bool passed;
  final bool isSample;
  final double? timeSec;
  final int? memoryKb;
  final String? stdin;
  final String? stdout;
  final String? stderr;
  final String? expectedOutput;

  @override
  List<Object?> get props => [testCaseId, status, passed, isSample];
}

/// The result of running code against the student's own input — one execution,
/// no judging, nothing stored.
class PracticeCustomRunResult extends Equatable {
  const PracticeCustomRunResult({
    required this.status,
    this.compileError = false,
    this.stdout,
    this.stderr,
    this.timeSec,
    this.memoryKb,
  });

  final String status;
  final bool compileError;
  final String? stdout;
  final String? stderr;
  final double? timeSec;
  final int? memoryKb;

  @override
  List<Object?> get props => [status, compileError, stdout, stderr];
}

/// What the student has entered but not yet submitted.
///
/// One shape for all four question types, mirroring the submit body — the
/// server takes every field as optional and reads only the ones its question
/// type calls for.
class PracticeAnswerDraft extends Equatable {
  const PracticeAnswerDraft({
    this.selectedAnswers = const [],
    this.answerText,
    this.attachments = const [],
    this.code,
    this.language,
    this.studentNote,
  });

  final List<String> selectedAnswers;
  final String? answerText;
  final List<String> attachments;
  final String? code;
  final String? language;
  final String? studentNote;

  /// Whether this draft is worth sending, per the question's type.
  ///
  /// The server accepts an empty body and scores it zero, so this is the only
  /// thing standing between a mis-tap and a wasted attempt.
  bool canSubmit(PracticeQuestion question) => switch (question.type) {
        'mcq' || 'true_false' => selectedAnswers.isNotEmpty,
        'subjective' => (answerText ?? '').trim().isNotEmpty,
        'coding' => (code ?? '').trim().isNotEmpty,
        _ => false,
      };

  PracticeAnswerDraft copyWith({
    List<String>? selectedAnswers,
    String? answerText,
    List<String>? attachments,
    String? code,
    String? language,
    String? studentNote,
  }) =>
      PracticeAnswerDraft(
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        answerText: answerText ?? this.answerText,
        attachments: attachments ?? this.attachments,
        code: code ?? this.code,
        language: language ?? this.language,
        studentNote: studentNote ?? this.studentNote,
      );

  @override
  List<Object?> get props =>
      [selectedAnswers, answerText, attachments, code, language, studentNote];
}

/// `GET /practice/questions/:id/attempts` — the history plus the question with
/// its answer key revealed.
class PracticeAttemptHistory extends Equatable {
  const PracticeAttemptHistory({required this.question, this.attempts = const []});

  /// The same question, but carrying `answers`, `explanation`, `modelAnswer`
  /// and `hints` — which the plain detail fetch withholds.
  final PracticeQuestion question;

  /// Newest attempt first, as the server orders them.
  final List<PracticeAttempt> attempts;

  @override
  List<Object?> get props => [question, attempts];
}

/// `POST /practice/questions/:id/submit` — the graded attempt plus the now-
/// revealed question.
class PracticeSubmitResult extends Equatable {
  const PracticeSubmitResult({required this.attempt, required this.question});

  final PracticeAttempt attempt;
  final PracticeQuestion question;

  @override
  List<Object?> get props => [attempt, question];
}
