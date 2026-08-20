import 'package:equatable/equatable.dart';

/// One row of `GET /student/practice/questions`.
class PracticeQuestionListItem extends Equatable {
  const PracticeQuestionListItem({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.points,
    required this.bookmarked,
    required this.stats,
    this.questionNumber,
    this.duration,
    this.tags = const [],
    this.courseId,
    this.subject,
    this.moduleName,
    this.topicName,
    this.totalAttempts = 0,
  });

  final String id;
  final String title;

  /// `mcq | true_false | subjective | coding`.
  final String type;

  /// `easy | medium | hard`.
  final String difficulty;
  final int points;
  final bool bookmarked;
  final PracticeQuestionStats stats;
  final int? questionNumber;
  final int? duration;
  final List<String> tags;
  final String? courseId;

  /// The course name, sent as `subject`.
  final String? subject;
  final String? moduleName;
  final String? topicName;

  /// Attempts across all students — the "popularity" signal.
  final int totalAttempts;

  String get typeLabel => switch (type) {
        'mcq' => 'MCQ',
        'true_false' => 'True / False',
        'subjective' => 'Subjective',
        'coding' => 'Coding',
        _ => type,
      };

  @override
  List<Object?> get props => [id, title, type, difficulty, points, bookmarked, stats];
}

/// The student's own record against one question.
class PracticeQuestionStats extends Equatable {
  const PracticeQuestionStats({
    required this.attempts,
    required this.correct,
    required this.attemptStatus,
    this.accuracy,
    this.bestScore,
    this.pendingReview = false,
    this.lastAttemptAt,
  });

  final int attempts;
  final int correct;

  /// `not_attempted | attempted | solved | incorrect`.
  final String attemptStatus;
  final int? accuracy;
  final int? bestScore;

  /// A subjective or coding attempt is waiting on a teacher.
  final bool pendingReview;
  final String? lastAttemptAt;

  bool get isSolved => attemptStatus == 'solved';
  bool get isAttempted => attemptStatus != 'not_attempted';

  @override
  List<Object?> get props =>
      [attempts, correct, attemptStatus, accuracy, bestScore, pendingReview, lastAttemptAt];
}

/// `GET /student/practice/questions/:id`.
///
/// The backend strips answers and solutions from the question before an
/// attempt (`sanitizeQuestionForAttempt`) and only reveals them in the review
/// payload, so those fields are absent here by design.
class PracticeQuestionDetail extends Equatable {
  const PracticeQuestionDetail({
    required this.question,
    required this.stats,
    required this.bookmarked,
    this.sampleTestCases = const [],
  });

  final PracticeQuestion question;
  final PracticeQuestionStats stats;
  final bool bookmarked;
  final List<CodingSampleCase> sampleTestCases;

  /// The same detail with the star flipped — what an optimistic toggle emits
  /// before the server has agreed.
  PracticeQuestionDetail withBookmark(bool value) => PracticeQuestionDetail(
        question: question,
        stats: stats,
        bookmarked: value,
        sampleTestCases: sampleTestCases,
      );

  @override
  List<Object?> get props => [question, stats, bookmarked, sampleTestCases];
}

class PracticeQuestion extends Equatable {
  const PracticeQuestion({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.points,
    this.description,
    this.duration,
    this.tags = const [],
    this.attachments = const [],
    this.options = const [],
    this.answerType,
    this.constraints = const [],
    this.examples = const [],
    this.languageTemplates = const [],
    this.moduleName,
    this.topicName,
    this.answers,
    this.explanation,
    this.modelAnswer,
    this.hints = const [],
  });

  final String id;
  final String title;
  final String type;
  final String difficulty;
  final int points;

  /// Markdown statement.
  final String? description;
  final int? duration;
  final List<String> tags;
  final List<String> attachments;

  /// MCQ / true-false choices, without the correct-answer flags.
  final List<QuestionOption> options;

  /// `single | multiple` — whether an MCQ accepts more than one choice.
  final String? answerType;

  /// Coding scaffolding.
  final List<String> constraints;
  final List<QuestionExample> examples;

  /// One entry per language the question can be solved in, each carrying its
  /// starter code.
  final List<QuestionLanguageTemplate> languageTemplates;
  final String? moduleName;
  final String? topicName;

  // ── Review-only ───────────────────────────────────────────────────────────
  // Null until an attempt is made: the detail endpoint sanitises them away, and
  // only `/attempts` and `/submit` hand them back.

  /// The correct option ids.
  final List<String>? answers;
  final String? explanation;
  final String? modelAnswer;
  final List<String> hints;

  /// Whether the answer key has been handed over — the two review endpoints
  /// supply it, the plain detail fetch never does.
  bool get hasSolution =>
      (answers?.isNotEmpty ?? false) ||
      (explanation ?? '').isNotEmpty ||
      (modelAnswer ?? '').isNotEmpty ||
      hints.isNotEmpty;

  bool get isCoding => type == 'coding';
  bool get isObjective => type == 'mcq' || type == 'true_false';
  bool get allowsMultiple => answerType == 'multiple';

  @override
  List<Object?> get props =>
      [id, title, type, difficulty, points, description, answers, explanation];
}

/// One language a coding question offers, with the code the student starts from.
///
/// The API's template object also carries `solutionCode`, which the backend does
/// **not** strip before sending — so it is deliberately not modelled here. A
/// field that does not exist cannot be rendered by accident.
class QuestionLanguageTemplate extends Equatable {
  const QuestionLanguageTemplate({
    required this.language,
    this.starterCode,
    this.placeholderCode,
  });

  /// `python`, `cpp`, `java` … — also what the run/submit endpoints expect.
  final String language;

  final String? starterCode;
  final String? placeholderCode;

  /// What to seed the editor with.
  String get initialCode => starterCode ?? placeholderCode ?? '';

  @override
  List<Object?> get props => [language, starterCode, placeholderCode];
}

class QuestionOption extends Equatable {
  const QuestionOption({required this.id, required this.text});

  final String id;
  final String text;

  @override
  List<Object?> get props => [id, text];
}

class QuestionExample extends Equatable {
  const QuestionExample({this.input, this.output, this.explanation});

  final String? input;
  final String? output;
  final String? explanation;

  @override
  List<Object?> get props => [input, output, explanation];
}

/// What `GET /practice/filters` offers.
///
/// Only the course list needs the round trip — type, difficulty, status and
/// sort are fixed enums the client already knows, and the endpoint returns no
/// counts.
class PracticeFilterOptions extends Equatable {
  const PracticeFilterOptions({
    this.subjects = const [],
    this.modules = const [],
    this.topics = const [],
  });

  final List<PracticeSubject> subjects;
  final List<String> modules;
  final List<String> topics;

  @override
  List<Object?> get props => [subjects, modules, topics];
}

/// A course, as the filter endpoint names it.
class PracticeSubject extends Equatable {
  const PracticeSubject({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  @override
  List<Object?> get props => [id, name, code];
}

/// A visible sample test case for a coding question.
class CodingSampleCase extends Equatable {
  const CodingSampleCase({
    required this.id,
    this.input,
    this.output,
    this.explanation,
    this.order = 0,
  });

  final String id;
  final String? input;
  final String? output;
  final String? explanation;
  final int order;

  @override
  List<Object?> get props => [id, input, output, explanation, order];
}
