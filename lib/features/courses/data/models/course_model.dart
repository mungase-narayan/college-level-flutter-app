import '../../domain/entities/course.dart';

/// Shared JSON helpers for the course models.
int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// JSON → [CourseEnrollment], the row shape of `GET /student/courses`.
class CourseEnrollmentModel extends CourseEnrollment {
  const CourseEnrollmentModel({
    required super.id,
    required super.status,
    required super.course,
    super.createdAt,
  });

  factory CourseEnrollmentModel.fromJson(Map<String, dynamic> json) =>
      CourseEnrollmentModel(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        createdAt: json['createdAt'] as String?,
        course: CourseModel.fromJson(_map(json['course'])),
      );
}

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.name,
    required super.code,
    required super.type,
    required super.status,
    required super.credits,
    super.description,
    super.colorCode,
    super.batch,
    super.department,
    super.semester,
    super.division,
    super.instructor,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        type: json['type'] as String? ?? 'regular',
        status: json['status'] as String? ?? 'active',
        credits: _int(json['credits']),
        description: json['description'] as String?,
        colorCode: json['colorCode'] as String?,
        batch: json['batch'] == null ? null : _batch(_map(json['batch'])),
        department:
            json['department'] == null ? null : _department(_map(json['department'])),
        semester: json['semester'] == null ? null : _semester(_map(json['semester'])),
        // `division` and `instructor` are explicitly null when the student has
        // no division mapping for the course.
        division: json['division'] == null ? null : _division(_map(json['division'])),
        instructor:
            json['instructor'] == null ? null : _instructor(_map(json['instructor'])),
      );

  static CourseBatch _batch(Map<String, dynamic> json) => CourseBatch(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        startYear: (json['startYear'] as num?)?.toInt(),
        endYear: (json['endYear'] as num?)?.toInt(),
      );

  static CourseDepartment _department(Map<String, dynamic> json) => CourseDepartment(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
      );

  static CourseSemester _semester(Map<String, dynamic> json) => CourseSemester(
        id: json['id'] as String? ?? '',
        code: _int(json['code']),
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        status: json['status'] as String?,
        isCurrent: json['isCurrent'] as bool? ?? false,
      );

  static CourseDivision _division(Map<String, dynamic> json) => CourseDivision(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
      );

  static CourseInstructor _instructor(Map<String, dynamic> json) => CourseInstructor(
        id: json['id'] as String? ?? '',
        // The join exposes the teacher's user record, whose name may arrive
        // either pre-composed or split.
        name: json['fullName'] as String? ??
            json['name'] as String? ??
            [json['firstName'], json['lastName']]
                .whereType<String>()
                .where((part) => part.isNotEmpty)
                .join(' '),
        email: json['email'] as String?,
        avatar: json['avatar'] as String?,
      );
}
