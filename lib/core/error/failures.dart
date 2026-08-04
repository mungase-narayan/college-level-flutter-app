import 'package:equatable/equatable.dart';

import 'exceptions.dart';

/// Domain-layer failures.
///
/// Repositories return `Either<Failure, T>`; blocs pattern-match on the
/// concrete type to decide whether to show an inline message, a toast, or to
/// bounce the user to login.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// A message safe to render directly to the user.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// A non-2xx response that isn't one of the specialised cases below.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// The request never reached the server.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Please check your connection.']);
}

/// HTTP 401 — the session is over. The router listens for this and redirects.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Your session has expired. Please log in again.']);
}

/// HTTP 403 — wrong role, inactive account, or unverified email.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message);
}

/// HTTP 423 — too many failed login attempts.
class AccountLockedFailure extends Failure {
  const AccountLockedFailure(super.message);
}

/// HTTP 422 — express-validator rejected the payload. [fieldErrors] carries the
/// per-field detail so forms can highlight the offending inputs.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const []});

  final List<FieldError> fieldErrors;

  /// The full message as the React app renders it: the summary line followed by
  /// one `• field: message` line per field error.
  String get detailedMessage {
    if (fieldErrors.isEmpty) return message;
    return '$message\n${fieldErrors.map((e) => e.display).join('\n')}';
  }

  @override
  List<Object?> get props => [message, fieldErrors.map((e) => e.display).toList()];
}

/// Local storage read/write failed.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read locally stored data.']);
}

/// Maps a data-layer [AppException] onto its domain [Failure].
///
/// Every repository implementation funnels its `catch` blocks through here so
/// the translation stays in one place.
Failure mapExceptionToFailure(Object error) {
  return switch (error) {
    ValidationException e => ValidationFailure(e.message, fieldErrors: e.fieldErrors),
    UnauthorizedException e => UnauthorizedFailure(e.message),
    ForbiddenException e => ForbiddenFailure(e.message),
    AccountLockedException e => AccountLockedFailure(e.message),
    NetworkException e => NetworkFailure(e.message),
    CacheException e => CacheFailure(e.message),
    ServerException e => ServerFailure(e.message, statusCode: e.statusCode),
    _ => const ServerFailure('Something went wrong'),
  };
}
