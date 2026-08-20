import 'package:equatable/equatable.dart';

import '../../../../../core/constants/user_constants.dart';
import 'school.dart';
import 'user.dart';

/// Everything `POST /users/login` returns, which is also everything the React
/// `authSlice` persists.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.roles,
    required this.tokens,
    this.school,
    this.activeRole,
  });

  final User user;
  final School? school;
  final List<LoginRole> roles;
  final Tokens tokens;

  /// Which role's area the user is currently in.
  ///
  /// `setAuth` defaults this to `roles[0].name` so single-role users — who
  /// never see the role selector — still land with a role active.
  final UserRole? activeRole;

  UserRole? get defaultRole => roles.isEmpty ? null : roles.first.name;

  /// The landing path for this session, the port of `handleNavigate(roles)`.
  String get homePath => (activeRole ?? defaultRole)?.home ?? '/';

  bool hasRole(UserRole role) => roles.any((r) => r.name == role);

  /// True when any of the user's roles is a teaching role.
  bool get hasTeacherRole => roles.any((r) => r.name.isTeacher);

  bool get isMultiRole => roles.length > 1;

  AuthSession copyWith({User? user, UserRole? activeRole}) => AuthSession(
        user: user ?? this.user,
        school: school,
        roles: roles,
        tokens: tokens,
        activeRole: activeRole ?? this.activeRole,
      );

  @override
  List<Object?> get props => [user, school, roles, tokens, activeRole];
}
