import 'package:equatable/equatable.dart';

import '../../../../../core/constants/user_constants.dart';

/// The authenticated user, field-for-field from `LoginUserDto`
/// (`src/modules/user/dto/login-response.dto.ts`) and the web's
/// `src/types/user.types.ts`.
class User extends Equatable {
  const User({
    required this.id,
    required this.schoolId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.isEmailVerified,
    required this.status,
    this.middleName,
    this.fullName,
    this.avatar,
  });

  final String id;
  final String schoolId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? fullName;
  final String email;
  final String username;
  final bool isEmailVerified;
  final String? avatar;
  final String status;

  /// `fullName` is nullable on the wire, so fall back to composing the parts.
  String get displayName {
    final composed = [firstName, middleName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(' ');
    final name = (fullName ?? '').trim();
    return name.isNotEmpty ? name : composed;
  }

  /// The public-profile handle, rendered as `@username` throughout the UI.
  String get handle => '@$username';

  User copyWith({String? username, String? avatar, bool clearAvatar = false}) => User(
        id: id,
        schoolId: schoolId,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        fullName: fullName,
        email: email,
        username: username ?? this.username,
        isEmailVerified: isEmailVerified,
        avatar: clearAvatar ? null : (avatar ?? this.avatar),
        status: status,
      );

  @override
  List<Object?> get props => [
        id,
        schoolId,
        firstName,
        middleName,
        lastName,
        fullName,
        email,
        username,
        isEmailVerified,
        avatar,
        status,
      ];
}

/// One of the user's active roles. The JWT carries only `{ user: { id } }`, so
/// this list — returned by login — is the only source of role information the
/// client has.
class LoginRole extends Equatable {
  const LoginRole({required this.name, required this.userRoleId});

  final UserRole name;
  final String userRoleId;

  @override
  List<Object?> get props => [name, userRoleId];
}

/// The access/refresh pair issued at login.
///
/// [refreshToken] is stored because the API returns it, but nothing consumes
/// it: the backend never wired a refresh route, so a 15-minute access token
/// simply expires into a forced re-login.
class Tokens extends Equatable {
  const Tokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
