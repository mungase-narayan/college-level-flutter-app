import 'package:equatable/equatable.dart';

import 'practice_question.dart';

/// `GET /student/practice/daily-challenge` — today's set for the student's
/// batch/department/semester scope.
class DailyChallenge extends Equatable {
  const DailyChallenge({
    required this.available,
    required this.isOpen,
    required this.streak,
    this.set,
    this.questions = const [],
    this.completion,
    this.availableTickets = 0,
    this.timeTravelUnlocked = false,
  });

  /// False when no challenge is posted for the student's scope today.
  final bool available;

  /// Inside the `availableFrom`–`availableUntil` window and still `active`.
  final bool isOpen;
  final DailyStreak streak;
  final DailyChallengeSet? set;
  final List<PracticeQuestion> questions;
  final DailyChallengeCompletion? completion;

  /// Unused Time Travel Tickets in the student's wallet — each one re-opens a
  /// missed day (70 coins in the rewards store).
  final int availableTickets;

  /// A ticket has already been spent to unlock today's set.
  final bool timeTravelUnlocked;

  /// Solvable right now, either because the window is open or a ticket unlocked
  /// it — the same condition the submit endpoint enforces.
  bool get canSolve => available && (isOpen || timeTravelUnlocked);

  bool get isCompleted => completion?.status == 'completed';

  @override
  List<Object?> get props =>
      [available, isOpen, streak, set, questions, completion, availableTickets];
}

class DailyChallengeSet extends Equatable {
  const DailyChallengeSet({
    required this.id,
    required this.title,
    required this.date,
    required this.totalQuestions,
    this.availableFrom,
    this.availableUntil,
    this.status,
  });

  final String id;
  final String title;

  /// `YYYY-MM-DD`.
  final String date;
  final int totalQuestions;
  final String? availableFrom;
  final String? availableUntil;
  final String? status;

  @override
  List<Object?> get props => [id, title, date, totalQuestions, status];
}

class DailyChallengeCompletion extends Equatable {
  const DailyChallengeCompletion({
    required this.status,
    required this.totalQuestions,
    required this.pointsEarned,
    this.solvedQuestionIds = const [],
    this.attemptedQuestionIds = const [],
    this.completedAt,
  });

  /// `in_progress | completed`.
  final String status;
  final int totalQuestions;
  final int pointsEarned;
  final List<String> solvedQuestionIds;
  final List<String> attemptedQuestionIds;
  final String? completedAt;

  int get solvedCount => solvedQuestionIds.length;

  double get fraction =>
      totalQuestions == 0 ? 0 : (solvedCount / totalQuestions).clamp(0.0, 1.0);

  @override
  List<Object?> get props =>
      [status, totalQuestions, pointsEarned, solvedQuestionIds, attemptedQuestionIds];
}

/// The streak summary returned alongside today's challenge.
class DailyStreak extends Equatable {
  const DailyStreak({
    required this.currentStreak,
    required this.totalPoints,
    required this.challengesCompleted,
  });

  final int currentStreak;
  final int totalPoints;
  final int challengesCompleted;

  static const empty =
      DailyStreak(currentStreak: 0, totalPoints: 0, challengesCompleted: 0);

  @override
  List<Object?> get props => [currentStreak, totalPoints, challengesCompleted];
}

/// One day in `GET /student/practice/daily-challenge/calendar` or `/history`.
class DailyChallengeDay extends Equatable {
  const DailyChallengeDay({
    required this.date,
    required this.setId,
    required this.title,
    required this.totalQuestions,
    required this.status,
    required this.solvedCount,
    this.attemptedCount = 0,
  });

  final String date;
  final String setId;
  final String title;
  final int totalQuestions;

  /// `completed | in_progress | missed | upcoming`.
  final String status;
  final int solvedCount;
  final int attemptedCount;

  @override
  List<Object?> get props =>
      [date, setId, title, totalQuestions, status, solvedCount, attemptedCount];
}
