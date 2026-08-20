import '../../../../../core/network/api_response.dart';
import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/attendance_session.dart';

class AttendanceSessionModel extends AttendanceSession {
  const AttendanceSessionModel({
    required super.id,
    required super.courseId,
    required super.divisionId,
    required super.type,
    required super.status,
    required super.sessionDate,
    super.topic,
    super.startTime,
    super.endTime,
    super.rosterSize,
    super.markedCount,
    super.presentCount,
    super.courseName,
    super.courseCode,
    super.divisionName,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionModel(
        id: asString(json['id']),
        courseId: asString(json['courseId']),
        divisionId: asString(json['divisionId']),
        type: asString(json['type']),
        status: asString(json['status']),
        sessionDate: asString(json['sessionDate']),
        topic: asStringOrNull(json['topic']),
        startTime: asStringOrNull(json['startTime']),
        endTime: asStringOrNull(json['endTime']),
        rosterSize: asInt(json['rosterSize']),
        markedCount: asInt(json['markedCount']),
        presentCount: asInt(json['presentCount']),
        courseName: asStringOrNull(json['courseName']),
        courseCode: asStringOrNull(json['courseCode']),
        divisionName: asStringOrNull(json['divisionName']),
      );
}

class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.studentId,
    required super.fullName,
    required super.isMarked,
    super.userId,
    super.email,
    super.avatar,
    super.rollNumber,
    super.status,
    super.remark,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel(
        studentId: asString(json['studentId']),
        fullName: asString(json['fullName']),
        isMarked: asBool(json['isMarked']),
        userId: asStringOrNull(json['userId']),
        email: asStringOrNull(json['email']),
        avatar: asStringOrNull(json['avatar']),
        rollNumber: asStringOrNull(json['rollNumber']),
        status: asStringOrNull(json['status']),
        remark: asStringOrNull(json['remark']),
      );
}

class AttendanceSessionDetailModel extends AttendanceSessionDetail {
  const AttendanceSessionDetailModel({
    required super.session,
    required super.records,
  });

  /// The detail payload is a session row with `records` folded in alongside its
  /// own columns, so the session is parsed from the same object.
  factory AttendanceSessionDetailModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionDetailModel(
        session: AttendanceSessionModel.fromJson(json),
        records: asObjectList(json['records'])
            .map(AttendanceRecordModel.fromJson)
            .toList(growable: false),
      );
}

class TodaySlotModel extends TodaySlot {
  const TodaySlotModel({
    required super.id,
    required super.title,
    required super.courseId,
    required super.divisionId,
    super.startTime,
    super.endTime,
    super.roomName,
    super.roomCode,
    super.sessionId,
    super.courseName,
    super.courseCode,
    super.divisionName,
  });

  factory TodaySlotModel.fromJson(Map<String, dynamic> json) => TodaySlotModel(
        id: asString(json['id']),
        title: asString(json['title']),
        courseId: asString(json['courseId']),
        divisionId: asString(json['divisionId']),
        startTime: asStringOrNull(json['startTime']),
        endTime: asStringOrNull(json['endTime']),
        roomName: asStringOrNull(json['roomName']),
        roomCode: asStringOrNull(json['roomCode']),
        sessionId: asStringOrNull(json['sessionId']),
        courseName: asStringOrNull(json['courseName']),
        courseCode: asStringOrNull(json['courseCode']),
        divisionName: asStringOrNull(json['divisionName']),
      );
}

class AttendanceAnalyticsModel extends AttendanceAnalytics {
  const AttendanceAnalyticsModel({
    required super.totalSessions,
    required super.present,
    required super.absent,
    required super.late,
    required super.leave,
  });

  factory AttendanceAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final counts = (json['statusCounts'] as Map<String, dynamic>?) ?? const {};
    return AttendanceAnalyticsModel(
      totalSessions: asInt(json['totalSessions']),
      present: asInt(counts['present']),
      absent: asInt(counts['absent']),
      late: asInt(counts['late']),
      leave: asInt(counts['leave']),
    );
  }
}

class AttendanceSessionPageModel extends AttendanceSessionPage {
  const AttendanceSessionPageModel({
    required super.items,
    required super.pagination,
  });

  factory AttendanceSessionPageModel.fromJson(Object? data) {
    final page = Paginated<AttendanceSession>.fromJson(
      data,
      AttendanceSessionModel.fromJson,
    );
    return AttendanceSessionPageModel(
      items: page.items,
      pagination: page.pagination,
    );
  }
}
