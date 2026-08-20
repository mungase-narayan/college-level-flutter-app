import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constants/user_constants.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Ends the session: revokes cookies server-side, then wipes local storage.
class LogoutUseCase implements UseCase<Unit, NoParams> {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.logout();
}

/// Reads the persisted session at boot. `null` means "no one is signed in".
class GetCachedSessionUseCase implements UseCase<AuthSession?, NoParams> {
  const GetCachedSessionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession?>> call(NoParams params) =>
      _repository.getCachedSession();
}

/// Switches which role's area the user is in, from the login role selector or
/// the settings screen.
class SetActiveRoleUseCase implements UseCase<Unit, UserRole> {
  const SetActiveRoleUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(UserRole params) =>
      _repository.setActiveRole(params);
}

/// `PATCH /users/me`. Only `username` and `avatar` are editable.
class UpdateMyAccountUseCase implements UseCase<User, UpdateMyAccountParams> {
  const UpdateMyAccountUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(UpdateMyAccountParams params) =>
      _repository.updateMyAccount(username: params.username, avatar: params.avatar);
}

/// Uploads an image and yields the public URL to store as the avatar.
class UploadAvatarUseCase implements UseCase<String, UploadAvatarParams> {
  const UploadAvatarUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadAvatarParams params) =>
      _repository.uploadAvatar(
        filePath: params.filePath,
        fileName: params.fileName,
      );
}

class UploadAvatarParams extends Equatable {
  const UploadAvatarParams({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;

  @override
  List<Object?> get props => [filePath, fileName];
}

class UpdateMyAccountParams extends Equatable {
  const UpdateMyAccountParams({this.username, this.avatar});

  final String? username;

  /// The public URL returned by `POST /files/upload` — never raw bytes, and not
  /// the file's uuid. The web app stores `fileUrl` in this field too.
  final String? avatar;

  @override
  List<Object?> get props => [username, avatar];
}
