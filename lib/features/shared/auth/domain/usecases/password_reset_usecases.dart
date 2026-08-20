import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Asks the server to email a one-time code.
///
/// A [Right] means the request was accepted, **not** that an email went out:
/// the server answers identically for an address it has never seen, and stays
/// silent for inactive and unverified accounts too, so that the endpoint cannot
/// be used to enumerate registered emails. Nothing on screen may claim an email
/// has arrived.
class RequestPasswordResetUseCase
    implements UseCase<Unit, RequestPasswordResetParams> {
  const RequestPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RequestPasswordResetParams params) =>
      _repository.requestPasswordReset(email: params.email);
}

class RequestPasswordResetParams extends Equatable {
  const RequestPasswordResetParams({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Sets a new password using the emailed code.
///
/// The code is six digits, lives ten minutes, and is burned after five wrong
/// guesses — but none of that is distinguishable from the response, which is
/// one 400 with a single sentence for every failure.
class ResetPasswordUseCase implements UseCase<Unit, ResetPasswordParams> {
  const ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ResetPasswordParams params) =>
      _repository.resetPassword(
        email: params.email,
        otp: params.otp,
        password: params.password,
      );
}

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({
    required this.email,
    required this.otp,
    required this.password,
  });

  final String email;

  /// Exactly six digits — the server matches `^\d{6}$` and answers 422 otherwise.
  final String otp;

  /// The backend validator requires 8–128 characters.
  final String password;

  @override
  List<Object?> get props => [email, otp, password];
}
