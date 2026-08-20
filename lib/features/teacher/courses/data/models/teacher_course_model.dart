import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/teacher_course.dart';

class TeacherAssignedCourseModel extends TeacherAssignedCourse {
  const TeacherAssignedCourseModel({
    required super.id,
    required super.status,
    required super.divisionId,
    required super.course,
  });

  factory TeacherAssignedCourseModel.fromJson(Map<String, dynamic> json) =>
      TeacherAssignedCourseModel(
        id: asString(json['id']),
        status: asString(json['status']),
        divisionId: asString(json['divisionId']),
        course: TeacherCourseInfoModel.fromJson(
          (json['course'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

class TeacherCourseInfoModel extends TeacherCourseInfo {
  const TeacherCourseInfoModel({
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
  });

  factory TeacherCourseInfoModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseInfoModel(
        id: asString(json['id']),
        name: asString(json['name']),
        code: asString(json['code']),
        type: asString(json['type']),
        status: asString(json['status']),
        credits: asInt(json['credits']),
        description: asStringOrNull(json['description']),
        colorCode: asStringOrNull(json['colorCode']),
        batch: asObject(json['batch'], TeacherCourseBatchModel.fromJson),
        department:
            asObject(json['department'], TeacherCourseDepartmentModel.fromJson),
        semester: asObject(json['semester'], TeacherCourseSemesterModel.fromJson),
        division: asObject(json['division'], CourseDivisionModel.fromJson),
      );
}

class TeacherCourseBatchModel extends TeacherCourseBatch {
  const TeacherCourseBatchModel({
    required super.id,
    required super.name,
    required super.code,
    super.startYear,
    super.endYear,
  });

  factory TeacherCourseBatchModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseBatchModel(
        id: asString(json['id']),
        name: asString(json['name']),
        code: asString(json['code']),
        startYear: asIntOrNull(json['startYear']),
        endYear: asIntOrNull(json['endYear']),
      );
}

class TeacherCourseDepartmentModel extends TeacherCourseDepartment {
  const TeacherCourseDepartmentModel({
    required super.id,
    required super.name,
    required super.code,
  });

  factory TeacherCourseDepartmentModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseDepartmentModel(
        id: asString(json['id']),
        name: asString(json['name']),
        code: asString(json['code']),
      );
}

class TeacherCourseSemesterModel extends TeacherCourseSemester {
  const TeacherCourseSemesterModel({
    required super.id,
    required super.code,
    required super.isCurrent,
    super.status,
  });

  factory TeacherCourseSemesterModel.fromJson(Map<String, dynamic> json) =>
      TeacherCourseSemesterModel(
        id: asString(json['id']),
        // Sent as a NUMBER for numeric semesters ("3" arrives as 3), so this
        // cannot be a plain String cast — that threw and took the whole list
        // down with a bare "Something went wrong".
        code: asString(json['code']),
        isCurrent: asBool(json['isCurrent']),
        status: asStringOrNull(json['status']),
      );
}

class CourseDivisionModel extends CourseDivision {
  const CourseDivisionModel({required super.id, super.name, super.code});

  factory CourseDivisionModel.fromJson(Map<String, dynamic> json) =>
      CourseDivisionModel(
        id: asString(json['id']),
        // Divisions are often named "1"/"2" and arrive as numbers.
        name: asStringOrNull(json['name']),
        code: asStringOrNull(json['code']),
      );
}
