import 'package:dartz/dartz.dart';

import '../../../../core/constants/user_constants.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_session.dart';
import '../entities/user.dart';

/// The auth contract the domain layer depends on. Implemented in
/// `data/repositories/auth_repository_impl.dart`.
abstract class AuthRepository {
  /// `POST /users/login`. Persists the session on success.
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  /// `POST /users/accept-invitation` — the only way an account is ever
  /// activated, since the backend has no self-registration route.
  Future<Either<Failure, Unit>> acceptInvitation({
    required String token,
    required String password,
  });

  /// `POST /users/logout` plus a local wipe. The local wipe happens even if the
  /// network call fails, so the user is never stuck signed in.
  Future<Either<Failure, Unit>> logout();

  /// Reads the session persisted at the last login. Returns `null` when there
  /// is none (first launch, or after a logout).
  Future<Either<Failure, AuthSession?>> getCachedSession();

  /// `PATCH /users/me` — the only mutable fields are `username` and `avatar`.
  Future<Either<Failure, User>> updateMyAccount({String? username, String? avatar});

  /// `POST /files/upload?isPublic=true`, returning the uploaded file's public URL.
  ///
  /// Avatars are uploaded publicly because the URL is stored on the user record
  /// and rendered without an auth header — the same `isPublic: true` the web app
  /// sends for this field.
  Future<Either<Failure, String>> uploadAvatar({
    required String filePath,
    required String fileName,
  });

  /// Records which role's area the user is currently in, so the choice survives
  /// a restart.
  Future<Either<Failure, Unit>> setActiveRole(UserRole role);

  /// Clears the persisted session without calling the API — used when the API
  /// has already told us the token is dead (401).
  Future<void> clearSession();
}
