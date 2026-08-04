import 'package:flutter/material.dart';

import '../config/theme/app_colors.dart';

/// The seven role names in `ROLE_NAMES`
/// (`college-level-backend/src/modules/role/constants/role.constants.ts`,
/// mirrored by `src/constants/user.constants.ts` on the web).
enum UserRole {
  student('student'),
  teacher('teacher'),
  classTeacher('class_teacher'),
  hod('hod'),
  schoolAdmin('school_admin'),
  superAdmin('super_admin'),
  accountant('accountant');

  const UserRole(this.wire);

  /// The exact string the API sends and expects.
  final String wire;

  static UserRole? fromWire(String? value) {
    for (final role in UserRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }

  /// `class_teacher` and `hod` are treated as ordinary teachers everywhere in
  /// the React app (`TEACHER_ROLES`); no distinct UI exists for them.
  static const teacherRoles = {UserRole.teacher, UserRole.classTeacher, UserRole.hod};

  bool get isTeacher => teacherRoles.contains(this);

  /// Landing path after login — a verbatim port of `ROLE_HOME` in
  /// `src/lib/utils.ts`. Note super admin lands on `/school`, not `/dashboard`.
  String get home => switch (this) {
        UserRole.student => '/student/dashboard',
        UserRole.teacher || UserRole.classTeacher || UserRole.hod => '/teacher/dashboard',
        UserRole.schoolAdmin => '/school-admin/dashboard',
        UserRole.superAdmin => '/super-admin/school',
        UserRole.accountant => '/accountant/dashboard',
      };

  /// Label, description, icon, and tint from `src/constants/role-config.ts`.
  String get label => switch (this) {
        UserRole.student => 'Student',
        UserRole.teacher => 'Teacher',
        UserRole.classTeacher => 'Class Teacher',
        UserRole.hod => 'Head of Department',
        UserRole.schoolAdmin => 'School Admin',
        UserRole.superAdmin => 'Super Admin',
        UserRole.accountant => 'Accountant',
      };

  String get description => switch (this) {
        UserRole.student => 'Access courses, grades & attendance',
        UserRole.teacher => 'Manage classes, marks & students',
        UserRole.classTeacher => 'Oversee your class & student records',
        UserRole.hod => 'Coordinate department & faculty',
        UserRole.schoolAdmin => 'Manage school operations & staff',
        UserRole.superAdmin => 'Full platform access & configuration',
        UserRole.accountant => 'Admit students & manage admissions',
      };

  IconData get icon => switch (this) {
        UserRole.student => Icons.school_outlined,
        UserRole.teacher || UserRole.classTeacher => Icons.co_present_outlined,
        UserRole.hod => Icons.account_tree_outlined,
        UserRole.schoolAdmin => Icons.admin_panel_settings_outlined,
        UserRole.superAdmin => Icons.shield_outlined,
        UserRole.accountant => Icons.receipt_long_outlined,
      };

  /// The gradient tint each role card uses on the web, reduced to its base hue.
  TwShade get shade => switch (this) {
        UserRole.student => TwColors.blue,
        UserRole.teacher => TwColors.emerald,
        UserRole.classTeacher => TwColors.teal,
        UserRole.hod => TwColors.orange,
        UserRole.schoolAdmin => TwColors.violet,
        UserRole.superAdmin => TwColors.rose,
        UserRole.accountant => TwColors.amber,
      };

  /// The two-colour gradient from `role-config.ts`, for the role selector cards.
  List<Color> get gradient => switch (this) {
        UserRole.student => [TwColors.blue.s500, TwColors.cyan.s500],
        UserRole.teacher => [TwColors.emerald.s500, TwColors.teal.s500],
        UserRole.classTeacher => [TwColors.teal.s500, TwColors.cyan.s700],
        UserRole.hod => [TwColors.orange.s500, TwColors.amber.s500],
        UserRole.schoolAdmin => [TwColors.violet.s500, TwColors.purple.s700],
        UserRole.superAdmin => [TwColors.rose.s500, TwColors.pink.s700],
        UserRole.accountant => [TwColors.amber.s500, TwColors.orange.s700],
      };
}

/// `USER_STATUSES` from `src/constants/user.constants.ts`.
const userStatuses = ['active', 'inactive', 'suspended', 'blocked', 'archived'];

/// `GENDERS` from the same file.
const genders = ['male', 'female', 'other', 'prefer_not_to_say'];
