import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Activates an invited account by setting its first password.
///
/// The invitation token is an access token minted with a 7-day expiry, handed
/// to the user by email as `/invite/set-password?token=…`.
class AcceptInvitationUseCase implements UseCase<Unit, AcceptInvitationParams> {
  const AcceptInvitationUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AcceptInvitationParams params) =>
      _repository.acceptInvitation(token: params.token, password: params.password);
}

class AcceptInvitationParams extends Equatable {
  const AcceptInvitationParams({required this.token, required this.password});

  final String token;

  /// The backend validator requires 8–128 characters.
  final String password;

  @override
  List<Object?> get props => [token, password];
}
