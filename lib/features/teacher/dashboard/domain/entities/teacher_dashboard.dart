import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// `GET /teacher/dashboard` — everything the teacher dashboard renders,
/// aggregated server-side into one payload.
class TeacherDashboard extends Equatable {
  const TeacherDashboard({
    required this.stats,
    required this.todaySessions,
    required this.myCourses,
  });

  final TeacherDashboardStats stats;
  final List<TeacherTodaySession> todaySessions;
  final List<TeacherCourseSummary> myCourses;

  /// Whether any of today's sessions could still change state on their own.
  ///
  /// Drives the dashboard's periodic refresh: once every session is `completed`
  /// nothing more will happen today, so the poll stops.
  bool get hasPendingSessions =>
      todaySessions.any((s) => s.status != TeacherSessionStatus.completed);

  @override
  List<Object?> get props => [stats, todaySessions, myCourses];
}

class TeacherDashboardStats extends Equatable {
  const TeacherDashboardStats({
    required this.coursesCount,
    required this.studentsCount,
    required this.topicsCount,
  });

  /// Distinct courses, **not** course-division assignments — so this is at most
  /// [TeacherDashboard.myCourses]`.length`, and usually less.
  final int coursesCount;
  final int studentsCount;
  final int topicsCount;

  @override
  List<Object?> get props => [coursesCount, studentsCount, topicsCount];
}

/// One row of today's timetable.
///
/// [time] arrives **pre-formatted** ("9:00 AM") and there are no start/end
/// timestamps in the payload, so the client cannot recompute [status] — the
/// server does it in the school's own timezone. Staleness is handled by
/// refetching, not by a local clock.
class TeacherTodaySession extends Equatable {
  const TeacherTodaySession({
    required this.id,
    required this.time,
    required this.title,
    required this.division,
    required this.room,
    required this.students,
    required this.status,
  });

  final String id;
  final String time;
  final String title;

  /// The server substitutes an em dash for a missing division or room. Read
  /// these through [divisionOrNull] / [roomOrNull] so the UI can drop the chip
  /// instead of rendering a stray dash.
  final String division;
  final String room;
  final int students;
  final String status;

  String? get divisionOrNull => _presentOrNull(division);
  String? get roomOrNull => _presentOrNull(room);

  bool get isCompleted => status == TeacherSessionStatus.completed;
  bool get isLive => status == TeacherSessionStatus.live;

  @override
  List<Object?> get props =>
      [id, time, title, division, room, students, status];
}

/// One (course, division) assignment.
///
/// The same course appears once **per division** the teacher takes it for, so
/// `courseId` alone is not a unique key — see [key].
class TeacherCourseSummary extends Equatable {
  const TeacherCourseSummary({
    required this.courseId,
    required this.name,
    required this.code,
    required this.division,
    required this.students,
    required this.totalTopics,
    this.colorCode,
  });

  final String courseId;
  final String name;
  final String code;
  final String division;
  final int students;

  /// Division-scoped: topics shared school-wide plus this section's own.
  final int totalTopics;
  final String? colorCode;

  /// Unique per row. `courseId` repeats across divisions.
  String get key => '$courseId-$division';

  String? get divisionOrNull => _presentOrNull(division);

  @override
  List<Object?> get props =>
      [courseId, name, code, division, students, totalTopics, colorCode];
}

/// `todaySessions[].status` — the wire values and how each one reads.
class TeacherSessionStatus {
  const TeacherSessionStatus._();

  static const upcoming = 'upcoming';
  static const live = 'live';
  static const completed = 'completed';

  static String label(String status) => switch (status) {
        live => 'Live Now',
        upcoming => 'Upcoming',
        completed => 'Completed',
        _ => status,
      };

  static TwShade shade(String status) => switch (status) {
        live => TwColors.emerald,
        upcoming => TwColors.amber,
        completed => TwColors.slate,
        _ => TwColors.slate,
      };
}

/// The backend writes an em dash where a division or room is null, so an empty
/// string is not the only "absent" it sends.
String? _presentOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '—' || trimmed == '-') return null;
  return trimmed;
}
