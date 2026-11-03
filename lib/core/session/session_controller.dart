import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_api.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import 'session_user.dart';

/// Trạng thái phiên - thay `authSlice` (Zustand) + `useAuthSession` bên RN.
class SessionState {
  const SessionState({
    this.ready = false,
    this.user,
    this.epoch = 0,
    this.biometricEnabled = false,
    this.biometricRequired = false,
  });

  /// false = đang kiểm tra phiên lúc mở app (hiện splash).
  final bool ready;
  final SessionUser? user;

  /// Tăng mỗi lần đổi phiên. Provider dữ liệu riêng tư `watch` cái này
  /// nên tự reset cache khi logout / đổi user.
  final int epoch;
  final bool biometricEnabled;
  final bool biometricRequired;
}

/// Role được vào app ở bản hiện tại. ADMIN vẫn chưa có khu vực mobile.
const appRoles = {Role.STUDENT, Role.MENTOR, Role.MANAGER};

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Dùng trong provider dữ liệu riêng tư: `ref.watch(sessionEpochProvider);`
final sessionEpochProvider = Provider<int>(
  (ref) => ref.watch(sessionProvider.select((s) => s.epoch)),
);

class SessionController extends Notifier<SessionState> {
  static const _rememberKey = 'remember_login';
  static const _biometricKey = 'biometric_login_enabled';

  ApiClient get _api => ref.read(apiClientProvider);
  AuthApi get _auth => ref.read(authApiProvider);

  @override
  SessionState build() {
    _api.onSessionExpired = expire;
    Future.microtask(_bootstrap);
    return const SessionState();
  }

  void _accept(SessionUser? user) {
    _api.sessionEpoch++;
    state = SessionState(
      ready: true,
      user: user,
      epoch: state.epoch + 1,
      biometricEnabled: state.biometricEnabled,
    );
  }

  /// Mở app: GET auth/me. Lỗi thì vẫn cho vào màn Login (không chặn vô hạn).
  /// Lần trước bỏ "Ghi nhớ đăng nhập" -> xoá cookie, bắt đăng nhập lại.
  Future<void> _bootstrap() async {
    final epoch = _api.sessionEpoch;
    final prefs = await SharedPreferences.getInstance();
    if (_api.sessionEpoch != epoch) return;
    if (prefs.getBool(_rememberKey) == false) {
      await prefs.setBool(_biometricKey, false);
      await _api.clearCookies();
      _accept(null);
      return;
    }
    if (prefs.getBool(_biometricKey) == true) {
      // Keep the secure session cookie, but don't restore the user until the
      // operating system's biometric prompt succeeds.
      state = SessionState(
        ready: true,
        epoch: state.epoch,
        biometricEnabled: true,
        biometricRequired: true,
      );
      return;
    }
    try {
      final user = await _auth.me();
      if (_api.sessionEpoch == epoch) _accept(user);
    } catch (_) {
      if (!state.ready) _accept(null);
    }
  }

  /// Chỉ role trong [appRoles] được vào. Role khác: logout và báo sai thông tin (giống RN).
  /// [remember] = false: phiên chỉ giữ tới khi tắt app.
  Future<void> login(
    String email,
    String password, {
    bool remember = true,
  }) async {
    final epoch = _api.sessionEpoch;
    final user = await _auth.login(email, password);
    if (_api.sessionEpoch != epoch) {
      throw ApiError(
        status: 401,
        code: 'SESSION_CHANGED',
        message: 'Session changed',
      );
    }
    if (!appRoles.contains(user.role)) {
      await _auth.logout();
      throw ApiError(
        status: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid credentials',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (_api.sessionEpoch != epoch) {
      throw ApiError(
        status: 401,
        code: 'SESSION_CHANGED',
        message: 'Session changed',
      );
    }
    await prefs.setBool(_rememberKey, remember);
    if (!remember) {
      await prefs.setBool(_biometricKey, false);
      state = SessionState(
        ready: state.ready,
        epoch: state.epoch,
        user: state.user,
      );
    }
    if (_api.sessionEpoch != epoch) {
      throw ApiError(
        status: 401,
        code: 'SESSION_CHANGED',
        message: 'Session changed',
      );
    }
    _accept(user);
  }

  /// Gate the securely stored session cookie with device biometrics. Passwords
  /// are never persisted.
  Future<bool> setBiometricLogin(bool enabled, {required String reason}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      if (prefs.getBool(_rememberKey) == false) return false;
      final auth = LocalAuthentication();
      if ((await auth.getAvailableBiometrics()).isEmpty) return false;
      final passed = await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!passed) return false;
    }
    await prefs.setBool(_biometricKey, enabled);
    state = SessionState(
      ready: state.ready,
      user: state.user,
      epoch: state.epoch,
      biometricEnabled: enabled,
      biometricRequired: state.biometricRequired,
    );
    return true;
  }

  /// Verifies locally, then validates the stored cookie with the existing
  /// auth/me endpoint before restoring the session.
  Future<bool> biometricLogin({required String reason}) async {
    if (!state.biometricRequired) return false;
    final auth = LocalAuthentication();
    if ((await auth.getAvailableBiometrics()).isEmpty) return false;
    final passed = await auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!passed) return false;
    final epoch = _api.sessionEpoch;
    final user = await _auth.me();
    if (_api.sessionEpoch != epoch) {
      throw ApiError(
        status: 401,
        code: 'SESSION_CHANGED',
        message: 'Session changed',
      );
    }
    if (!appRoles.contains(user.role)) {
      throw ApiError(
        status: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid credentials',
      );
    }
    _accept(user);
    return true;
  }

  /// Logout lỗi mạng thì ném lỗi để màn hình báo, KHÔNG giả vờ thành công.
  Future<void> logout({bool all = false}) async {
    await _auth.logout(all: all);
    await _api.clearCookies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, false);
    state = SessionState(
      ready: state.ready,
      epoch: state.epoch,
      user: state.user,
    );
    _accept(null);
  }

  /// Refresh thất bại -> về Login.
  void expire() {
    if (state.user != null || !state.ready) {
      final biometricEnabled = state.biometricEnabled;
      _accept(null);
      if (biometricEnabled) {
        state = SessionState(
          ready: true,
          epoch: state.epoch,
          biometricEnabled: true,
          biometricRequired: true,
        );
      }
    }
  }

  /// Tải lại thông tin user hiện tại (ví dụ pull to refresh).
  Future<void> reload() async {
    final epoch = _api.sessionEpoch;
    try {
      final user = await _auth.me();
      if (_api.sessionEpoch == epoch) _accept(user);
    } catch (_) {
      // Giữ phiên hiện tại nếu reload lỗi mạng
    }
  }
}
