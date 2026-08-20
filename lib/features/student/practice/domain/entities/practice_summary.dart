import 'package:equatable/equatable.dart';

import '../../../../../core/common/widgets/heatmap_grid.dart';

/// `GET /student/practice/summary` — the roll-up behind the dashboard tiles.
class PracticeSummary extends Equatable {
  const PracticeSummary({
    required this.totalQuestionsAvailable,
    required this.questionsAttempted,
    required this.questionsSolved,
    required this.correctAnswers,
    required this.pendingReviews,
    required this.totalPoints,
    required this.practiceSeconds,
    this.overallAccuracy,
  });

  final int totalQuestionsAvailable;
  final int questionsAttempted;
  final int questionsSolved;
  final int correctAnswers;
  final int pendingReviews;
  final int totalPoints;
  final int practiceSeconds;

  /// 0–100, or null when the student has never attempted anything.
  final int? overallAccuracy;

  @override
  List<Object?> get props => [
        totalQuestionsAvailable,
        questionsAttempted,
        questionsSolved,
        correctAnswers,
        pendingReviews,
        totalPoints,
        practiceSeconds,
        overallAccuracy,
      ];
}

/// `GET /student/practice/analytics` — the full analytics payload. The
/// dashboard uses the heatmap and overview; the analytics screen uses the rest.
class PracticeAnalytics extends Equatable {
  const PracticeAnalytics({
    required this.overview,
    required this.heatmap,
    this.difficulty = const [],
    this.subjects = const [],
    this.daily = const [],
    this.monthly = const [],
    this.timeStats,
  });

  final PracticeSummary overview;
  final ActivityHeatmap heatmap;

  /// Solved/attempted split per difficulty and per subject.
  final List<PracticeBreakdown> difficulty;
  final List<PracticeBreakdown> subjects;

  /// The last 14 days, oldest first. The charts show the trailing 7.
  final List<PracticeDailyPoint> daily;

  /// The last 6 months, oldest first.
  final List<PracticeMonthlyPoint> monthly;
  final PracticeTimeStats? timeStats;

  /// The trailing 7 days the React charts plot.
  List<PracticeDailyPoint> get lastWeek =>
      daily.length <= 7 ? daily : daily.sublist(daily.length - 7);

  @override
  List<Object?> get props =>
      [overview, heatmap, difficulty, subjects, daily, monthly, timeStats];
}

/// One day of the practice series.
class PracticeDailyPoint extends Equatable {
  const PracticeDailyPoint({
    required this.date,
    required this.attempts,
    required this.correct,
    required this.points,
    this.accuracy,
  });

  /// `YYYY-MM-DD`.
  final String date;
  final int attempts;
  final int correct;
  final int points;

  /// 0–100, or null on a day with no attempts.
  final int? accuracy;

  /// The chart axis labels days by number only, as the React tick formatter
  /// does (`iso.slice(8, 10)`).
  String get dayLabel => date.length >= 10 ? date.substring(8, 10) : date;

  @override
  List<Object?> get props => [date, attempts, correct, points, accuracy];
}

/// One month of solved questions.
class PracticeMonthlyPoint extends Equatable {
  const PracticeMonthlyPoint({required this.month, required this.solved});

  /// `YYYY-MM`.
  final String month;
  final int solved;

  /// `2026-07` → `Jul`.
  String get label {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final index = int.tryParse(parts[1]);
    if (index == null || index < 1 || index > 12) return month;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[index - 1];
  }

  @override
  List<Object?> get props => [month, solved];
}

/// The contribution grid: 371 cells running Sunday→Saturday, with cells after
/// `today` present as zero-count placeholders.
class ActivityHeatmap extends Equatable {
  const ActivityHeatmap({required this.today, required this.days});

  final String today;
  final List<HeatmapDay> days;

  /// Consecutive days ending today (or yesterday, if today is still blank —
  /// the GitHub convention the backend also uses).
  int get currentStreak {
    final active = {for (final day in days) if (day.count > 0) day.date};
    if (active.isEmpty) return 0;

    var cursor = DateTime.tryParse(today);
    if (cursor == null) return 0;

    // Today may legitimately still be empty, so don't break the streak on it.
    final todayKey = _key(cursor);
    if (!active.contains(todayKey)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (active.contains(_key(cursor!))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [today, days.map((d) => '${d.date}:${d.count}').toList()];
}

/// One row of the difficulty or subject breakdown.
class PracticeBreakdown extends Equatable {
  const PracticeBreakdown({
    required this.label,
    required this.attempts,
    required this.solved,
    this.accuracy,
  });

  final String label;
  final int attempts;
  final int solved;
  final int? accuracy;

  @override
  List<Object?> get props => [label, attempts, solved, accuracy];
}

class PracticeTimeStats extends Equatable {
  const PracticeTimeStats({
    required this.totalSeconds,
    this.avgSecondsPerQuestion,
    this.fastestSolveSec,
    this.slowestSolveSec,
  });

  final int totalSeconds;
  final int? avgSecondsPerQuestion;
  final int? fastestSolveSec;
  final int? slowestSolveSec;

  @override
  List<Object?> get props =>
      [totalSeconds, avgSecondsPerQuestion, fastestSolveSec, slowestSolveSec];
}
