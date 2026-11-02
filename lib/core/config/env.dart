import 'dart:io' show Platform;

/// Biến môi trường, truyền khi build:
///   flutter run --dart-define-from-file=env/dev.json   (hoặc =.env)
///   flutter build apk --dart-define-from-file=env/prod.json
///
/// Không truyền gì (bấm Run trong Xcode/Android Studio) => bản development dùng giá trị
/// mặc định bên dưới = `.env` của dự án (server dev + APP_ORIGIN đã được owner xác nhận).
/// Tương đương `src/config/env.ts` bên RN.
class Env {
  Env._();

  static const _appEnv = String.fromEnvironment('APP_ENV');
  static const _apiUrl = String.fromEnvironment('API_URL');
  static const _appOrigin = String.fromEnvironment('APP_ORIGIN');
  static const _debugMode = String.fromEnvironment('DEBUG_MODE');

  // Mặc định development = .env của dự án
  static const _defaultDevApiUrl = 'https://api.quanh123.id.vn/api/v1';
  static const _defaultDevOrigin = 'http://localhost:3003';

  /// Origin gửi kèm mọi request ghi (phải nằm trong CORS_ORIGINS của backend).
  static String get appOrigin => _appOrigin.isNotEmpty || isProduction ? _appOrigin : _defaultDevOrigin;

  /// DEBUG_MODE=true: bật log/công cụ debug. Development mặc định bật.
  static bool get debugMode => _debugMode.isEmpty ? !isProduction : _debugMode == 'true';

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
