import 'package:equatable/equatable.dart';

/// One row of `GET /student/courses` — an enrollment wrapping its course.
class CourseEnrollment extends Equatable {
  const CourseEnrollment({
    required this.id,
    required this.status,
    required this.course,
    this.createdAt,
  });

  final String id;

  /// `active | archived | dropped`.
  final String status;
  final Course course;
  final String? createdAt;

  @override
  List<Object?> get props => [id, status, course, createdAt];
}

class Course extends Equatable {
  const Course({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.status,
    required this.credits,
    this.description,
    this.colorCode,
    this.batch,
    this.department,
    this.semester,
    this.division,
    this.instructor,
  });

  final String id;
  final String name;
  final String code;

  /// One of `COURSE_TYPES` — `regular`, `elective`, `laboratory`, `project`…
  final String type;

  /// `active | draft | completed | archived`.
  final String status;
  final int credits;
  final String? description;
  final String? colorCode;
  final CourseBatch? batch;
  final CourseDepartment? department;
  final CourseSemester? semester;

  /// The student's own division for this course, and who teaches that section.
  final CourseDivision? division;
  final CourseInstructor? instructor;

  /// `regular` → `Regular`, `open_elective` → `Open elective`.
  String get typeLabel {
    final spaced = type.replaceAll('_', ' ');
    return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        type,
        status,
        credits,
        description,
        colorCode,
        batch,
        department,
        semester,
        division,
        instructor,
      ];
}

class CourseBatch extends Equatable {
  const CourseBatch({
    required this.id,
    required this.name,
    this.code,
    this.startYear,
    this.endYear,
  });

  final String id;
  final String name;
  final String? code;
  final int? startYear;
  final int? endYear;

  @override
  List<Object?> get props => [id, name, code, startYear, endYear];
}

class CourseDepartment extends Equatable {
  const CourseDepartment({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;

  @override
  List<Object?> get props => [id, name, code];
}

class CourseSemester extends Equatable {
  const CourseSemester({
    required this.id,
    required this.code,
    this.startDate,
    this.endDate,
    this.status,
    this.isCurrent = false,
  });

  final String id;

  /// Semesters are numbered, not named — `code` is an int like `5`.
  final int code;
  final String? startDate;
  final String? endDate;
  final String? status;
  final bool isCurrent;

  String get label => 'Semester $code';

  @override
  List<Object?> get props => [id, code, startDate, endDate, status, isCurrent];
}

class CourseDivision extends Equatable {
  const CourseDivision({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;

  @override
  List<Object?> get props => [id, name, code];
}

class CourseInstructor extends Equatable {
  const CourseInstructor({
    required this.id,
    this.name,
    this.email,
    this.avatar,
  });

  final String id;
  final String? name;
  final String? email;
  final String? avatar;

  @override
  List<Object?> get props => [id, name, email, avatar];
}
