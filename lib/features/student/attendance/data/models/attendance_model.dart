import '../../domain/entities/attendance.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// JSON → [CourseAttendance].
class CourseAttendanceModel extends CourseAttendance {
  const CourseAttendanceModel({
    required super.totalSessions,
    required super.percentage,
    required super.counts,
  });

  factory CourseAttendanceModel.fromJson(Map<String, dynamic> json) {
    // The per-course endpoint nests the tallies under `statusCounts`; the
    // school-wide one puts them at the top level. Accept either.
    final counts = json['statusCounts'] is Map<String, dynamic>
        ? _map(json['statusCounts'])
        : json;

    return CourseAttendanceModel(
      totalSessions: _int(json['totalSessions']),
      percentage: _int(json['percentage']),
      counts: AttendanceCounts(
        present: _int(counts['present']),
        absent: _int(counts['absent']),
        late: _int(counts['late']),
        leave: _int(counts['leave']),
      ),
    );
  }
}

/// JSON → [AttendanceOverview].
class AttendanceOverviewModel extends AttendanceOverview {
  const AttendanceOverviewModel({
    required super.overall,
    required super.courses,
  });

  factory AttendanceOverviewModel.fromJson(Map<String, dynamic> json) =>
      AttendanceOverviewModel(
        // `overall` puts its tallies at the top level, which
        // [CourseAttendanceModel.fromJson] already accepts.
        overall: CourseAttendanceModel.fromJson(_map(json['overall'])),
        courses: ((json['courses'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CourseAttendanceSummaryModel.fromJson)
            .toList(growable: false),
      );
}

/// JSON → [CourseAttendanceSummary].
class CourseAttendanceSummaryModel extends CourseAttendanceSummary {
  const CourseAttendanceSummaryModel({
    required super.courseId,
    required super.courseName,
    required super.courseCode,
    required super.divisionId,
    required super.totalSessions,
    required super.percentage,
    required super.counts,
  });

  factory CourseAttendanceSummaryModel.fromJson(Map<String, dynamic> json) =>
      CourseAttendanceSummaryModel(
        courseId: json['courseId'] as String? ?? '',
        courseName: json['courseName'] as String? ?? '',
        courseCode: json['courseCode'] as String? ?? '',
        // Legitimately empty when no division is resolved for the semester.
        divisionId: json['divisionId'] as String? ?? '',
        totalSessions: _int(json['totalSessions']),
        percentage: _int(json['percentage']),
        counts: AttendanceCounts(
          present: _int(json['present']),
          absent: _int(json['absent']),
          late: _int(json['late']),
          leave: _int(json['leave']),
        ),
      );
}

/// JSON → [AttendanceSession].
class AttendanceSessionModel extends AttendanceSession {
  const AttendanceSessionModel({
    required super.id,
    required super.status,
    required super.type,
    required super.sessionDate,
    super.sessionId,
    super.topic,
    super.remark,
    super.startTime,
    super.endTime,
    super.courseId,
    super.courseName,
    super.courseCode,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionModel(
        id: json['id'] as String? ?? json['sessionId'] as String? ?? '',
        sessionId: json['sessionId'] as String?,
        status: json['status'] as String? ?? 'absent',
        type: json['type'] as String? ?? 'lecture',
        sessionDate: json['sessionDate'] as String? ?? '',
        topic: json['topic'] as String?,
        remark: json['remark'] as String?,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        courseId: json['courseId'] as String?,
        courseName: json['courseName'] as String?,
        courseCode: json['courseCode'] as String?,
      );
}
