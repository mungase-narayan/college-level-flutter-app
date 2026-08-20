import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/network/api_response.dart';

/// One attendance session, as it appears in the teacher's list.
///
/// `sessionDate` is a bare `YYYY-MM-DD`; `startTime`/`endTime` are full ISO
/// timestamps. They are deliberately different shapes on the wire — see
/// [TodaySlot], whose times are clock strings with no date at all.
class AttendanceSession extends Equatable {
  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.divisionId,
    required this.type,
    required this.status,
    required this.sessionDate,
    this.topic,
    this.startTime,
    this.endTime,
    this.rosterSize = 0,
    this.markedCount = 0,
    this.presentCount = 0,
    this.courseName,
    this.courseCode,
    this.divisionName,
  });

  final String id;
  final String courseId;
  final String divisionId;

  /// `lecture | lab | tutorial`.
  final String type;

  /// `draft | finalized`.
  final String status;
  final String sessionDate;
  final String? topic;
  final String? startTime;
  final String? endTime;

  final int rosterSize;
  final int markedCount;

  /// Carried by the API but not shown — the row reports marked-of-roster, which
  /// is what tells a teacher whether there is work left to do.
  final int presentCount;

  final String? courseName;
  final String? courseCode;
  final String? divisionName;

  bool get isDraft => status == AttendanceStatus.draft;

  /// Only a draft can be edited or deleted; the server answers 409
  /// `ATTENDANCE_SESSION_NOT_EDITABLE` otherwise.
  bool get isEditable => isDraft;

  /// What the row headlines with when the teacher left the topic blank.
  String get title =>
      (topic ?? '').trim().isNotEmpty ? topic!.trim() : AttendanceType.label(type);

  @override
  List<Object?> get props => [
        id,
        courseId,
        divisionId,
        type,
        status,
        sessionDate,
        topic,
        startTime,
        endTime,
        rosterSize,
        markedCount,
        presentCount,
      ];
}

/// A session plus its full roster — what the marking screen loads.
class AttendanceSessionDetail extends Equatable {
  const AttendanceSessionDetail({required this.session, required this.records});

  final AttendanceSession session;
  final List<AttendanceRecord> records;

  @override
  List<Object?> get props => [session, records];
}

/// One student on the roster.
class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.studentId,
    required this.fullName,
    required this.isMarked,
    this.userId,
    this.email,
    this.avatar,
    this.rollNumber,
    this.status,
    this.remark,
  });

  final String studentId;
  final String fullName;

  /// Whether a mark has been saved for this student. Distinct from [status]
  /// being null only in that the server sets both together.
  final bool isMarked;
  final String? userId;
  final String? email;
  final String? avatar;
  final String? rollNumber;

  /// `present | absent | late | leave`, or null when never marked.
  final String? status;

  /// Persisted by the API and shown nowhere — the web has no remark input
  /// either, so this is carried rather than surfaced.
  final String? remark;

  /// `CS21-014 · ravi@x.edu`, dropping whichever is missing.
  String? get subtitle {
    final parts = [
      if ((rollNumber ?? '').isNotEmpty) rollNumber!,
      if ((email ?? '').isNotEmpty) email!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props =>
      [studentId, fullName, isMarked, rollNumber, status, remark];
}

/// A timetable slot for today, and whether a session already exists for it.
class TodaySlot extends Equatable {
  const TodaySlot({
    required this.id,
    required this.title,
    required this.courseId,
    required this.divisionId,
    this.startTime,
    this.endTime,
    this.roomName,
    this.roomCode,
    this.sessionId,
    this.courseName,
    this.courseCode,
    this.divisionName,
  });

  final String id;
  final String title;
  final String courseId;
  final String divisionId;

  /// `"HH:MM:SS"` clock strings — no date, unlike a session's ISO timestamps.
  final String? startTime;
  final String? endTime;
  final String? roomName;
  final String? roomCode;

  /// Non-null once a session has been created from this slot today. Only slots
  /// without one are offered as pending.
  final String? sessionId;
  final String? courseName;
  final String? courseCode;
  final String? divisionName;

  bool get isPending => sessionId == null;

  @override
  List<Object?> get props => [id, title, courseId, divisionId, sessionId];
}

/// The course + division attendance rollup behind the analytics strip.
class AttendanceAnalytics extends Equatable {
  const AttendanceAnalytics({
    required this.totalSessions,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
  });

  final int totalSessions;
  final int present;
  final int absent;
  final int late;
  final int leave;

  int get marked => present + absent + late + leave;

  /// Share of marks that were present, as a whole percent. Null when nothing
  /// has been marked — distinct from 0%, which would read as everyone absent.
  int? get presentPercent =>
      marked == 0 ? null : ((present / marked) * 100).round();

  @override
  List<Object?> get props => [totalSessions, present, absent, late, leave];
}

/// A page of sessions plus its pagination envelope.
class AttendanceSessionPage extends Equatable {
  const AttendanceSessionPage({required this.items, required this.pagination});

  final List<AttendanceSession> items;
  final Pagination pagination;

  @override
  List<Object?> get props => [items, pagination];
}

/// `session.type` — the wire values and how each reads.
class AttendanceType {
  const AttendanceType._();

  static const lecture = 'lecture';
  static const lab = 'lab';
  static const tutorial = 'tutorial';

  static const options = [lecture, lab, tutorial];

  static String label(String value) => switch (value) {
        lecture => 'Lecture',
        lab => 'Lab',
        tutorial => 'Tutorial',
        _ => value,
      };
}

/// `session.status`.
class AttendanceStatus {
  const AttendanceStatus._();

  static const draft = 'draft';
  static const finalized = 'finalized';

  static const options = [draft, finalized];

  static String label(String value) => switch (value) {
        draft => 'Draft',
        finalized => 'Finalized',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        draft => TwColors.amber,
        finalized => TwColors.emerald,
        _ => TwColors.slate,
      };
}

/// `records[].status` — the four marks, and the colours the web gives them.
class MarkStatus {
  const MarkStatus._();

  static const present = 'present';
  static const absent = 'absent';
  static const late = 'late';
  static const leave = 'leave';

  /// Order matters: this is the left-to-right order of the segmented control.
  static const options = [present, absent, late, leave];

  static String label(String value) => switch (value) {
        present => 'Present',
        absent => 'Absent',
        late => 'Late',
        leave => 'Leave',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        present => TwColors.emerald,
        absent => TwColors.rose,
        late => TwColors.amber,
        leave => TwColors.cyan,
        _ => TwColors.slate,
      };
}
