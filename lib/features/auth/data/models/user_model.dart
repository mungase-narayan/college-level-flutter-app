import '../../../../core/constants/user_constants.dart';
import '../../domain/entities/user.dart';

/// JSON ↔ [User]. The shape is `LoginUserDto` on the backend.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.schoolId,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.username,
    required super.isEmailVerified,
    required super.status,
    super.middleName,
    super.fullName,
    super.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        schoolId: json['schoolId'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        middleName: json['middleName'] as String?,
        lastName: json['lastName'] as String? ?? '',
        fullName: json['fullName'] as String?,
        email: json['email'] as String? ?? '',
        username: json['username'] as String? ?? '',
        isEmailVerified: json['isEmailVerified'] as bool? ?? false,
        avatar: json['avatar'] as String?,
        status: json['status'] as String? ?? 'active',
      );

  factory UserModel.fromEntity(User user) => UserModel(
        id: user.id,
        schoolId: user.schoolId,
        firstName: user.firstName,
        middleName: user.middleName,
        lastName: user.lastName,
        fullName: user.fullName,
        email: user.email,
        username: user.username,
        isEmailVerified: user.isEmailVerified,
        avatar: user.avatar,
        status: user.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'schoolId': schoolId,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'fullName': fullName,
        'email': email,
        'username': username,
        'isEmailVerified': isEmailVerified,
        'avatar': avatar,
        'status': status,
      };
}

/// JSON ↔ [LoginRole] (`{ name, userRoleId }`).
class LoginRoleModel extends LoginRole {
  const LoginRoleModel({required super.name, required super.userRoleId});

  /// Returns null for a role name this client doesn't know, so an unexpected
  /// value from a newer backend degrades to "role ignored" rather than a crash.
  static LoginRoleModel? tryFromJson(Map<String, dynamic> json) {
    final role = UserRole.fromWire(json['name'] as String?);
    if (role == null) return null;
    return LoginRoleModel(
      name: role,
      userRoleId: json['userRoleId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name.wire, 'userRoleId': userRoleId};
}

/// JSON ↔ [Tokens].
class TokensModel extends Tokens {
  const TokensModel({required super.accessToken, required super.refreshToken});

  factory TokensModel.fromJson(Map<String, dynamic> json) => TokensModel(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}
