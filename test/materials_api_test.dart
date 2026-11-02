import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/config/env.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/file_models.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
import '../tool/preview/classes_fixtures.dart';
import '../tool/preview/materials_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';
import 'mentor_api_test.dart' show client, body;

Map<String, Object?> fileJson(BinaryFileSummary f) => {
  'id': f.id,
  'originalFilename': f.name,
  'mimeType': f.mimeType,
  'sizeBytes': f.size,
  'kind': f.kind.name,
};
Map<String, Object?> materialJson(MentorMaterialDetail detail) {
  final m = detail.material;
  return {
    'id': m.id,
    'courseUnitId': m.courseUnitId,
    'contentType': m.type.name,
    'title': m.title,
    'description': m.description,
    'sortOrder': 0,
    'availableAt': null,
    'sessionId': null,
    'createdBy': m.createdBy,
    'createdInClassId': m.classId,
    'revision': m.revision,
    'reviewStatus': m.reviewStatus.name,
    'approvedRevision': m.approvedRevision,
    'reviewedBy': m.firstApprovedAt == null ? null : previewPrimaryMentor.id,
    'reviewedAt': m.firstApprovedAt?.toIso8601String(),
    'firstApprovedAt': m.firstApprovedAt?.toIso8601String(),
    'rejectionReason': m.rejectionReason,
    'publishedAt': m.publishedAt?.toIso8601String(),
    'createdAt': m.createdAt.toIso8601String(),
    'updatedAt': m.updatedAt.toIso8601String(),
    'canEdit': m.canEdit,
    'file': m.file == null ? null : fileJson(m.file!),
    'contentHtml': detail.html,
    'contentSchemaVersion': detail.html == null ? null : 1,
    'inlineImages': detail.inlineImages.map(fileJson).toList(),
    'attachments': detail.attachments.map(fileJson).toList(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  test('Đọc hết trang, kiểm tra scope Course Unit và model không nhận VIDEO giả FILE', () async {
    final pages = <int>[];
    final api = MentorMaterialsApi(
      client((o) {
        final page = o.queryParameters['page']! as int;
        pages.add(page);
        return body({
          'items': [materialJson(sampleMaterial(page))],
          'page': page,
          'pageSize': 1,
          'total': 2,
        });
      }),
    );
    expect(await api.all(fixtureClassId, sampleUnits().single), hasLength(2));
    expect(pages, [1, 2]);
    final data = materialJson(sampleMaterial(1));
    await expectLater(
      MentorMaterialsApi(
        client(
          (_) => body({
            'items': [
              {...data, 'courseUnitId': fixtureId(99)},
            ],
            'page': 1,
            'pageSize': 100,
            'total': 1,
          }),
        ),
      ).all(fixtureClassId, sampleUnits().single),
      throwsA(isA<ApiError>()),
    );
    expect(() => MentorMaterial.fromJson(Json({...data, 'contentType': 'VIDEO'}, 'BAD')), throwsA(isA<ApiError>()));
    expect(
      () => MentorMaterialDetail.fromJson(
        Json({...data, 'contentType': 'ARTICLE', 'file': null, 'contentHtml': null, 'contentSchemaVersion': 1}, 'BAD'),
      ),
      throwsA(isA<ApiError>()),
    );
  });
  test('PATCH/submit/delete dùng revision và Origin; lỗi ghi 503 không tự retry', () async {
    final draft = sampleMaterial(1), calls = <RequestOptions>[];
    final api = MentorMaterialsApi(
      client((o) {
        calls.add(o);
        if (o.method == 'DELETE') {
          return body(null, 204);
        }
        if (o.method == 'PATCH') {
          return body({...materialJson(draft), 'revision': 2, 'title': 'Sửa'});
        }
        return body({...materialJson(draft), 'reviewStatus': 'PENDING_REVIEW', 'canEdit': false});
      }),
    );
    await api.patch(fixtureClassId, draft.material, title: 'Sửa', description: null);
    await api.submit(fixtureClassId, draft.material);
    await api.delete(fixtureClassId, draft.material);
    expect(calls.map((o) => o.method), ['PATCH', 'POST', 'DELETE']);
    for (final call in calls) {
      expect(call.headers['Origin'], Env.appOrigin);
    }
    expect((calls.first.data as Map<Object?, Object?>)['expectedRevision'], 1);
    expect(calls.last.queryParameters['expectedRevision'], 1);
    var failures = 0;
    await expectLater(
      MentorMaterialsApi(
        client((_) {
          failures++;
          return body({'statusCode': 503, 'code': 'FILE_STORAGE_UNAVAILABLE'}, 503);
        }),
      ).submit(fixtureClassId, draft.material),
      throwsA(isA<ApiError>()),
    );
    expect(failures, 1);
  });
  test('Access gắn material/file/revision đúng; chặn URI có credential và revision lệch', () async {
    final m = sampleMaterial(1).material, f = m.file!.id;
    final payload = {
      'materialId': m.id,
      'fileId': f,
      'revision': 1,
      'role': 'PRIMARY',
      'url': 'https://storage.example.test/file',
      'expiresAt': previewNow.add(const Duration(minutes: 1)).toIso8601String(),
    };
    RequestOptions? request;
    final access = await MentorMaterialsApi(
      client((o) {
        request = o;
        return body(payload);
      }),
    ).access(fixtureClassId, m, f);
    expect(access.role, MaterialFileRole.PRIMARY);
    expect(request?.queryParameters['expectedRevision'], 1);
    for (final change in <Map<String, Object?>>[
      {'revision': 2},
      {'fileId': fixtureId(99)},
      {'role': 'OTHER'},
      {'url': 'https://user:secret@storage.example.test/file'},
    ]) {
      await expectLater(
        MentorMaterialsApi(client((_) => body({...payload, ...change}))).access(fixtureClassId, m, f),
        throwsA(isA<ApiError>()),
      );
    }
  });
  test('Ảnh inline cũng là attachment được phép; không đồng nhất approved và published', () {
    final article = materialJson(sampleMaterial(1, article: true)),
        image = {
          'id': fixtureId(950),
          'originalFilename': 'a.png',
          'mimeType': 'image/png',
          'sizeBytes': 4,
          'kind': 'IMAGE',
        };
    final result = MentorMaterialDetail.fromJson(
      Json({
        ...article,
        'inlineImages': [image],
        'attachments': [image],
      }, 'BAD'),
    );
    expect(result.inlineImages.single.id, result.attachments.single.id);
    expect(sampleMaterial(1, status: MaterialReviewStatus.APPROVED).material.published, isFalse);
    expect(sampleMaterial(1, status: MaterialReviewStatus.APPROVED, published: true).material.published, isTrue);
  });
}
