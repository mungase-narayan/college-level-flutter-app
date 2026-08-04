import 'package:dio/dio.dart';

import '../constants/api_urls.dart';
import '../error/exceptions.dart';
import 'api_response.dart';
import 'session_manager.dart';

/// The app's entire HTTP layer — the port of `src/request/api-request.ts`.
///
/// Two Dio instances, matching the two axios instances in the React app:
///
/// * [_dio] attaches the bearer token and translates every non-2xx response
///   into a typed [AppException]. A 401 additionally fires
///   [SessionManager.notifyUnauthorized] (the React `performLogout()`).
/// * [_publicDio] attaches the token when one happens to exist but has **no**
///   error interceptor, so an expected 404 (an unknown `@username`) neither
///   toasts nor logs the user out.
class DioClient {
  DioClient({required this.session, Dio? dio, Dio? publicDio})
      : _dio = dio ?? Dio(),
        _publicDio = publicDio ?? Dio() {
    for (final client in [_dio, _publicDio]) {
      client.options
        ..baseUrl = ApiUrls.baseUrl
        ..connectTimeout = const Duration(seconds: 20)
        ..receiveTimeout = const Duration(seconds: 60)
        ..sendTimeout = const Duration(seconds: 60)
        ..headers = {'Content-Type': 'application/json'}
        // The envelope is meaningful at every status, so let the interceptor
        // decide what counts as an error rather than Dio's default.
        ..validateStatus = (_) => true;

      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = session.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(onResponse: _onResponse, onError: _onError),
    );
  }

  final SessionManager session;
  final Dio _dio;
  final Dio _publicDio;

  /// Exposed so the public-profile datasource can opt out of the interceptor.
  Dio get publicDio => _publicDio;

  // ── Verbs ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) =>
      _send(path, method: 'GET', query: query, parse: parse);

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) =>
      _send(path, method: 'POST', body: body, query: query, parse: parse);

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) =>
      _send(path, method: 'PATCH', body: body, query: query, parse: parse);

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) =>
      _send(path, method: 'PUT', body: body, query: query, parse: parse);

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) =>
      _send(path, method: 'DELETE', body: body, query: query, parse: parse);

  /// Uploads a single file to `POST /files/upload`.
  ///
  /// The multipart field name is **`file`** — the only name the backend's
  /// multer config accepts. Every other endpoint takes the returned file uuid,
  /// never raw bytes.
  Future<ApiResponse<T>> uploadFile<T>({
    required String filePath,
    required String fileName,
    String? folder,
    bool isPublic = false,
    required T Function(Object? data) parse,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _send(
      ApiUrls.fileUpload,
      method: 'POST',
      body: form,
      // A null `folder` is dropped by _clean().
      query: {'isPublic': isPublic, 'folder': folder},
      parse: parse,
    );
  }

  // ── Plumbing ──────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> _send<T>(
    String path, {
    required String method,
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) async {
    final response = await _dio.request<dynamic>(
      path,
      data: body,
      queryParameters: _clean(query),
      options: Options(
        method: method,
        contentType: body is FormData ? 'multipart/form-data' : null,
      ),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      // A handful of non-envelope endpoints (/health) answer with a bare shape.
      return ApiResponse<T>(
        statusCode: response.statusCode ?? 200,
        data: parse(data),
        message: '',
        success: true,
      );
    }
    return ApiResponse<T>.fromJson(data, parse);
  }

  /// Dio sends `null` query values as empty strings, which the backend's
  /// validators reject; drop them instead.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value != '') entry.key: entry.value,
    };
    return cleaned.isEmpty ? null : cleaned;
  }

  /// `validateStatus` lets everything through, so success/failure is decided
  /// here off the envelope.
  void _onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      handler.next(response);
      return;
    }
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: _exceptionFor(status, response.data),
      ),
      true,
    );
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    // Already typed by _onResponse — just make sure a 401 fires the logout.
    if (error.error is AppException) {
      if (error.error is UnauthorizedException) session.notifyUnauthorized();
      handler.reject(error);
      return;
    }

    final status = error.response?.statusCode;
    if (status == null) {
      handler.reject(
        error.copyWith(
          error: const NetworkException('Network error. Please check your connection.'),
        ),
      );
      return;
    }

    final typed = _exceptionFor(status, error.response?.data);
    if (typed is UnauthorizedException) session.notifyUnauthorized();
    handler.reject(error.copyWith(error: typed));
  }

  /// Builds the typed exception from an error envelope
  /// (`{ statusCode, data: null, success: false, errors: [], message }`).
  AppException _exceptionFor(int status, Object? body) {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final message = (map['message'] as String?)?.trim();
    final fieldErrors = _parseFieldErrors(map['errors']);

    return switch (status) {
      401 => const UnauthorizedException(
          'Your session has expired. Please log in again.',
        ),
      403 => ForbiddenException(
          message ?? 'You are not allowed to perform this action',
        ),
      422 => ValidationException(
          message ?? 'Received data is not valid',
          fieldErrors: fieldErrors,
        ),
      423 => AccountLockedException(
          message ?? 'Account is locked. Try again later.',
        ),
      _ => ServerException(
          message ?? 'Something went wrong',
          statusCode: status,
          fieldErrors: fieldErrors,
        ),
    };
  }

  /// `errors` is `Array<Record<field, message>>` — one single-entry map per
  /// offending field.
  List<FieldError> _parseFieldErrors(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .expand(
          (entry) => entry.entries.map(
            (e) => FieldError(field: '${e.key}', message: '${e.value}'),
          ),
        )
        .toList(growable: false);
  }
}
