import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/features/mentor/materials/file_picker_service.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  late Directory folder;
  late File fixture;
  Object? response;
  MethodCall? request;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('mindy-picker-');
    fixture = File('${folder.path}/lesson.pdf');
    await fixture.writeAsBytes([1, 2, 3, 4]);
    response = [
      {'name': 'lesson.pdf', 'path': fixture.path, 'size': 999, 'bytes': null},
    ];
    request = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      request = call;
      return response;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await folder.delete(recursive: true);
  });
  test('Bridge native chọn một file, không withData, đo size thật và stream mở lại được', () async {
    final selected = await MentorFilePicker().pick(UploadCategory.document);
    expect(request?.method, 'custom');
    final args = request!.arguments as Map<Object?, Object?>;
    expect(args['allowMultipleSelection'], isFalse);
    expect(args['withData'], isFalse);
    expect(args['allowedExtensions'], contains('pdf'));
    expect(selected?.size, 4);
    expect(selected?.mimeType, 'application/pdf');
    expect(await selected!.openRead().expand((chunk) => chunk).toList(), [1, 2, 3, 4]);
    expect(await selected.openRead().expand((chunk) => chunk).toList(), [1, 2, 3, 4]);
  });
  test('Hủy picker trả null; loại không hợp lệ và file cache mất báo lỗi trước upload', () async {
    response = null;
    expect(await MentorFilePicker().pick(UploadCategory.document), isNull);
    response = [
      {'name': 'lesson.pdf', 'path': fixture.path, 'size': 4},
    ];
    await expectLater(
      MentorFilePicker().pick(UploadCategory.image),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'UPLOAD_FILE_UNSUPPORTED')),
    );
    await fixture.delete();
    await expectLater(
      MentorFilePicker().pick(UploadCategory.document),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'UPLOAD_FILE_UNAVAILABLE')),
    );
  });
}
