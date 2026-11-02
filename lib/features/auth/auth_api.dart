import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/json.dart';
import '../../core/session/session_user.dart';

final authApiProvider = Provider((ref) => AuthApi(ref.watch(apiClientProvider)));

/// `src/modules/auth/services/auth.service.ts`
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;
  static const _err = 'INVALID_AUTH_RESPONSE';

  Future<SessionUser> login(String email, String password) async {
    final res = await _api.post('auth/login', body: {'email': email, 'password': password});
    final j = Json(res, _err);
    j.dateTime('accessTokenExpiresAt');
    return SessionUser.fromJson(j.obj('user'));
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? phone,
  }) =>
      _api.post('auth/register', body: {
        'displayName': displayName,
        'email': email.trim(),
        'password': password,
        // Field rỗng thì bỏ hẳn, gửi field lạ backend trả 422
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

  Future<void> resend(String email) => _api.post('auth/email/resend', body: {'email': email});

  Future<SessionUser> me({CancelToken? cancel}) async =>
      SessionUser.fromJson(Json(await _api.get('auth/me', cancel: cancel), _err));

  Future<void> logout() => _api.post('auth/logout');
}
