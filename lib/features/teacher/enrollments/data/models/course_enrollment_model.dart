import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/course_enrollment.dart';

class CourseEnrollmentRowModel extends CourseEnrollmentRow {
  const CourseEnrollmentRowModel({
    required super.id,
    required super.studentId,
    required super.userId,
    required super.status,
    required super.fullName,
    super.email,
    super.avatar,
    super.rollNumber,
    super.prnNumber,
    super.divisionName,
    super.createdAt,
  });

  /// Identity lives under `user`, the roll and PRN under `student`, and the
  /// section under `division` — three nested objects, any of which may be absent.
  factory CourseEnrollmentRowModel.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    final student = (json['student'] as Map<String, dynamic>?) ?? const {};
    final division = (json['division'] as Map<String, dynamic>?) ?? const {};

    return CourseEnrollmentRowModel(
      id: asString(json['id']),
      studentId: asString(json['studentId']),
      userId: asString(json['userId']),
      status: asString(json['status']),
      fullName: asStringOrNull(user['fullName']) ??
          asStringOrNull(user['email']) ??
          '',
      email: asStringOrNull(user['email']),
      avatar: asStringOrNull(user['avatar']),
      rollNumber: asStringOrNull(student['rollNumber']),
      prnNumber: asStringOrNull(student['prnNumber']),
      divisionName: asStringOrNull(division['name']) ??
          asStringOrNull(division['code']),
      createdAt: asStringOrNull(json['createdAt']),
    );
  }
}

class UnenrolledStudentModel extends UnenrolledStudent {
  const UnenrolledStudentModel({
    required super.id,
    required super.userId,
    required super.fullName,
    super.email,
    super.avatar,
    super.rollNumber,
    super.divisionName,
  });

  /// Flat, unlike the enrolment row — this endpoint returns the student's own
  /// columns rather than a join.
  factory UnenrolledStudentModel.fromJson(Map<String, dynamic> json) {
    final division = (json['division'] as Map<String, dynamic>?) ?? const {};
    return UnenrolledStudentModel(
      id: asString(json['id']),
      userId: asString(json['userId']),
      fullName: asStringOrNull(json['fullName']) ??
          asStringOrNull(json['email']) ??
          '',
      email: asStringOrNull(json['email']),
      avatar: asStringOrNull(json['avatar']),
      rollNumber: asStringOrNull(json['rollNumber']),
      divisionName: asStringOrNull(division['name']) ??
          asStringOrNull(division['code']),
    );
  }
}
