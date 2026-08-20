import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// One row of `GET /teacher/courses` — a single **(course, division)**
/// instructor assignment.
///
/// A teacher taking three sections of one course gets three of these. The list
/// screen folds them into one [TeacherCourseGroup] per course, which is what the
/// web does too.
class TeacherAssignedCourse extends Equatable {
  const TeacherAssignedCourse({
    required this.id,
    required this.status,
    required this.divisionId,
    required this.course,
  });

  /// The `courseInstructors` row id, not the course id.
  final String id;

  /// `active | archived | dropped`.
  final String status;
  final String divisionId;
  final TeacherCourseInfo course;

  @override
  List<Object?> get props => [id, status, divisionId, course];
}

class TeacherCourseInfo extends Equatable {
  const TeacherCourseInfo({
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
  });

  final String id;
  final String name;
  final String code;
  final String type;
  final String status;
  final int credits;
  final String? description;
  final String? colorCode;
  final TeacherCourseBatch? batch;
  final TeacherCourseDepartment? department;
  final TeacherCourseSemester? semester;
  final CourseDivision? division;

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
      ];
}

class TeacherCourseBatch extends Equatable {
  const TeacherCourseBatch({
    required this.id,
    required this.name,
    required this.code,
    this.startYear,
    this.endYear,
  });

  final String id;
  final String name;
  final String code;
  final int? startYear;
  final int? endYear;

  @override
  List<Object?> get props => [id, name, code, startYear, endYear];
}

class TeacherCourseDepartment extends Equatable {
  const TeacherCourseDepartment({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  @override
  List<Object?> get props => [id, name, code];
}

class TeacherCourseSemester extends Equatable {
  const TeacherCourseSemester({
    required this.id,
    required this.code,
    required this.isCurrent,
    this.status,
  });

  final String id;
  final String code;
  final bool isCurrent;
  final String? status;

  @override
  List<Object?> get props => [id, code, isCurrent, status];
}

/// A section of a course.
///
/// `name`/`code` are non-null on `/teacher/courses/:id/divisions` but nullable
/// on the attendance variant of the same idea, so both are optional here and
/// read through [label].
class CourseDivision extends Equatable {
  const CourseDivision({required this.id, this.name, this.code});

  final String id;
  final String? name;
  final String? code;

  /// What to render — the web falls back `name ?? code ?? 'Section'` everywhere.
  String get label => name ?? code ?? 'Section';

  @override
  List<Object?> get props => [id, name, code];
}

/// All of one course's assignments, folded together for the list screen.
///
/// The API row is per-section; the card is per-course, showing "3 sections"
/// rather than repeating the course three times.
class TeacherCourseGroup extends Equatable {
  const TeacherCourseGroup({required this.assignment, required this.sections});

  /// The first assignment for this course — the source of the course info.
  final TeacherAssignedCourse assignment;

  /// Every division of this course the teacher instructs.
  final List<CourseDivision> sections;

  TeacherCourseInfo get course => assignment.course;

  /// "3 sections" when the teacher takes more than one, else "Div A".
  String get sectionLabel => sections.length > 1
      ? '${sections.length} sections'
      : 'Div ${sections.firstOrNull?.label ?? '—'}';

  @override
  List<Object?> get props => [assignment, sections];
}

/// `course.status` — the wire values and how each reads.
class CourseStatus {
  const CourseStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const archived = 'archived';

  static const options = [draft, active, archived];

  static String label(String value) => switch (value) {
        draft => 'Draft',
        active => 'Active',
        archived => 'Archived',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        draft => TwColors.amber,
        active => TwColors.emerald,
        archived => TwColors.slate,
        _ => TwColors.slate,
      };
}

/// `course.type` — the eleven values from `COURSE_TYPE_OPTIONS`.
class CourseType {
  const CourseType._();

  static const options = [
    'regular',
    'elective',
    'open_elective',
    'professional_elective',
    'program_elective',
    'mandatory',
    'audit',
    'laboratory',
    'project',
    'internship',
    'seminar',
  ];

  static String label(String value) => switch (value) {
        'regular' => 'Regular',
        'elective' => 'Elective',
        'open_elective' => 'Open Elective',
        'professional_elective' => 'Professional Elective',
        'program_elective' => 'Program Elective',
        'mandatory' => 'Mandatory',
        'audit' => 'Audit',
        'laboratory' => 'Laboratory',
        'project' => 'Project',
        'internship' => 'Internship',
        'seminar' => 'Seminar',
        _ => value,
      };
}
