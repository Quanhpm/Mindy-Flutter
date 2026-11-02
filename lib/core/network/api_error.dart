/// Lỗi chuẩn hoá từ backend: `{ statusCode, code, message, details?, requestId? }`.
/// Xử lý theo [status] + [code], KHÔNG so sánh [message].
class ApiError implements Exception {
  ApiError({
    required this.status,
    required this.code,
    this.message = '',
    this.requestId,
  });

  final int status;
  final String code;
  final String message;
  final String? requestId;

  bool get isNetwork => code == 'NETWORK_ERROR';
  bool get isAuthRequired => status == 401 && code == 'AUTHENTICATION_REQUIRED';

  /// Response sai schema (thay cho các hàm invalidXxxResponse bên RN).
  factory ApiError.invalidResponse([String code = 'INVALID_RESPONSE']) =>
      ApiError(status: 502, code: code, message: 'Invalid response');

  factory ApiError.network() =>
      ApiError(status: 0, code: 'NETWORK_ERROR', message: 'Network unavailable');

  factory ApiError.fromJson(int? httpStatus, Object? body) {
    if (body is Map) {
      final code = body['code'];
      final status = body['statusCode'];
      if (code is String && status is int) {
        final msg = body['message'];
        return ApiError(
          status: httpStatus ?? status,
          code: code,
          message: msg is List ? msg.join(', ') : '$msg',
          requestId: body['requestId'] is String ? body['requestId'] as String : null,
        );
      }
    }
    return ApiError(
      status: httpStatus ?? 0,
      code: httpStatus == null ? 'NETWORK_ERROR' : 'HTTP_ERROR',
      message: 'Request failed',
    );
  }

  @override
  String toString() => 'ApiError($status, $code)';
}
