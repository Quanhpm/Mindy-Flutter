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
  IdempotentCall(this.body, {String? key}) : key = key ?? const Uuid().v4();

  final String key;
  final Map<String, Object?> body;

  Map<String, String> get headers => {'Idempotency-Key': key};
}
