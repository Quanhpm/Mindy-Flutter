import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/file_models.dart';
import '../../../core/network/json.dart';

final mentorFilesApiProvider = Provider((ref) => MentorFilesApi(ref.watch(apiClientProvider)));

class MentorFilesApi {
  MentorFilesApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_FILES_RESPONSE';
  Future<FileUploadIntent> intent({
    required String classId,
    required String unitId,
    required String courseUnitId,
    required String name,
    required String mimeType,
    required int size,
    required CancelToken cancel,
  }) async {
    final j = Json(
      await _api.post(
        'files/upload-intents',
        body: {
          'classId': classId,
          'classUnitId': unitId,
          'courseUnitId': courseUnitId,
          'originalFilename': name,
          'declaredMimeType': mimeType,
          'declaredSizeBytes': size,
        },
        cancel: cancel,
      ),
      errorCode,
    );
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
