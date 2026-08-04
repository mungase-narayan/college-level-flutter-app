import '../../../../core/constants/user_constants.dart';
import '../../domain/entities/auth_session.dart';
import 'school_model.dart';
import 'user_model.dart';

/// JSON ↔ [AuthSession].
///
/// [fromJson] parses the `data` object of `POST /users/login`; [toJson] is what
/// gets cached locally, so the same shape round-trips through storage.
class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.user,
    required super.roles,
    required super.tokens,
    super.school,
    super.activeRole,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final roles = ((json['roles'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LoginRoleModel.tryFromJson)
        .nonNulls
        .toList(growable: false);

    return AuthSessionModel(
      user: UserModel.fromJson((json['user'] as Map<String, dynamic>?) ?? const {}),
      school: json['school'] is Map<String, dynamic>
          ? SchoolModel.fromJson(json['school'] as Map<String, dynamic>)
          : null,
      roles: roles,
      tokens: TokensModel.fromJson(
        (json['tokens'] as Map<String, dynamic>?) ?? const {},
      ),
      // `setAuth` defaults the active role to the first role, so single-role
      // users never land with a null active role.
      activeRole: UserRole.fromWire(json['activeRole'] as String?) ??
          (roles.isEmpty ? null : roles.first.name),
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession session) => AuthSessionModel(
        user: session.user,
        school: session.school,
        roles: session.roles,
        tokens: session.tokens,
        activeRole: session.activeRole,
      );

  Map<String, dynamic> toJson() => {
        'user': UserModel.fromEntity(user).toJson(),
        'school': school == null ? null : SchoolModel.fromEntity(school!).toJson(),
        'roles': [
          for (final role in roles)
            LoginRoleModel(name: role.name, userRoleId: role.userRoleId).toJson(),
        ],
        'tokens': TokensModel(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ).toJson(),
        'activeRole': activeRole?.wire,
      };
}
