import '../../domain/entities/student_analytics.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

/// JSON → [AnalyticsOverview].
class AnalyticsOverviewModel extends AnalyticsOverview {
  const AnalyticsOverviewModel({
    required super.semesters,
    required super.notes,
    required super.questions,
    required super.dailyChallenge,
    super.currentSemesterId,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverviewModel(
        currentSemesterId: json['currentSemesterId'] as String?,
        semesters: _maps(json['semesters'])
            .map(
              (row) => AnalyticsSemester(
                id: row['id'] as String? ?? '',
                code: _int(row['code']),
                isCurrent: row['isCurrent'] as bool? ?? false,
              ),
            )
            .toList(growable: false),
        notes: _notes(_map(json['notes'])),
        questions: _questions(_map(json['questions'])),
        dailyChallenge: _daily(_map(json['dailyChallenge'])),
      );

  static NoteStats _notes(Map<String, dynamic> json) => NoteStats(
        totalNotes: _int(json['totalNotes']),
        publishedNotes: _int(json['publishedNotes']),
        totalViews: _int(json['totalViews']),
        totalLikes: _int(json['totalLikes']),
      );

  static QuestionStats _questions(Map<String, dynamic> json) => QuestionStats(
        totalSolved: _int(json['totalSolved']),
        totalAttempted: _int(json['totalAttempted']),
        correct: _int(json['correct']),
        totalPoints: _int(json['totalPoints']),
        accuracy: _int(json['accuracy']),
        currentStreak: _int(json['currentStreak']),
        maxStreak: _int(json['maxStreak']),
        difficulty: _maps(json['difficulty'])
            .map(
              (row) => DifficultyStat(
                level: row['level'] as String? ?? '',
                solved: _int(row['solved']),
                attempted: _int(row['attempted']),
              ),
            )
            .toList(growable: false),
      );

  static DailyChallengeStats _daily(Map<String, dynamic> json) => DailyChallengeStats(
        totalAttempted: _int(json['totalAttempted']),
        completed: _int(json['completed']),
        totalPoints: _int(json['totalPoints']),
        currentStreak: _int(json['currentStreak']),
        maxStreak: _int(json['maxStreak']),
      );
}

/// JSON → [SemesterAnalytics].
///
/// The endpoint answers `{ "error": "not_found" }` when the semester isn't in
/// the student's batch/department, which [isNotFound] detects so the screen can
/// show an empty state instead of an error.
class SemesterAnalyticsModel extends SemesterAnalytics {
  const SemesterAnalyticsModel({
    required super.quiz,
    required super.assignment,
    required super.courses,
  });

  static bool isNotFound(Object? data) =>
      data is Map<String, dynamic> && data['error'] == 'not_found';

  factory SemesterAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      SemesterAnalyticsModel(
        quiz: _category(_map(json['quiz'])),
        assignment: _category(_map(json['assignment'])),
        courses: _courses(_map(json['courses'])),
      );

  static CategoryStats _category(Map<String, dynamic> json) {
    if (json.isEmpty) return CategoryStats.empty;
    return CategoryStats(
      total: _int(json['total']),
      attempted: _int(json['attempted']),
      evaluated: _int(json['evaluated']),
      pending: _int(json['pending']),
      obtainedMarks: _int(json['obtainedMarks']),
      maxMarks: _int(json['maxMarks']),
      percentage: _int(json['percentage']),
      courses: _maps(json['courses'])
          .map(
            (row) => CategoryCourseStats(
              courseId: row['courseId'] as String? ?? '',
              courseName: row['courseName'] as String? ?? '',
              percentage: _int(row['percentage']),
              obtainedMarks: _int(row['obtainedMarks']),
              maxMarks: _int(row['maxMarks']),
            ),
          )
          .toList(growable: false),
    );
  }

  static CourseCompletion _courses(Map<String, dynamic> json) {
    if (json.isEmpty) return CourseCompletion.empty;
    return CourseCompletion(
      overallPercent: _int(json['overallPercent']),
      completedMaterials: _int(json['completedMaterials']),
      totalMaterials: _int(json['totalMaterials']),
      list: _maps(json['list'])
          .map(
            (row) => CourseCompletionRow(
              courseId: row['courseId'] as String? ?? '',
              courseName: row['courseName'] as String? ?? '',
              courseCode: row['courseCode'] as String?,
              completed: _int(row['completed']),
              total: _int(row['total']),
              percent: _int(row['percent']),
            ),
          )
          .toList(growable: false),
    );
  }
}
