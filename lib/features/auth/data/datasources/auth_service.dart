import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_session_model.dart';
import '../models/user_model.dart';

/// Raw HTTP calls for the auth endpoints — the port of `src/api/auth/apis.ts`
/// plus the `PATCH /users/me` call from `src/api/user-profile`.
///
/// Every method returns a model or throws an [AppException]; failure mapping
/// happens in the repository.
class AuthService {
  const AuthService(this._client);

  final DioClient _client;

  /// `POST /users/login` — public.
  ///
  /// Fails with 403 when the account is inactive or the email is unverified,
  /// and 423 after five failed attempts (locked for 15 minutes).
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiUrls.login,
      body: {'email': email, 'password': password},
      parse: (data) => AuthSessionModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /users/accept-invitation` — public. The password must be 8–128 chars.
  Future<void> acceptInvitation({
    required String token,
    required String password,
  }) async {
    await _client.post(
      ApiUrls.acceptInvitation,
      body: {'token': token, 'password': password},
      parse: (_) => null,
    );
  }

  /// `POST /users/forgot-password` — public. Emails a 6-digit code.
  ///
  /// Always succeeds, even for an address with no account: the endpoint answers
  /// identically either way so it cannot be used to discover which emails are
  /// registered. It stays silent for inactive and email-unverified accounts too,
  /// and swallows mail-send failures for the same reason — so a 200 here is not
  /// proof that anything was delivered.
  Future<void> requestPasswordReset({required String email}) async {
    await _client.post(
      ApiUrls.forgotPassword,
      body: {'email': email},
      parse: (_) => null,
    );
  }

  /// `POST /users/reset-password` — public. The password must be 8–128 chars.
  ///
  /// Every failure — unknown account, no live code, too many wrong guesses, a
  /// mismatch — comes back as one 400 carrying the same sentence, so there is
  /// nothing to branch on: show what the server said.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    await _client.post(
      ApiUrls.resetPassword,
      body: {'email': email, 'otp': otp, 'password': password},
      parse: (_) => null,
    );
  }

  /// `POST /users/logout`. Only clears the server-set cookies — the bearer
  /// token stays valid until it expires, so the local wipe is what matters.
  Future<void> logout() async {
    await _client.post(ApiUrls.logout, parse: (_) => null);
  }

  /// `PATCH /users/me`. At least one of `username` / `avatar` must be present,
  /// or the backend answers 400 "No fields provided to update".
  Future<UserModel> updateMyAccount({String? username, String? avatar}) async {
    final response = await _client.patch(
      ApiUrls.updateMyAccount,
      body: {'username': ?username, 'avatar': ?avatar},
      parse: (data) => UserModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /files/upload?isPublic=true` → the stored file's public URL.
  ///
  /// Returns `fileUrl`, not `id`. The `avatar` column holds a URL that is rendered
  /// directly, which is what the web app's avatar field stores too.
  Future<String> uploadAvatar({
    required String filePath,
    required String fileName,
  }) async {
    final response = await _client.uploadFile<String>(
      filePath: filePath,
      fileName: fileName,
      isPublic: true,
      parse: (data) {
        final url = (data as Map<String, dynamic>?)?['fileUrl'] as String?;
        if (url == null || url.isEmpty) {
          throw const FormatException('Upload succeeded but returned no fileUrl');
        }
        return url;
      },
    );
    return response.data;
  }
}
