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
