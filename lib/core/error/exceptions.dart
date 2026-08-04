/// Data-layer exceptions.
///
/// These are thrown by datasources and translated into [Failure]s by
/// repository implementations. Nothing above the data layer should ever
/// catch one of these directly.
library;

/// A field-level validation message returned by the backend.
///
/// The API returns 422 bodies shaped as
/// `{ "errors": [ { "email": "email must be a valid email" } ] }` — one
/// single-entry map per offending field.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  /// Mirrors the React formatter in `src/request/api-request.ts`, which renders
  /// each entry as `• field: message` (or just `• message` for the catch-all
  /// `error` key).
  String get display => field == 'error' ? '• $message' : '• $field: $message';

  @override
  String toString() => display;
}

/// Base class for every exception raised inside the data layer.
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server answered with a non-2xx status.
class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    this.fieldErrors = const [],
  });

  final int? statusCode;
  final List<FieldError> fieldErrors;
}

/// HTTP 422 — express-validator rejected the payload. [fieldErrors] carries the
/// per-field detail.
class ValidationException extends ServerException {
  const ValidationException(super.message, {super.fieldErrors})
      : super(statusCode: 422);
}

/// The request never reached the server (no connectivity, DNS failure,
/// connection/receive timeout).
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// The access token is missing, expired, or rejected (HTTP 401).
///
/// The backend issues 15-minute access tokens and exposes **no refresh
/// endpoint**, so this is terminal: the session must be cleared and the user
/// sent back to login.
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message);
}

/// The caller lacks the role required by the endpoint (HTTP 403), or the
/// account is inactive / unverified.
class ForbiddenException extends AppException {
  const ForbiddenException(super.message);
}

/// The account is locked after too many failed login attempts (HTTP 423).
class AccountLockedException extends AppException {
  const AccountLockedException(super.message);
}

/// Reading from or writing to local storage failed.
class CacheException extends AppException {
  const CacheException(super.message);
}
