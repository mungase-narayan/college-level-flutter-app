import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';

/// `GET /student/attendance/courses/:courseId/analytics`.
class CourseAttendance extends Equatable {
  const CourseAttendance({
    required this.totalSessions,
    required this.percentage,
    required this.counts,
  });

  final int totalSessions;

  /// Computed server-side — never recompute it on the client.
  final int percentage;
  final AttendanceCounts counts;

  static const empty = CourseAttendance(
    totalSessions: 0,
    percentage: 0,
    counts: AttendanceCounts.empty,
  );

  @override
  List<Object?> get props => [totalSessions, percentage, counts];
}

class AttendanceCounts extends Equatable {
  const AttendanceCounts({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
  });

  final int present;
  final int absent;
  final int late;
  final int leave;

  static const empty =
      AttendanceCounts(present: 0, absent: 0, late: 0, leave: 0);

  /// The React stat card groups these two into one tile.
  int get lateAndLeave => late + leave;

  @override
  List<Object?> get props => [present, absent, late, leave];
}

/// `GET /student/attendance/analytics/overall`.
///
/// [overall] sums **every** enrolled course, but [courses] is truncated by the
/// server — see [courseListCap]. The two therefore disagree for a student with
/// more than ten courses, and that is the server's behaviour, not a parsing bug.
class AttendanceOverview extends Equatable {
  const AttendanceOverview({required this.overall, required this.courses});

  final CourseAttendance overall;
  final List<CourseAttendanceSummary> courses;

  static const empty = AttendanceOverview(
    overall: CourseAttendance.empty,
    courses: [],
  );

  /// Mirrors `OVERALL_COURSES_LIMIT` in the backend's student attendance
  /// service. There is no query parameter to raise or page past it.
  static const courseListCap = 10;

  /// Whether the course list may have been cut short.
  ///
  /// A full list is indistinguishable from a truncated one — the server sends no
  /// total — so this is true for a student with exactly ten courses as well. Any
  /// copy driven by it has to read correctly in both cases.
  bool get isCourseListCapped => courses.length >= courseListCap;

  @override
  List<Object?> get props => [overall, courses];
}

/// One entry of [AttendanceOverview.courses].
class CourseAttendanceSummary extends Equatable {
  const CourseAttendanceSummary({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.divisionId,
    required this.totalSessions,
    required this.percentage,
    required this.counts,
  });

  final String courseId;
  final String courseName;
  final String courseCode;

  /// Empty when the student has no division resolved for the course's semester,
  /// which is also when [totalSessions] comes back as zero.
  final String divisionId;

  final int totalSessions;

  /// Computed server-side — never recompute it on the client.
  final int percentage;
  final AttendanceCounts counts;

  /// The React list key: a course can appear once per division.
  String get key => '$courseId:$divisionId';

  /// False when the course has not met yet. The server still reports 0%, which
  /// would otherwise paint an unheld course as a failing one.
  bool get hasSessions => totalSessions > 0;

  @override
  List<Object?> get props => [
        courseId,
        courseName,
        courseCode,
        divisionId,
        totalSessions,
        percentage,
        counts,
      ];
}

/// One row of `GET /student/attendance/sessions`.
class AttendanceSession extends Equatable {
  const AttendanceSession({
    required this.id,
    required this.status,
    required this.type,
    required this.sessionDate,
    this.sessionId,
    this.topic,
    this.remark,
    this.startTime,
    this.endTime,
    this.courseId,
    this.courseName,
    this.courseCode,
  });

  final String id;

  /// `present | absent | late | leave`.
  final String status;

  /// `lecture | lab | tutorial`.
  final String type;

  /// `YYYY-MM-DD`.
  final String sessionDate;
  final String? sessionId;
  final String? topic;
  final String? remark;
  final String? startTime;
  final String? endTime;
  final String? courseId;
  final String? courseName;
  final String? courseCode;

  // `topic` and `courseCode` are in here because the row renders them: a cubit
  // drops an emission equal to the current state, so a teacher correcting a
  // session's topic would otherwise leave the stale text on screen.
  @override
  List<Object?> get props =>
      [id, status, type, sessionDate, courseId, courseCode, topic];
}

/// Labels, tints, and the percentage colour rule.
class AttendanceMeta {
  const AttendanceMeta._();

  static const statuses = ['present', 'absent', 'late', 'leave'];

  static String statusLabel(String status) => switch (status) {
        'present' => 'Present',
        'absent' => 'Absent',
        'late' => 'Late',
        'leave' => 'Leave',
        _ => status,
      };

  static TwShade statusShade(String status) => switch (status) {
        'present' => TwColors.emerald,
        'absent' => TwColors.rose,
        'late' => TwColors.amber,
        'leave' => TwColors.cyan,
        _ => TwColors.slate,
      };

  static String typeLabel(String type) => switch (type) {
        'lecture' => 'Lecture',
        'lab' => 'Lab',
        'tutorial' => 'Tutorial',
        _ => type,
      };

  /// The React rule: **≥75 emerald, ≥50 amber, else rose**.
  static TwShade percentShade(int percentage) {
    if (percentage >= 75) return TwColors.emerald;
    if (percentage >= 50) return TwColors.amber;
    return TwColors.rose;
  }

  /// The bar fill, matching the web's `bg-emerald-500`.
  ///
  /// Percentage *text* should go through [percentShade] and the theme's tone
  /// instead, so it tracks light and dark the way `text-emerald-600
  /// dark:text-emerald-400` does.
  static Color percentColor(int percentage) => percentShade(percentage).s500;

  /// The page size both attendance screens use.
  static const pageSize = 10;
}
