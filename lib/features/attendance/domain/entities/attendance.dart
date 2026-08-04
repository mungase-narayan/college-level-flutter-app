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

  @override
  List<Object?> get props => [id, status, type, sessionDate, courseId];
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
  static Color percentColor(int percentage) {
    if (percentage >= 75) return TwColors.emerald.s500;
    if (percentage >= 50) return TwColors.amber.s500;
    return TwColors.rose.s500;
  }

  /// The page size both attendance screens use.
  static const pageSize = 10;
}
