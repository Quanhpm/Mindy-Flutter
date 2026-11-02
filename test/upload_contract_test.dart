import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/file_models.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
import '../tool/preview/classes_fixtures.dart';

Map<String, Object?> intentJson([Map<String, Object?> changes = const {}]) => {
  'fileId': fixtureId(600),
  'uploadUrl': 'https://storage.example.test/object?signature=synthetic',
  'requiredHeaders': {'content-type': 'application/pdf'},
  'uploadUrlExpiresAt': '2026-11-02T07:10:00Z',
  'intentExpiresAt': '2026-11-02T08:00:00Z',
  ...changes,
};

class _UploadAdapter implements HttpClientAdapter {
  RequestOptions? request;
  int bytes = 0;
  int status = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    request = options;
    if (stream != null) {
      await for (final chunk in stream) {
        bytes += chunk.length;
      }
    }
    return ResponseBody.fromString('', status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Filename, extension, MIME và giới hạn đúng allowlist, gồm hidden file và 200 MiB video', () {
    expect(validateUploadFile('Lesson.PDF', 25 * 1024 * 1024).kind, FileKind.PDF);
    expect(validateUploadFile('Lesson.mp4', 200 * 1024 * 1024).kind, FileKind.VIDEO);
    for (final name in [
      '.pdf',
      'no-extension',
      'bad.exe',
      ' report.pdf',
      'report.pdf ',
      'a/b.pdf',
      'a\\b.pdf',
      'bad\u0000.pdf',
    ]) {
      expect(() => validateUploadFile(name, 10), throwsA(isA<ApiError>()), reason: name);
    }
    expect(() => validateUploadFile('a.pdf', 0), throwsA(isA<ApiError>()));
    expect(
      () => validateUploadFile('a.pdf', 25 * 1024 * 1024 + 1),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'UPLOAD_FILE_TOO_LARGE')),
    );
    expect(() => validateUploadFile('a.mp4', 1, category: UploadCategory.image), throwsA(isA<ApiError>()));
    expect(() => validateUploadFile('a.jpg', 1, declaredMimeType: 'application/pdf'), throwsA(isA<ApiError>()));
  });
  test('Intent từ chối credential/header injection, URI sai và expiry không hợp lệ', () {
    expect(FileUploadIntent.fromJson(Json(intentJson(), 'BAD')).headers, {'content-type': 'application/pdf'});
    for (final change in <Map<String, Object?>>[
      {
        'requiredHeaders': {'authorization': 'secret'},
      },
      {
        'requiredHeaders': {'Cookie': 'synthetic'},
      },
      {
        'requiredHeaders': {'Origin': 'https://example.test'},
      },
      {
        'requiredHeaders': {'content-type': 'application/pdf\r\nx-secret:bad'},
      },
      {
        'requiredHeaders': {'content-type': 1},
      },
      {'uploadUrl': 'https://user:password@example.test/object'},
      {'uploadUrl': 'javascript:bad'},
      {'uploadUrlExpiresAt': '2026-11-02T09:00:00Z'},
      {'uploadUrlExpiresAt': '2026-11-02T07:00:00'},
    ]) {
      expect(() => FileUploadIntent.fromJson(Json(intentJson(change), 'BAD')), throwsA(isA<ApiError>()));
    }
  });
  test('READY cần đủ metadata đã xác minh, status chưa xử lý giữ null', () {
    final pending = {
      'id': fixtureId(600),
      'courseUnitId': fixtureId(21),
      'originalFilename': 'a.pdf',
      'status': 'PENDING_UPLOAD',
      'declaredSizeBytes': 4,
      'sizeBytes': null,
      'mimeType': null,
      'kind': null,
      'intentExpiresAt': '2026-11-02T08:00:00Z',
      'readyAt': null,
      'metadataStatus': null,
      'errorCode': null,
    };
    expect(FileUploadStatus.fromJson(Json(pending, 'BAD'), fixtureId(600)).kind, isNull);
    expect(
      () => FileUploadStatus.fromJson(Json({...pending, 'status': 'READY'}, 'BAD'), fixtureId(600)),
      throwsA(isA<ApiError>()),
    );
    final ready = {
      ...pending,
      'status': 'READY',
      'sizeBytes': 4,
      'mimeType': 'application/pdf',
      'kind': 'PDF',
      'readyAt': '2026-11-02T07:00:00Z',
    };
    expect(FileUploadStatus.fromJson(Json(ready, 'BAD'), fixtureId(600)).kind, FileKind.PDF);
    expect(
      () => FileUploadStatus.fromJson(Json({...ready, 'sizeBytes': 3}, 'BAD'), fixtureId(600)),
      throwsA(isA<ApiError>()),
    );
  });
  test('PUT stream đúng bytes/header, không baseUrl/cookie/Origin và không theo redirect', () async {
    final client = UploadClient(), adapter = _UploadAdapter();
    client.dio.httpClientAdapter = adapter;
    await client.put(
      FileUploadIntent.fromJson(Json(intentJson(), 'BAD')),
      Stream.value([1, 2, 3, 4]),
      4,
      cancel: CancelToken(),
      onProgress: (_, _) {},
    );
    expect(adapter.bytes, 4);
    expect(adapter.request?.method, 'PUT');
    expect(adapter.request?.followRedirects, isFalse);
    expect(
      adapter.request?.headers.keys.map((k) => k.toLowerCase()),
      isNot(anyOf(contains('cookie'), contains('origin'), contains('authorization'))),
    );
    expect(adapter.request?.headers[Headers.contentLengthHeader], 4);
    expect(adapter.request?.headers[Headers.contentTypeHeader], 'application/pdf');
    expect(client.dio.options.baseUrl, isEmpty);
  });
  test('Lỗi PUT không giữ DioException chứa signed URL trong state/log', () async {
    final client = UploadClient(), adapter = _UploadAdapter()..status = 403;
    client.dio.httpClientAdapter = adapter;
    await expectLater(
      client.put(
        FileUploadIntent.fromJson(Json(intentJson(), 'BAD')),
        Stream.value([1]),
        1,
        cancel: CancelToken(),
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'UPLOAD_URL_EXPIRED')
            .having((e) => e.toString().contains('signature'), 'signed URL leaked', isFalse),
      ),
    );
  });
}
