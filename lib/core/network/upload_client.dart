import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_error.dart';
import 'file_models.dart';

final uploadClientProvider = Provider((ref) => UploadClient());

/// PUT object storage tách hoàn toàn khỏi API/cookie/Origin. Không theo redirect
/// để tránh gửi URL ký hoặc header sang host khác; mỗi lần thử mở stream mới.
class UploadClient {
  UploadClient()
    : dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(seconds: 30),
          followRedirects: false,
          responseType: ResponseType.plain,
        ),
      );
  final Dio dio;
  Future<void> put(
    FileUploadIntent intent,
    Stream<List<int>> bytes,
    int size, {
    required CancelToken cancel,
    required void Function(int, int) onProgress,
  }) async {
    try {
      await dio.putUri<void>(
        intent.url,
        data: bytes,
        cancelToken: cancel,
        onSendProgress: onProgress,
        options: Options(
          headers: {...intent.headers, Headers.contentLengthHeader: size},
          contentType: intent.headers.entries.where((e) => e.key.toLowerCase() == 'content-type').firstOrNull?.value,
        ),
      );
    } on DioException catch (error) {
      // Không giữ DioException/requestOptions chứa signed URL trong state/log hỗ trợ.
      throw ApiError(
        status: error.response?.statusCode ?? 0,
        code: CancelToken.isCancel(error)
            ? 'UPLOAD_CANCELLED'
            : error.response?.statusCode == 403
            ? 'UPLOAD_URL_EXPIRED'
            : 'UPLOAD_TRANSFER_FAILED',
      );
    }
  }
}
