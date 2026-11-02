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

  static const _bankName = String.fromEnvironment('DEV_BANK_NAME');
  static const _bankAccount = String.fromEnvironment('DEV_BANK_ACCOUNT');
  static const _bankOwner = String.fromEnvironment('DEV_BANK_OWNER');
  static ({String name, String account, String owner})? get developmentBank =>
      !isProduction && _bankName.isNotEmpty && _bankAccount.isNotEmpty && _bankOwner.isNotEmpty
      ? (name: _bankName, account: _bankAccount, owner: _bankOwner)
      : null;

  // Mặc định development = .env của dự án
  static const _defaultDevApiUrl = 'https://api.quanh123.id.vn/api/v1';
  static const _defaultDevOrigin = 'http://localhost:3003';

  /// Origin gửi kèm mọi request ghi (phải nằm trong CORS_ORIGINS của backend).
  static String get appOrigin {
    if (isProduction) return _productionUrl(_appOrigin, 'APP_ORIGIN', origin: true);
    return _appOrigin.trim().isNotEmpty ? _appOrigin.trim() : _defaultDevOrigin;
  }

  /// DEBUG_MODE=true: bật log/công cụ debug. Development mặc định bật.
  static bool get debugMode => !isProduction && (_debugMode.isEmpty || _debugMode == 'true');

  static bool get isProduction =>
      _appEnv == 'production' || (_appEnv.isEmpty && const bool.fromEnvironment('dart.vm.product'));

  static String _productionUrl(String value, String key, {bool origin = false}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (origin && uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError('[env] $key must be a valid HTTPS ${origin ? 'origin' : 'URL'} in production');
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  /// Fail-fast trước bootstrap thay vì lỗi cấu hình bị nuốt thành màn đăng nhập.
  static void validate() {
    apiUrl;
    appOrigin;
  }

  /// Luôn kết thúc bằng `/` để Dio nối path tương đối (`auth/me`) đúng.
  static String get apiUrl {
    final raw = _apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (isProduction) {
      return '${_productionUrl(raw, 'API_URL')}/';
    }
    var url = raw.isEmpty ? _defaultDevApiUrl : raw;
    // Android emulator không gọi được localhost của máy host -> 10.0.2.2
    if (Platform.isAndroid) {
      url = url.replaceFirstMapped(RegExp(r'//(localhost|127\.0\.0\.1)(?=[:/]|$)'), (_) => '//10.0.2.2');
    }
    return '$url/';
  }
}
