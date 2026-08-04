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
    this.languageTemplates = const {},
    this.moduleName,
    this.topicName,
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

  /// Starter code keyed by language id.
  final Map<String, String> languageTemplates;
  final String? moduleName;
  final String? topicName;

  bool get isCoding => type == 'coding';
  bool get isObjective => type == 'mcq' || type == 'true_false';
  bool get allowsMultiple => answerType == 'multiple';

  @override
  List<Object?> get props => [id, title, type, difficulty, points, description];
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
