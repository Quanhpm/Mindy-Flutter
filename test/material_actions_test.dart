import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/materials/material_actions.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
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
  Future<({ProviderContainer scope, MaterialActions actions, MemoryMaterialsApi api})> setup({
    MemoryMaterialsApi? api,
    bool readonly = false,
  }) async {
    final m = api ?? sampleMaterialsApi();
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorPrimaryWorkspaceProvider.overrideWith(
          (ref, id) async =>
              sampleWorkspace(status: readonly ? MentorClassStatus.COMPLETED : MentorClassStatus.IN_PROGRESS),
        ),
        mentorClassUnitsProvider.overrideWith((ref, id) async => sampleUnits()),
        mentorMaterialsApiProvider.overrideWithValue(m),
      ],
    );
    addTearDown(scope.dispose);
    final sub = scope.listen(materialActionsProvider(fixtureClassId), (_, _) {});
    addTearDown(sub.close);
    return (scope: scope, actions: scope.read(materialActionsProvider(fixtureClassId).notifier), api: m);
  }

  MaterialActionState value(ProviderContainer scope) => scope.read(materialActionsProvider(fixtureClassId));
  test('Edit tăng revision, REJECTED về DRAFT rồi mới được submit, không tự gửi sau sửa', () async {
    final s = await setup(),
        rejected = s.api.rows.firstWhere((r) => r.material.reviewStatus == MaterialReviewStatus.REJECTED).material;
    expect(await s.actions.submit([rejected]), isFalse);
    expect(s.api.commands, isEmpty);
    expect(await s.actions.edit(rejected, title: 'Đã bổ sung đáp án', description: 'Đã sửa'), isTrue);
    final draft = s.api.rows.singleWhere((r) => r.material.id == rejected.id).material;
    expect(draft.reviewStatus, MaterialReviewStatus.DRAFT);
    expect(draft.revision, 2);
    expect(s.api.commands.map((c) => c.kind), ['edit']);
    expect(await s.actions.submit([draft]), isTrue);
    expect(s.api.commands.last.revision, 2);
  });
  test('Mất response PATCH sau commit: nút check chỉ GET, không tăng revision lần hai', () async {
    final s = await setup(api: sampleMaterialsApi()..loseCommandResponse = true), m = s.api.rows.first.material;
    expect(await s.actions.edit(m, title: 'Tên mới', description: null), isFalse);
    expect(value(s.scope).checkRequired, isTrue);
    expect(await s.actions.check(), isTrue);
    expect(s.api.commands, hasLength(1));
    expect(value(s.scope).changed, 1);
    expect(s.api.rows.first.material.revision, 2);
    expect(s.api.rows.first.material.description, isNull);
  });
  test('Mất response submit: xác nhận PENDING cùng revision, không POST lại', () async {
    final s = await setup(api: sampleMaterialsApi()..loseCommandResponse = true), m = s.api.rows.first.material;
    expect(await s.actions.submit([m]), isFalse);
    expect(await s.actions.check(), isTrue);
    expect(s.api.commands, hasLength(1));
    expect(s.api.rows.first.material.reviewStatus, MaterialReviewStatus.PENDING_REVIEW);
  });
  test('Mất response delete: chỉ coi 404 MATERIAL_NOT_FOUND là bằng chứng đã xóa', () async {
    final s = await setup(api: sampleMaterialsApi()..loseCommandResponse = true), m = s.api.rows.first.material;
    expect(await s.actions.delete(m), isFalse);
    expect(await s.actions.check(), isTrue);
    expect(s.api.commands, hasLength(1));
    expect(s.api.rows.where((r) => r.material.id == m.id), isEmpty);
  });
  test('Ack rồi reload lỗi: check chỉ đọc lại danh sách, không gửi lại mutation', () async {
    final s = await setup(api: sampleMaterialsApi()..failLists = 1), m = s.api.rows.first.material;
    expect(await s.actions.submit([m]), isFalse);
    expect(value(s.scope).reloadOnly, isTrue);
    expect(value(s.scope).changed, 1);
    expect(await s.actions.check(), isTrue);
    expect(s.api.commands, hasLength(1));
  });
  test('Bulk dừng ở lỗi, check không tự gửi phần còn lại; lần mới lấy DRAFT mới nhất', () async {
    final s = await setup(api: sampleMaterialsApi()..failCommandAt = 2),
        drafts = s.api.rows
            .where((r) => r.material.reviewStatus == MaterialReviewStatus.DRAFT)
            .map((r) => r.material)
            .toList();
    expect(await s.actions.submit(drafts), isFalse);
    expect(value(s.scope).changed, 1);
    expect(value(s.scope).total, 2);
    expect(s.api.commands, hasLength(2));
    expect(await s.actions.check(), isFalse);
    expect(s.api.commands, hasLength(2));
    expect(value(s.scope).checkRequired, isFalse);
    final remaining = s.api.rows
        .where((r) => r.material.reviewStatus == MaterialReviewStatus.DRAFT)
        .map((r) => r.material)
        .toList();
    expect(await s.actions.submit(remaining), isTrue);
    expect(s.api.commands, hasLength(3));
  });
  test('409 không retry; đọc lại, lần sửa mới dùng revision mới', () async {
    final s = await setup(), old = s.api.rows.first;
    s.api.rows[0] = MentorMaterialDetail(
      material: copyPreviewMaterial(old.material, revision: 2, title: 'Đã sửa ở máy khác'),
      html: old.html,
      inlineImages: old.inlineImages,
      attachments: old.attachments,
    );
    expect(await s.actions.edit(old.material, title: 'Bản cũ', description: null), isFalse);
    expect(value(s.scope).checkRequired, isFalse);
    expect(s.api.commands, hasLength(1));
    expect(await s.actions.edit(s.api.rows.first.material, title: 'Đã xem lại', description: null), isTrue);
    expect(s.api.commands.last.revision, 2);
  });
  test('Tài liệu bị xóa sau lệnh chưa rõ kết quả không khóa cả lớp mãi', () async {
    final s = await setup(api: sampleMaterialsApi()..failCommandAt = 1), m = s.api.rows.first.material;
    expect(await s.actions.submit([m]), isFalse);
    s.api.rows.removeWhere((r) => r.material.id == m.id);
    expect(await s.actions.check(), isFalse);
    expect(value(s.scope).locked, isFalse);
    expect(value(s.scope).changed, 0);
    expect(s.api.commands, hasLength(1));
  });
  test('Readonly và tài liệu đã duyệt bị chặn trước mutation', () async {
    final closed = await setup(readonly: true);
    expect(await closed.actions.submit([closed.api.rows.first.material]), isFalse);
    expect(closed.api.commands, isEmpty);
    final s = await setup(),
        approved = s.api.rows.firstWhere((r) => r.material.reviewStatus == MaterialReviewStatus.APPROVED).material;
    expect(await s.actions.delete(approved), isFalse);
    expect(s.api.commands, isEmpty);
  });
  test('Khóa bấm lặp và callback phiên cũ không cập nhật action state', () async {
    final gate = Completer<void>(), s = await setup(api: sampleMaterialsApi()..commandGate = Completer<void>());
    s.api.commandGate = gate;
    final m = s.api.rows.first.material, job = s.actions.submit([m]);
    while (s.api.commandCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(await s.actions.submit([m]), isFalse);
    (s.scope.read(sessionProvider.notifier) as _Session).change();
    await s.scope.pump();
    gate.complete();
    expect(await job, isFalse);
    expect(value(s.scope).changed, 0);
    expect(value(s.scope).busy, isFalse);
  });
}
