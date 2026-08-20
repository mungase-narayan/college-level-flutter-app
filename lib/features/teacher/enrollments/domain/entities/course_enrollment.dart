import 'package:equatable/equatable.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// A student's enrolment on a course.
class CourseEnrollmentRow extends Equatable {
  const CourseEnrollmentRow({
    required this.id,
    required this.studentId,
    required this.userId,
    required this.status,
    required this.fullName,
    this.email,
    this.avatar,
    this.rollNumber,
    this.prnNumber,
    this.divisionName,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String userId;

  /// `active | archived | dropped`.
  final String status;
  final String fullName;
  final String? email;
  final String? avatar;
  final String? rollNumber;
  final String? prnNumber;
  final String? divisionName;
  final String? createdAt;

  /// What the search box matches, mirroring the web: name, email, roll number.
  bool matches(String term) {
    if (term.isEmpty) return true;
    final needle = term.toLowerCase();
    return [fullName, email, rollNumber]
        .any((field) => (field ?? '').toLowerCase().contains(needle));
  }

  @override
  List<Object?> get props => [id, studentId, userId, status, fullName];
}

/// A student who could be enrolled but isn't yet — the picker's row.
class UnenrolledStudent extends Equatable {
  const UnenrolledStudent({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.avatar,
    this.rollNumber,
    this.divisionName,
  });

  /// The **student profile** id, which is what the enrol body wants.
  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String? avatar;
  final String? rollNumber;
  final String? divisionName;

  String? get subtitle {
    final parts = [
      if ((rollNumber ?? '').isNotEmpty) rollNumber!,
      if ((email ?? '').isNotEmpty) email!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props => [id, userId, fullName, rollNumber];
}

/// `enrollment.status`.
class EnrollmentStatus {
  const EnrollmentStatus._();

  static const active = 'active';
  static const archived = 'archived';
  static const dropped = 'dropped';

  static const options = [active, archived, dropped];

  static String label(String value) => switch (value) {
        active => 'Active',
        archived => 'Archived',
        dropped => 'Dropped',
        _ => value,
      };

  static TwShade shade(String value) => switch (value) {
        active => TwColors.emerald,
        archived => TwColors.slate,
        dropped => TwColors.rose,
        _ => TwColors.slate,
      };
}
