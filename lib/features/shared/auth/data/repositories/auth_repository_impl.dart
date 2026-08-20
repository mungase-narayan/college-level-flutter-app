import 'package:dartz/dartz.dart';

import '../../../../../core/constants/user_constants.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_service.dart';
import '../datasources/auth_service.dart';
import '../models/auth_session_model.dart';

/// Implements [AuthRepository] over the remote [AuthService] and the local
/// [AuthLocalService], translating exceptions into [Failure]s.
class AuthRepositoryImpl with RepositoryGuard implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._local);

  final AuthService _remote;
  final AuthLocalService _local;

  @override
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    return guard(() async {
      final session = await _remote.login(email: email, password: password);

      // A user with no active roles can authenticate but has nowhere to land,
      // so surface that here rather than dropping them on a blank shell.
      if (session.roles.isEmpty) {
        throw const ForbiddenException(
          'Your account has no active role. Please contact your school admin.',
        );
      }

      await _local.save(session);
      return session;
    });
  }

  @override
  Future<Either<Failure, Unit>> acceptInvitation({
    required String token,
    required String password,
  }) =>
      guard(() async {
        await _remote.acceptInvitation(token: token, password: password);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> requestPasswordReset({
    required String email,
  }) =>
      guard(() async {
        await _remote.requestPasswordReset(email: email);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) =>
      guard(() async {
        await _remote.resetPassword(email: email, otp: otp, password: password);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> logout() async {
    // The local wipe must happen regardless — a failed network call should
    // never leave the user stuck in a session they asked to end.
    try {
      await _remote.logout();
    } catch (_) {
      // Ignored on purpose.
    }
    await _local.clear();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AuthSession?>> getCachedSession() =>
      guard(() => _local.read());

  @override
  Future<Either<Failure, User>> updateMyAccount({
    String? username,
    String? avatar,
  }) =>
      guard(() async {
        final user = await _remote.updateMyAccount(
          username: username,
          avatar: avatar,
        );

        // Keep the cached session in step so a restart doesn't resurrect the
        // old username or avatar.
        final cached = await _local.read();
        if (cached != null) {
          await _local.updateCachedSession(
            AuthSessionModel.fromEntity(cached.copyWith(user: user)),
          );
        }
        return user;
      });


  @override
  Future<Either<Failure, String>> uploadAvatar({
    required String filePath,
    required String fileName,
  }) =>
      guard(() => _remote.uploadAvatar(filePath: filePath, fileName: fileName));

  @override
  Future<Either<Failure, Unit>> setActiveRole(UserRole role) => guard(() async {
        await _local.setActiveRole(role);
        return unit;
      });

  @override
  Future<void> clearSession() => _local.clear();

}
