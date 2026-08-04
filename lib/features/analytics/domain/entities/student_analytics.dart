import 'package:equatable/equatable.dart';

/// `GET /student/analytics/overview` — all-time roll-ups plus the semester list
/// that drives the Analytics screen's only control.
class AnalyticsOverview extends Equatable {
  const AnalyticsOverview({
    required this.semesters,
    required this.notes,
    required this.questions,
    required this.dailyChallenge,
    this.currentSemesterId,
  });

  final List<AnalyticsSemester> semesters;
  final String? currentSemesterId;
  final NoteStats notes;
  final QuestionStats questions;
  final DailyChallengeStats dailyChallenge;

  /// The semester the screen should open on: the student's current one, else
  /// the first available.
  String? get defaultSemesterId =>
      currentSemesterId ?? (semesters.isEmpty ? null : semesters.first.id);

  @override
  List<Object?> get props =>
      [semesters, currentSemesterId, notes, questions, dailyChallenge];
}

class AnalyticsSemester extends Equatable {
  const AnalyticsSemester({
    required this.id,
    required this.code,
    this.isCurrent = false,
  });

  final String id;

  /// Semesters are numbered, not named.
  final int code;
  final bool isCurrent;

  String get label => isCurrent ? 'Semester $code (current)' : 'Semester $code';

  @override
  List<Object?> get props => [id, code, isCurrent];
}

class NoteStats extends Equatable {
  const NoteStats({
    required this.totalNotes,
    required this.publishedNotes,
    required this.totalViews,
    required this.totalLikes,
  });

  final int totalNotes;
  final int publishedNotes;
  final int totalViews;
  final int totalLikes;

  @override
  List<Object?> get props => [totalNotes, publishedNotes, totalViews, totalLikes];
}

class QuestionStats extends Equatable {
  const QuestionStats({
    required this.totalSolved,
    required this.totalAttempted,
    required this.correct,
    required this.totalPoints,
    required this.accuracy,
    required this.currentStreak,
    required this.maxStreak,
    this.difficulty = const [],
  });

  final int totalSolved;
  final int totalAttempted;
  final int correct;
  final int totalPoints;

  /// 0–100; the backend already substitutes 0 for "never attempted".
  final int accuracy;
  final int currentStreak;
  final int maxStreak;
  final List<DifficultyStat> difficulty;

  @override
  List<Object?> get props => [
        totalSolved,
        totalAttempted,
        correct,
        totalPoints,
        accuracy,
        currentStreak,
        maxStreak,
        difficulty,
      ];
}

class DifficultyStat extends Equatable {
  const DifficultyStat({
    required this.level,
    required this.solved,
    required this.attempted,
  });

  /// `easy | medium | hard` — always all three, in that order.
  final String level;
  final int solved;
  final int attempted;

  @override
  List<Object?> get props => [level, solved, attempted];
}

class DailyChallengeStats extends Equatable {
  const DailyChallengeStats({
    required this.totalAttempted,
    required this.completed,
    required this.totalPoints,
    required this.currentStreak,
    required this.maxStreak,
  });

  final int totalAttempted;
  final int completed;
  final int totalPoints;
  final int currentStreak;
  final int maxStreak;

  @override
  List<Object?> get props =>
      [totalAttempted, completed, totalPoints, currentStreak, maxStreak];
}

/// `GET /student/analytics/semester/:semesterId`.
class SemesterAnalytics extends Equatable {
  const SemesterAnalytics({
    required this.quiz,
    required this.assignment,
    required this.courses,
  });

  final CategoryStats quiz;
  final CategoryStats assignment;
  final CourseCompletion courses;

  @override
  List<Object?> get props => [quiz, assignment, courses];
}

/// Quiz or assignment totals for a semester, with a per-course breakdown.
class CategoryStats extends Equatable {
  const CategoryStats({
    required this.total,
    required this.attempted,
    required this.evaluated,
    required this.pending,
    required this.obtainedMarks,
    required this.maxMarks,
    required this.percentage,
    this.courses = const [],
  });

  final int total;
  final int attempted;
  final int evaluated;
  final int pending;
  final int obtainedMarks;
  final int maxMarks;

  /// 0–100, computed server-side from marks — never recompute it here.
  final int percentage;
  final List<CategoryCourseStats> courses;

  static const empty = CategoryStats(
    total: 0,
    attempted: 0,
    evaluated: 0,
    pending: 0,
    obtainedMarks: 0,
    maxMarks: 0,
    percentage: 0,
  );

  @override
  List<Object?> get props => [
        total,
        attempted,
        evaluated,
        pending,
        obtainedMarks,
        maxMarks,
        percentage,
        courses,
      ];
}

class CategoryCourseStats extends Equatable {
  const CategoryCourseStats({
    required this.courseId,
    required this.courseName,
    required this.percentage,
    required this.obtainedMarks,
    required this.maxMarks,
  });

  final String courseId;
  final String courseName;
  final int percentage;
  final int obtainedMarks;
  final int maxMarks;

  @override
  List<Object?> get props =>
      [courseId, courseName, percentage, obtainedMarks, maxMarks];
}

class CourseCompletion extends Equatable {
  const CourseCompletion({
    required this.overallPercent,
    required this.completedMaterials,
    required this.totalMaterials,
    this.list = const [],
  });

  final int overallPercent;
  final int completedMaterials;
  final int totalMaterials;
  final List<CourseCompletionRow> list;

  static const empty =
      CourseCompletion(overallPercent: 0, completedMaterials: 0, totalMaterials: 0);

  @override
  List<Object?> get props =>
      [overallPercent, completedMaterials, totalMaterials, list];
}

class CourseCompletionRow extends Equatable {
  const CourseCompletionRow({
    required this.courseId,
    required this.courseName,
    required this.completed,
    required this.total,
    required this.percent,
    this.courseCode,
  });

  final String courseId;
  final String courseName;
  final String? courseCode;
  final int completed;
  final int total;
  final int percent;

  @override
  List<Object?> get props =>
      [courseId, courseName, courseCode, completed, total, percent];
}
