import 'dart:io' show Platform;

/// Biến môi trường, truyền khi build:
///   flutter run --dart-define-from-file=env/dev.json
///   flutter build apk --dart-define-from-file=env/prod.json
///
/// Tương đương `src/config/env.ts` bên RN.
class Env {
  Env._();

  static const _appEnv = String.fromEnvironment('APP_ENV');
  static const _apiUrl = String.fromEnvironment('API_URL');
  static const appOrigin = String.fromEnvironment('APP_ORIGIN');

  static const _defaultDevApiUrl = 'http://localhost:3000/api/v1';

  static bool get isProduction =>
      _appEnv == 'production' ||
      (_appEnv.isEmpty && const bool.fromEnvironment('dart.vm.product'));

  /// Luôn kết thúc bằng `/` để Dio nối path tương đối (`auth/me`) đúng.
  static String get apiUrl {
    final raw = _apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (isProduction) {
      if (raw.isEmpty) {
        throw StateError('[env] API_URL is required when APP_ENV=production');
      }
      return '$raw/';
    }
    var url = raw.isEmpty ? _defaultDevApiUrl : raw;
    // Android emulator không gọi được localhost của máy host -> 10.0.2.2
    if (Platform.isAndroid) {
      url = url.replaceFirstMapped(
        RegExp(r'//(localhost|127\.0\.0\.1)(?=[:/]|$)'),
        (_) => '//10.0.2.2',
      );
    }
    return '$url/';
  }
}
