import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_controller.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';

import '../tool/preview/attendance_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
  void change() => state = SessionState(ready: true, epoch: state.epoch + 1);
}

void main() {
  setUp(initTimeZones);
  final id = sampleSchedule;
  Future<({ProviderContainer container, AttendanceController controller, void Function() close})> setup(
    MemoryAttendanceApi api,
  ) async {
    final sessionId = id().entries.first.session.id;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorClockProvider.overrideWithValue(() => previewNow),
        mentorAttendanceApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(attendanceEditorProvider(sessionId), (_, _) {});
    addTearDown(subscription.close);
    await container.read(attendanceEditorProvider(sessionId).future);
    return (
      container: container,
      controller: container.read(attendanceEditorProvider(sessionId).notifier),
      close: subscription.close,
    );
  }

  AttendanceEditorState editor(ProviderContainer container) =>
      container.read(attendanceEditorProvider(id().entries.first.session.id)).value!;

  test('205 dòng: mất response batch 2 sau commit, retry đúng key/body/version rồi tiếp tục batch 3', () async {
    final api = MemoryAttendanceApi(studentCount: 205)..loseResponseAtCommit = 2;
    final scope = await setup(api);
    for (final row in editor(scope.container).roster.records) {
      scope.controller.setStatus(row, AttendanceStatus.PRESENT);
    }
    expect(await scope.controller.save(), isFalse);
    expect(editor(scope.container).retryPending, isTrue);
    final before = editor(scope.container).draft;
    scope.controller.setStatus(editor(scope.container).roster.records.last, AttendanceStatus.ABSENT);
    expect(editor(scope.container).draft, before);
    expect(await scope.controller.retry(), isTrue);
    expect(api.calls.map((item) => item.call.body['expectedVersion']), [2, 3, 3, 4]);
    expect(api.calls[1].call.key, api.calls[2].call.key);
    expect(api.calls[1].call.body, api.calls[2].call.body);
    expect(api.committedWrites, 3);
    expect(editor(scope.container).draft, isEmpty);
    expect(editor(scope.container).roster.records.every((row) => row.status == AttendanceStatus.PRESENT), isTrue);
  });

  test('409 tải roster mới, giữ bản nháp và bắt xem lại trước lệnh mới', () async {
    final api = MemoryAttendanceApi(studentCount: 2)..conflictNextWrite = true;
    final scope = await setup(api);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    expect(await scope.controller.save(), isFalse);
    expect(editor(scope.container).roster.header.session.version, 3);
    expect(editor(scope.container).conflict, isTrue);
    expect(await scope.controller.save(), isFalse);
    expect(api.calls, hasLength(1));
    scope.controller.reviewDraft();
    expect(await scope.controller.save(), isTrue);
    expect(api.calls.last.call.key, isNot(api.calls.first.call.key));
    expect(api.calls.last.call.body['expectedVersion'], 3);
  });

  test('Ghi đã ack nhưng reload lỗi: retry chỉ GET, không gửi lại lệnh ghi', () async {
    final api = MemoryAttendanceApi(studentCount: 2);
    final scope = await setup(api);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    api.failReads = 1;
    expect(await scope.controller.save(), isFalse);
    expect(editor(scope.container).reloadRequired, isTrue);
    expect(await scope.controller.retry(), isTrue);
    expect(api.calls, hasLength(1));
    expect(api.readCount, 3);
  });

  test('Start tạo snapshot, finalize đổi UNMARKED thành ABSENT, vẫn sửa trong hạn', () async {
    final api = MemoryAttendanceApi(studentCount: 2, status: TeachingStatus.SCHEDULED);
    final scope = await setup(api);
    expect(editor(scope.container).roster.records, isEmpty);
    expect(await scope.controller.start(), isTrue);
    expect(editor(scope.container).roster.records, hasLength(2));
    expect(await scope.controller.finalize(), isTrue);
    expect(editor(scope.container).roster.records.every((row) => row.status == AttendanceStatus.ABSENT), isTrue);
    expect(editor(scope.container).editableAt(previewNow), isTrue);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    expect(await scope.controller.save(), isTrue);
    expect(editor(scope.container).roster.header.session.status, TeachingStatus.COMPLETED);
  });

  test('Hết hạn không ghi; bản nháp chưa lưu không bị bulk/finalize ghi đè', () async {
    final api = MemoryAttendanceApi(studentCount: 2, expired: true);
    final scope = await setup(api);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    expect(editor(scope.container).draft, isEmpty);
    expect(await scope.controller.bulkPresent(), isFalse);
    expect(api.calls, isEmpty);
    api.expired = false;
    await scope.controller.reload();
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    expect(await scope.controller.bulkPresent(), isFalse);
    expect(await scope.controller.finalize(), isFalse);
    expect(api.calls, isEmpty);
  });

  test('Khóa bấm lặp trong lúc gửi và bỏ response khi đã đổi phiên', () async {
    final api = MemoryAttendanceApi(studentCount: 2);
    final scope = await setup(api);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    final release = Completer<void>();
    api.delayNextWrite = release;
    final pending = scope.controller.save();
    expect(await scope.controller.save(), isFalse);
    expect(api.calls, hasLength(1));
    (scope.container.read(sessionProvider.notifier) as _Session).change();
    await scope.container.read(attendanceEditorProvider(id().entries.first.session.id).future);
    release.complete();
    expect(await pending, isFalse);
    expect(editor(scope.container).draft, isEmpty);
    expect(editor(scope.container).retryPending, isFalse);
  });

  test('Đóng sheet khi mất response vẫn giữ key trong RAM để mở lại và retry', () async {
    final api = MemoryAttendanceApi(studentCount: 2)..loseResponseAtCommit = 1;
    final scope = await setup(api);
    scope.controller.setStatus(editor(scope.container).roster.records.first, AttendanceStatus.PRESENT);
    expect(await scope.controller.save(), isFalse);
    final key = api.calls.single.call.key;
    scope.close();
    await scope.container.pump();
    final subscription = scope.container.listen(attendanceEditorProvider(id().entries.first.session.id), (_, _) {});
    addTearDown(subscription.close);
    expect(editor(scope.container).retryPending, isTrue);
    expect(
      await scope.container.read(attendanceEditorProvider(id().entries.first.session.id).notifier).retry(),
      isTrue,
    );
    expect(api.calls.last.call.key, key);
    expect(api.committedWrites, 1);
  });

  test('Đúng tại editableUntil thì hết hạn theo thời gian server ước lượng', () async {
    final scope = await setup(MemoryAttendanceApi(studentCount: 2));
    final current = editor(scope.container);
    final deadline = current.roster.header.session.editableUntil!;
    expect(current.editableAt(deadline.subtract(const Duration(milliseconds: 1))), isTrue);
    expect(current.editableAt(deadline), isFalse);
  });
}
