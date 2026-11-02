import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_api.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import 'session_user.dart';

/// Trạng thái phiên - thay `authSlice` (Zustand) + `useAuthSession` bên RN.
class SessionState {
  const SessionState({this.ready = false, this.user, this.epoch = 0});

  /// false = đang kiểm tra phiên lúc mở app (hiện splash).
  final bool ready;
  final SessionUser? user;

  /// Tăng mỗi lần đổi phiên. Provider dữ liệu riêng tư `watch` cái này
  /// nên tự reset cache khi logout / đổi user.
  final int epoch;
}

/// Role được vào app ở bản hiện tại. MANAGER/ADMIN sẽ thêm khi có app Quản lý.
const appRoles = {Role.STUDENT, Role.MENTOR};

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Dùng trong provider dữ liệu riêng tư: `ref.watch(sessionEpochProvider);`
final sessionEpochProvider = Provider<int>((ref) => ref.watch(sessionProvider.select((s) => s.epoch)));

class SessionController extends Notifier<SessionState> {
  static const _rememberKey = 'remember_login';

  ApiClient get _api => ref.read(apiClientProvider);
  AuthApi get _auth => ref.read(authApiProvider);

  @override
  SessionState build() {
    _api.onSessionExpired = expire;
    Future.microtask(_bootstrap);
    return const SessionState();
  }

  void _accept(SessionUser? user) {
    _api.generation++;
    state = SessionState(ready: true, user: user, epoch: state.epoch + 1);
  }

  /// Mở app: GET auth/me. Lỗi thì vẫn cho vào màn Login (không chặn vô hạn).
  /// Lần trước bỏ "Ghi nhớ đăng nhập" -> xoá cookie, bắt đăng nhập lại.
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rememberKey) == false) {
      await _api.clearCookies();
      _accept(null);
      return;
    }
    final gen = _api.generation;
    try {
      final user = await _auth.me();
      if (_api.generation == gen) _accept(user);
    } catch (_) {
      if (!state.ready) _accept(null);
    }
  }

  /// Chỉ role trong [appRoles] được vào. Role khác: logout và báo sai thông tin (giống RN).
  /// [remember] = false: phiên chỉ giữ tới khi tắt app.
  Future<void> login(String email, String password, {bool remember = true}) async {
    final gen = _api.generation;
    final user = await _auth.login(email, password);
    if (_api.generation != gen) {
      throw ApiError(status: 401, code: 'SESSION_CHANGED', message: 'Session changed');
    }
    if (!appRoles.contains(user.role)) {
      await _auth.logout();
      throw ApiError(status: 401, code: 'INVALID_CREDENTIALS', message: 'Invalid credentials');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    _accept(user);
  }

  /// Logout lỗi mạng thì ném lỗi để màn hình báo, KHÔNG giả vờ thành công.
  Future<void> logout() async {
    await _auth.logout();
    await _api.clearCookies();
    _accept(null);
  }

  /// Refresh thất bại -> về Login.
  void expire() {
    if (state.user != null || !state.ready) _accept(null);
  }
}
