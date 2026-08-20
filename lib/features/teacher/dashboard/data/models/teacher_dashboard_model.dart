import '../../domain/entities/teacher_dashboard.dart';

class TeacherDashboardModel extends TeacherDashboard {
  const TeacherDashboardModel({
    required super.stats,
    required super.todaySessions,
    required super.myCourses,
  });

  factory TeacherDashboardModel.fromJson(Map<String, dynamic> json) =>
      TeacherDashboardModel(
        stats: TeacherDashboardStatsModel.fromJson(
          (json['stats'] as Map<String, dynamic>?) ?? const {},
        ),
        todaySessions: _list(json['todaySessions'])
            .map(TeacherTodaySessionModel.fromJson)
            .toList(growable: false),
        myCourses: _list(json['myCourses'])
            .map(TeacherCourseSummaryModel.fromJson)
            .toList(growable: false),
      );
}

class TeacherDashboardStatsModel extends TeacherDashboardStats {
  const TeacherDashboardStatsModel({
    required super.coursesCount,
    required super.studentsCount,
    required super.topicsCount,
  });

  factory TeacherDashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      TeacherDashboardStatsModel(
        coursesCount: _int(json['coursesCount']),
        studentsCount: _int(json['studentsCount']),
        topicsCount: _int(json['topicsCount']),
      );
}

class TeacherTodaySessionModel extends TeacherTodaySession {
  const TeacherTodaySessionModel({
    required super.id,
    required super.time,
    required super.title,
    required super.division,
    required super.room,
    required super.students,
    required super.status,
  });

  factory TeacherTodaySessionModel.fromJson(Map<String, dynamic> json) =>
      TeacherTodaySessionModel(
        id: json['id'] as String? ?? '',
        // Already formatted for display by the server ("9:00 AM").
        time: json['time'] as String? ?? '',
        title: json['title'] as String? ?? '',
        division: json['division'] as String? ?? '',
        room: json['room'] as String? ?? '',
        students: _int(json['students']),
        status: json['status'] as String? ?? TeacherSessionStatus.upcoming,
      );
}

class TeacherCourseSummaryModel extends TeacherCourseSummary {
  const TeacherCourseSummaryModel({
    required super.courseId,
    required super.name,
    required super.code,
    required super.division,
    required super.students,
    required super.totalTopics,
    super.colorCode,
  });

  factory TeacherCourseSummaryModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseSummaryModel(
        courseId: json['courseId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        division: json['division'] as String? ?? '',
        students: _int(json['students']),
        totalTopics: _int(json['totalTopics']),
        colorCode: json['colorCode'] as String?,
      );
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

List<Map<String, dynamic>> _list(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];
