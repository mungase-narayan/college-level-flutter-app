import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the access/refresh tokens for the lifetime of the process and mirrors
/// them into the platform keystore.
///
/// This is the Flutter counterpart of the React app reading
/// `store.getState().auth.tokens?.accessToken` inside the axios request
/// interceptor — except tokens live in `flutter_secure_storage` rather than
/// `localStorage`, since the whole redux slice (tokens included) was persisted
/// in plaintext on the web.
///
/// It deliberately knows nothing about the user or their roles; that half of
/// the session is owned by the auth feature's local datasource.
class SessionManager {
  SessionManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'college_level.access_token';
  static const _refreshTokenKey = 'college_level.refresh_token';

  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;

  final _unauthorizedController = StreamController<void>.broadcast();

  /// Emits whenever the API rejects a request with 401.
  ///
  /// The backend has no refresh endpoint, so a 401 is terminal: `AuthBloc`
  /// listens here, clears the session, and the router redirects to login. This
  /// is the port of `performLogout()` in `src/request/api-request.ts`.
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _accessToken != null;

  /// Loads tokens from secure storage into memory. Call once at boot, before
  /// the first request is made.
  Future<void> restore() async {
    _accessToken = await _storage.read(key: _accessTokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Called by the Dio error interceptor on a 401.
  void notifyUnauthorized() {
    if (!_unauthorizedController.isClosed) _unauthorizedController.add(null);
  }

  Future<void> dispose() => _unauthorizedController.close();
}
