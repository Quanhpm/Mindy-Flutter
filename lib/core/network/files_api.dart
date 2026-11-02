import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'file_models.dart';
import 'json.dart';
import 'api_error.dart';

final filesApiProvider = Provider((ref) => FilesApi(ref.watch(apiClientProvider)));

class FilesApi {
  FilesApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_FILES_RESPONSE';
  Future<FileUploadIntent> intent({
    String? classId,
    String? unitId,
    required String courseUnitId,
    required String name,
    required String mimeType,
    required int size,
    required CancelToken cancel,
  }) async {
    if ((classId == null) != (unitId == null)) {
      throw ApiError(status: 422, code: 'UPLOAD_FILE_INVALID');
    }
    final body = <String, Object?>{
      'courseUnitId': courseUnitId,
      'originalFilename': name,
      'declaredMimeType': mimeType,
      'declaredSizeBytes': size,
    };
    if (classId != null && unitId != null) body.addAll({'classId': classId, 'classUnitId': unitId});
    final j = Json(await _api.post('files/upload-intents', body: body, cancel: cancel), errorCode);
    final intent = FileUploadIntent.fromJson(j);
    final contentTypes = intent.headers.entries.where((e) => e.key.toLowerCase() == 'content-type');
    if (contentTypes.length != 1 || contentTypes.single.value != mimeType) {
      j.fail();
    }
    return intent;
  }

  Future<FileUploadStatus> status(String id, {CancelToken? cancel}) async =>
      FileUploadStatus.fromJson(Json(await _api.get('files/$id', cancel: cancel), errorCode), id);
  Future<FileUploadStatus> complete(String id, {CancelToken? cancel}) async => FileUploadStatus.fromJson(
    Json(await _api.post('files/$id/complete', body: const <String, Object?>{}, cancel: cancel), errorCode),
    id,
  );
}
