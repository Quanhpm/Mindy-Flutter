import 'dart:convert';
import 'dart:io';

// Chỉ in tên field lỗi, không in URL/nội dung cấu hình.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tool/validate_release.dart <production-config.json>');
    exitCode = 64;
    return;
  }
  try {
    final data = jsonDecode(File(args.single).readAsStringSync());
    if (data is! Map<String, dynamic>) throw const FormatException('JSON object required');
    if (data['APP_ENV'] != 'production') throw const FormatException('APP_ENV must be production');
    for (final field in ['API_URL', 'APP_ORIGIN']) {
      final value = data[field];
      final uri = value is String ? Uri.tryParse(value.trim()) : null;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (field == 'APP_ORIGIN' && uri.path != '' && uri.path != '/')) {
        throw FormatException('$field must be a valid HTTPS ${field == 'APP_ORIGIN' ? 'origin' : 'URL'}');
      }
    }
    if (data['DEBUG_MODE'] != null && data['DEBUG_MODE'] != false && data['DEBUG_MODE'] != 'false') {
      throw const FormatException('DEBUG_MODE must be false');
    }
    stdout.writeln('Production configuration is valid. Confirm backend CORS and signing separately.');
  } on FormatException catch (e) {
    stderr.writeln('Release configuration: ${e.message}');
    exitCode = 65;
  } on FileSystemException {
    stderr.writeln('Could not read release configuration file.');
    exitCode = 66;
  }
}
