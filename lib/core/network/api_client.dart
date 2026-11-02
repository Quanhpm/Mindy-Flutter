import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_error.dart';
import 'cookie_storage.dart';

/// Một instance dùng chung cho toàn app.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// HTTP client - tương đương `src/config/http/http.config.ts`.
///
/// - Trả thẳng `response.data` (backend không bọc `{ data }`).
/// - Cookie HttpOnly (`access_token`, `refresh_token`) lưu trong secure storage.
/// - Gặp 401 `AUTHENTICATION_REQUIRED`: gọi `auth/refresh` đúng MỘT lần cho mọi
///   request đang lỗi (single-flight), rồi gửi lại request gốc tối đa 1 lần.
/// - Mọi lỗi đều được chuẩn hoá thành [ApiError].
class ApiClient {
  ApiClient({CookieJar? cookieJar})
      : cookieJar = cookieJar ??
            PersistCookieJar(storage: SecureCookieStorage(), ignoreExpires: false) {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      contentType: Headers.jsonContentType,
      // Tự xử lý status >= 400 trong onError
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ));
    dio.interceptors
      ..add(CookieManager(this.cookieJar))
      ..add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  late final Dio dio;
  final CookieJar cookieJar;

  /// Tăng mỗi khi phiên đổi (login/logout/refresh). Response của phiên cũ bị bỏ.
  int generation = 0;
  Future<void>? _refreshing;
  ApiError? _lastRefreshError;

  /// Session gắn callback này để về màn Login khi refresh thất bại.
  void Function()? onSessionExpired;

  // ---------------------------------------------------------------- public API

  Future<dynamic> get(
    String path, {
    Map<String, Object?>? query,
    CancelToken? cancel,
    Duration? timeout,
  }) =>
      _send(() => dio.get<dynamic>(
            path,
            queryParameters: _clean(query),
            cancelToken: cancel,
            options: timeout == null ? null : Options(receiveTimeout: timeout),
          ));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancel,
    Duration? timeout,
  }) =>
      _send(() => dio.post<dynamic>(
            path,
            data: body,
            cancelToken: cancel,
            options: Options(receiveTimeout: timeout, headers: headers),
          ));

  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers, CancelToken? cancel}) =>
      _send(() => dio.put<dynamic>(path, data: body, cancelToken: cancel, options: Options(headers: headers)));

  Future<dynamic> patch(String path, {Object? body, Map<String, String>? headers}) =>
      _send(() => dio.patch<dynamic>(path, data: body, options: Options(headers: headers)));

  Future<dynamic> delete(String path, {Object? body, Map<String, Object?>? query}) =>
      _send(() => dio.delete<dynamic>(path, data: body, queryParameters: _clean(query)));

  /// Xoá cookie phía app (logout / hết phiên).
  Future<void> clearCookies() => cookieJar.deleteAll();

  // ---------------------------------------------------------------- internals

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      throw _normalize(e);
    }
  }

  /// Bỏ giá trị null khỏi query (giống paramsSerializer bên RN).
  Map<String, Object?>? _clean(Map<String, Object?>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null));

  ApiError _normalize(DioException e) {
    if (e.error is ApiError) return e.error as ApiError;
    if (e.type == DioExceptionType.cancel) {
      return ApiError(status: 0, code: 'REQUEST_CANCELLED', message: 'Cancelled');
    }
    final res = e.response;
    if (res == null) return ApiError.network();
    return ApiError.fromJson(res.statusCode, res.data);
  }

  /// Route có RequestOriginGuard ở backend: mutation bắt buộc header Origin nằm trong CORS_ORIGINS.
  static final _originRequired = RegExp(
    r'^(manager/|mentor/classes/).*materials(?:/|$)'
    r'|/files/[^/]+/access$'
    r'|^notifications(?:/|$)'
    r'|^chat/'
    r'|^mentor/(class-sessions|classes|assignments)/.*assignments'
    r'|^mentor/assignments/'
    r'|^me/.*assignments',
  );
  static final _refreshPath = RegExp(r'(?:^|/)auth/refresh/?$');

  Future<void> _onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    final net = await Connectivity().checkConnectivity();
    if (net.isNotEmpty && net.every((r) => r == ConnectivityResult.none)) {
      return h.reject(DioException(requestOptions: o, error: ApiError.network()));
    }
    o.extra['gen'] ??= generation;

    // Mutation: gửi Origin (app mobile không tự có như trình duyệt). Route có guard thì bắt buộc.
    final path = o.path.replaceFirst(RegExp(r'^/'), '');
    final isMutation = !['GET', 'HEAD', 'OPTIONS'].contains(o.method.toUpperCase());
    if (isMutation) {
      if (Env.appOrigin.isNotEmpty) {
        o.headers['Origin'] = Env.appOrigin;
      } else if (_originRequired.hasMatch(path)) {
        return h.reject(DioException(
          requestOptions: o,
          error: ApiError(status: 0, code: 'APP_ORIGIN_REQUIRED', message: 'APP_ORIGIN is required'),
        ));
      }
    }
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final err = _normalize(e);
    final o = e.requestOptions;
    final isRefresh = _refreshPath.hasMatch(o.path);
    if (!err.isAuthRequired || isRefresh) {
      return h.next(e.copyWith(error: err));
    }
    if (o.extra['retried'] == true) {
      _expire();
      return h.next(e.copyWith(error: err));
    }
    o.extra['retried'] = true;

    try {
      if (o.extra['gen'] == generation) {
        _refreshing ??= _refresh();
        await _refreshing;
      } else if (_lastRefreshError != null) {
        throw _lastRefreshError!;
      }
      o.extra['gen'] = generation;
      final res = await dio.fetch<dynamic>(o);
      h.resolve(res);
    } on ApiError catch (refreshError) {
      h.next(e.copyWith(error: refreshError));
    } on DioException catch (retryError) {
      h.next(retryError.copyWith(error: _normalize(retryError)));
    }
  }

  Future<void> _refresh() async {
    try {
      await dio.post<dynamic>('auth/refresh');
      _lastRefreshError = null;
      generation++;
    } on DioException catch (e) {
      _lastRefreshError = _normalize(e);
      generation++;
      _expire();
      throw _lastRefreshError!;
    } finally {
      _refreshing = null;
    }
  }

  void _expire() {
    unawaited(clearCookies());
    onSessionExpired?.call();
  }
}
