import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/user_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/session_manager.dart';
import '../models/auth_session_model.dart';

/// Persists the session across launches.
///
/// The split mirrors the security trade-off the web app couldn't make: the
/// **tokens** go to the platform keystore via [SessionManager], while the
/// non-secret half (user, school, roles, active role) goes to
/// `shared_preferences`. On the web all of it — tokens included — sat in
/// `localStorage` under `persist:root`.
class AuthLocalService {
  const AuthLocalService(this._prefs, this._session);

  static const _sessionKey = 'college_level.auth_session';

  final SharedPreferences _prefs;
  final SessionManager _session;

  Future<void> save(AuthSessionModel session) async {
    try {
      await _session.save(
        accessToken: session.tokens.accessToken,
        refreshToken: session.tokens.refreshToken,
      );
      await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (error) {
      throw CacheException('Could not save your session: $error');
    }
  }

  /// Returns the persisted session, or null when there is none.
  ///
  /// The tokens come from the keystore rather than the JSON blob, so a session
  /// whose keystore entry was cleared (OS wipe, app data reset) is treated as
  /// no session at all instead of a broken one.
  Future<AuthSessionModel?> read() async {
    try {
      final raw = _prefs.getString(_sessionKey);
      if (raw == null) return null;

      await _session.restore();
      final accessToken = _session.accessToken;
      if (accessToken == null) {
        await clear();
        return null;
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      json['tokens'] = {
        'accessToken': accessToken,
        'refreshToken': _session.refreshToken ?? '',
      };
      return AuthSessionModel.fromJson(json);
    } catch (_) {
      // A corrupt blob should log the user out, not brick the app.
      await clear();
      return null;
    }
  }

  Future<void> setActiveRole(UserRole role) async {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json['activeRole'] = role.wire;
      await _prefs.setString(_sessionKey, jsonEncode(json));
    } catch (error) {
      throw CacheException('Could not save the selected role: $error');
    }
  }

  /// Replaces the cached user after a `PATCH /users/me`.
  Future<void> updateCachedSession(AuthSessionModel session) async {
    await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_sessionKey);
    await _session.clear();
  }
}
