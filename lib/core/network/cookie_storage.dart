import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu cookie (access_token/refresh_token) vào Keychain/Keystore thay vì file
/// plaintext mặc định của PersistCookieJar. Cookie chỉ nằm ở tầng network.
class SecureCookieStorage implements Storage {
  static const _prefix = 'mindy_cookie_';
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }
}
