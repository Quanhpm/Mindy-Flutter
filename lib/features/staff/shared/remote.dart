import '../../../core/network/api_error.dart';

/// Kết quả lỗi chung của các service RN (`{ kind: 'offline' | 'error' | 'denied' | 'notFound' | ... }`).
enum RemoteFailure {
  offline,
  error,
  denied,
  notFound,
  unavailable,
  conflict,
  invalid,
}

/// Lỗi đọc/ghi đã chuẩn hoá: [kind] + `requestId` (nếu backend trả).
class RemoteError implements Exception {
  const RemoteError(this.kind, {this.requestId, this.code, this.status});
  final RemoteFailure kind;
  final String? requestId;

  /// Mã lỗi backend (vd `SESSION_VERSION_CONFLICT`) để màn hình chọn thông báo.
  final String? code;
  final int? status;

  bool get offline => kind == RemoteFailure.offline;

  /// Map lỗi tầng mạng của Flutter sang kind RN, giống `ReadFailure` trong các service RN:
  /// mất mạng -> offline; 401/403 -> denied; 404 -> notFound; 409/412 -> conflict; 422/400 -> invalid; còn lại -> error.
  static RemoteError from(Object error) {
    if (error is RemoteError) return error;
    if (error is ApiError) {
      final kind = error.isNetwork
          ? RemoteFailure.offline
          : error.code == 'SESSION_CHANGED' ||
                error.status == 401 ||
                error.status == 403
          ? RemoteFailure.denied
          : error.status == 404
          ? RemoteFailure.notFound
          : error.status == 409 || error.status == 412
          ? RemoteFailure.conflict
          : error.status == 400 || error.status == 422
          ? RemoteFailure.invalid
          : RemoteFailure.error;
      return RemoteError(
        kind,
        requestId: error.requestId,
        code: error.code,
        status: error.status,
      );
    }
    return const RemoteError(RemoteFailure.error);
  }

  @override
  String toString() => 'RemoteError($kind, $code)';
}

/// UUID hợp lệ trước khi ghép vào URL (`resource()` của RN).
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String resourceId(String? value) {
  if (value == null || !_uuid.hasMatch(value)) {
    throw const RemoteError(RemoteFailure.error);
  }
  return Uri.encodeComponent(value);
}

bool isUuid(String? value) => value != null && _uuid.hasMatch(value);

/// Gộp theo id, giữ thứ tự xuất hiện đầu, phần tử sau ghi đè (Map của RN).
List<T> mergeById<T>(
  Iterable<T> first,
  Iterable<T> second,
  String Function(T) id,
) {
  final map = <String, T>{};
  for (final item in [...first, ...second]) {
    map[id(item)] = item;
  }
  return map.values.toList();
}
