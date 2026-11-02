import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/files_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_controller.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import '../tool/preview/classes_fixtures.dart';
import '../tool/preview/materials_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';

class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
    ready: true,
    epoch: 1,
    user: SessionUser(
      id: previewMentor.id,
      displayName: 'Mentor',
      email: 'mentor@example.test',
      phone: null,
      role: Role.MENTOR,
      createdAt: previewNow,
    ),
  );
  void change() => state = SessionState(ready: true, epoch: state.epoch + 1, user: state.user);
}

void main() {
  setUp(initTimeZones);
  Future<
    ({
      ProviderContainer scope,
      MentorUploadController controller,
      MemoryFilesApi files,
      MemoryUploadClient upload,
      MemoryMaterialsApi materials,
      void Function(MentorClassStatus) setClass,
      void Function() close,
    })
  >
  setup({MemoryFilesApi? files, MemoryUploadClient? upload, MemoryMaterialsApi? materials}) async {
    final f = files ?? MemoryFilesApi(), u = upload ?? MemoryUploadClient(), m = materials ?? MemoryMaterialsApi();
    var now = previewNow, status = MentorClassStatus.IN_PROGRESS;
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorPrimaryWorkspaceProvider.overrideWith((ref, id) async => sampleWorkspace(status: status)),
        mentorClassUnitsProvider.overrideWith((ref, id) async => sampleUnits()),
        mentorFilesApiProvider.overrideWithValue(f),
        uploadClientProvider.overrideWithValue(u),
        mentorMaterialsApiProvider.overrideWithValue(m),
        mentorClockProvider.overrideWithValue(() => now),
        uploadWaitProvider.overrideWithValue((duration, cancel) async {
          now = now.add(duration);
        }),
      ],
    );
    addTearDown(scope.dispose);
    final subscription = scope.listen(mentorUploadProvider(fixtureClassId), (_, _) {});
    return (
      scope: scope,
      controller: scope.read(mentorUploadProvider(fixtureClassId).notifier),
      files: f,
      upload: u,
      materials: m,
      setClass: (MentorClassStatus next) => status = next,
      close: subscription.close,
    );
  }

  PickedUploadFile file({void Function()? opened}) => PickedUploadFile(
    name: 'Bai hoc.pdf',
    size: 4,
    mimeType: 'application/pdf',
    openRead: () {
      opened?.call();
      return Stream.value([1, 2, 3, 4]);
    },
  );
  Future<bool> start(MentorUploadController c, {PickedUploadFile? selected}) =>
      c.start(file: selected ?? file(), unit: sampleUnits().single, title: 'Bài học');
  UploadState value(ProviderContainer scope) => scope.read(mentorUploadProvider(fixtureClassId));

  test('Upload → complete → poll READY → tạo nháp; không submit tự động', () async {
    final s = await setup();
    expect(await start(s.controller), isTrue);
    expect(s.files.intents, 1);
    expect(s.upload.puts, 1);
    expect(s.files.completes, 1);
    expect(s.files.reads, 1);
    expect(s.materials.creates, 1);
    expect(value(s.scope).step, UploadStep.done);
    expect(value(s.scope).material?.revision, 1);
    expect(s.upload.readBytes, 4);
  });
  test('PUT lỗi: retry cùng intent và mở stream mới, không đọc cả file vào RAM', () async {
    var opened = 0;
    final s = await setup(upload: MemoryUploadClient()..failNext = ApiError.network());
    expect(await start(s.controller, selected: file(opened: () => opened++)), isFalse);
    expect(await s.controller.retry(), isTrue);
    expect(opened, 2);
    expect(s.files.intents, 1);
    expect(s.upload.urls.first, s.upload.urls.last);
    expect(s.materials.creates, 1);
  });
  test('PUT hết hạn: người dùng retry mới xin intent mới', () async {
    final s = await setup(upload: MemoryUploadClient()..failNext = ApiError(status: 403, code: 'UPLOAD_URL_EXPIRED'));
    expect(await start(s.controller), isFalse);
    expect(s.files.intents, 1);
    expect(s.files.completes, 0);
    expect(await s.controller.retry(), isTrue);
    expect(s.files.intents, 2);
    expect(s.upload.urls.first, isNot(s.upload.urls.last));
  });
  test('Complete commit mất response: GET xác nhận trước, không complete lại', () async {
    final s = await setup(files: MemoryFilesApi()..loseCompleteResponse = true);
    expect(await start(s.controller), isTrue);
    expect(s.files.completes, 1);
    expect(s.files.events, ['intent', 'complete', 'status']);
    expect(s.materials.creates, 1);
  });
  test('GET sau complete lỗi: retry chỉ GET rồi tiếp tục tạo nháp', () async {
    final s = await setup(
      files: MemoryFilesApi()
        ..loseCompleteResponse = true
        ..failStatusReads = 1,
    );
    expect(await start(s.controller), isFalse);
    expect(await s.controller.retry(), isTrue);
    expect(s.upload.puts, 1);
    expect(s.files.completes, 1);
    expect(s.materials.creates, 1);
  });
  test('POST nháp commit mất response: retry chỉ tìm theo fileId, không tạo trùng', () async {
    final s = await setup(materials: MemoryMaterialsApi()..loseCreateResponse = true);
    expect(await start(s.controller), isFalse);
    expect(value(s.scope).requiresVerification, isTrue);
    expect(s.controller.reset(), isFalse);
    expect(await s.controller.retry(), isTrue);
    expect(s.materials.creates, 1);
    expect(s.materials.lists, 1);
    expect(s.materials.details, 1);
    expect(value(s.scope).requiresVerification, isFalse);
  });
  test('POST chưa rõ có tới server: nhiều lần kiểm tra không tìm thấy vẫn không POST lại', () async {
    final s = await setup(materials: MemoryMaterialsApi()..loseCreateBeforeCommit = true);
    expect(await start(s.controller), isFalse);
    expect(await s.controller.retry(), isFalse);
    expect(await s.controller.retry(), isFalse);
    expect(s.materials.creates, 1);
    expect((value(s.scope).error as ApiError).code, 'UPLOAD_DRAFT_UNCONFIRMED');
    expect(s.controller.reset(abandonUnconfirmed: true), isTrue);
  });
  test('PROCESSING tối đa 2 phút, retry đọc trạng thái, không PUT/complete lại', () async {
    final f = MemoryFilesApi()..neverReady = true;
    final s = await setup(files: f);
    expect(await start(s.controller), isFalse);
    expect(f.reads, 60);
    expect(s.materials.creates, 0);
    expect((value(s.scope).error as ApiError).code, 'UPLOAD_PROCESSING_TIMEOUT');
    f.neverReady = false;
    expect(await s.controller.retry(), isTrue);
    expect(s.upload.puts, 1);
    expect(f.completes, 1);
  });
  test('FAILED không tạo material và không retry cùng file hỏng', () async {
    final s = await setup(files: MemoryFilesApi()..failProcessing = true);
    expect(await start(s.controller), isFalse);
    expect(s.materials.creates, 0);
    expect(value(s.scope).canRetry, isFalse);
    expect(await s.controller.retry(), isFalse);
  });
  test('Lớp readonly chặn trước intent; cấp quyền mới được thử lại', () async {
    final s = await setup();
    s.setClass(MentorClassStatus.COMPLETED);
    expect(await start(s.controller), isFalse);
    expect(s.files.intents, 0);
    s.setClass(MentorClassStatus.IN_PROGRESS);
    expect(await s.controller.retry(), isTrue);
  });
  test('Lớp chuyển readonly khi worker xử lý: kiểm tra lại trước khi tạo nháp', () async {
    final f = MemoryFilesApi();
    final s = await setup(files: f);
    f.onStatus = () => s.setClass(MentorClassStatus.COMPLETED);
    expect(await start(s.controller), isFalse);
    expect(s.materials.creates, 0);
    expect(value(s.scope).requiresVerification, isFalse);
  });
  test('Đang PUT khóa bấm lặp; đóng/mở giữ flow; hủy không ghi nháp', () async {
    final u = MemoryUploadClient()..gate = Completer<void>();
    final s = await setup(upload: u);
    final job = start(s.controller);
    while (u.puts == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(await start(s.controller), isFalse);
    s.close();
    await s.scope.pump();
    expect(value(s.scope).busy, isTrue);
    await s.controller.cancel();
    expect(await job, isFalse);
    expect(s.materials.creates, 0);
    expect(value(s.scope).busy, isFalse);
  });
  test('Đổi phiên khi PUT chưa xong reset flow; callback cũ không tạo material', () async {
    final u = MemoryUploadClient()..gate = Completer<void>();
    final s = await setup(upload: u);
    final job = start(s.controller);
    while (u.puts == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    (s.scope.read(sessionProvider.notifier) as _Session).change();
    await s.scope.pump();
    expect(await job, isFalse);
    expect(value(s.scope).step, UploadStep.idle);
    expect(s.materials.creates, 0);
  });
}
