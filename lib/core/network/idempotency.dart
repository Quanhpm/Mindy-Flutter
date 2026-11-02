import 'package:uuid/uuid.dart';

/// Một thao tác người dùng cho API bắt buộc `Idempotency-Key` (điểm danh, gán mentor...).
///
/// Quy tắc (API_CONTRACT attendance.md §19):
/// - Mỗi lần người dùng bấm = 1 [IdempotentCall] mới (key mới).
/// - Retry vì lỗi mạng/timeout = dùng LẠI đúng object này (cùng key + cùng body).
/// - Gặp 409 SESSION_VERSION_CONFLICT: tải lại dữ liệu, tạo call mới với version mới.
///
///   final call = IdempotentCall({'expectedVersion': v, 'records': changed});
///   await api.put('class-sessions/$id/attendance', body: call.body, headers: call.headers);
class IdempotentCall {
  IdempotentCall(Map<String, Object?> body, {String? key}) : body = _freezeMap(body), key = key ?? const Uuid().v4();

  final String key;
  final Map<String, Object?> body;

  Map<String, String> get headers => {'Idempotency-Key': key};

  /// Snapshot sâu: sửa form sau lỗi mạng không được làm đổi payload của key cũ.
  static Map<String, Object?> _freezeMap(Map<String, Object?> value) =>
      Map.unmodifiable(value.map((key, value) => MapEntry(key, _freeze(value))));
  static Object? _freeze(Object? value) {
    if (value is Map<String, Object?>) return _freezeMap(value);
    if (value is List<Object?>) return List<Object?>.unmodifiable(value.map(_freeze));
    if (value == null || value is String || value is bool || (value is num && value.isFinite)) return value;
    throw ArgumentError('IdempotentCall chỉ nhận giá trị JSON hợp lệ');
  }
}
