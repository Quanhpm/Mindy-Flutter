import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/network/files_api.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/manager/manager_api.dart';
import 'package:mindy_flutter/features/manager/manager_models.dart';
import 'package:mindy_flutter/features/manager/manager_providers.dart';
import 'package:mindy_flutter/features/manager/leave/leave_api.dart';
import 'package:mindy_flutter/features/manager/leave/leave_providers.dart';
import 'package:mindy_flutter/features/manager/materials/materials_api.dart';
import 'package:mindy_flutter/features/manager/materials/materials_providers.dart';
import 'package:mindy_flutter/features/manager/materials/upload_controller.dart';
import 'package:mindy_flutter/features/manager/collections/collections_api.dart';
import 'package:mindy_flutter/features/manager/collections/collections_providers.dart';
import 'package:mindy_flutter/features/manager/collections/collections_models.dart';
import 'package:mindy_flutter/features/manager/operations/operations_api.dart';
import 'package:mindy_flutter/features/manager/operations/operations_models.dart';
import 'package:mindy_flutter/features/manager/operations/operations_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/preview/manager_fixtures.dart';
import '../tool/preview/materials_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  ({ProviderContainer scope, ManagerFixtureAdapter wire, ManagerApi api}) setup({ManagerFixtureAdapter? wire}) {
    final w = wire ?? ManagerFixtureAdapter(), client = managerFixtureClient(w);
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [apiClientProvider.overrideWithValue(client), sessionProvider.overrideWith(ManagerFixtureSession.new)],
    );
    addTearDown(() {
      scope.dispose();
      client.dio.close(force: true);
    });
    return (scope: scope, wire: w, api: scope.read(managerApiProvider));
  }

  test('Role redirect isolates Student, Mentor, Manager and unsupported Admin', () {
    for (final role in Role.values) {
      final u = SessionUser.fromJson(Json({...mgPerson('MANAGER'), 'role': role.name}));
      final s = SessionState(ready: true, epoch: 1, user: u);
      expect(redirectFor(s, Routes.login), switch (role) {
        Role.STUDENT => Routes.home,
        Role.MENTOR => Routes.mentor,
        Role.MANAGER => Routes.manager,
        Role.ADMIN => Routes.welcome,
      });
      if (role != Role.MANAGER) expect(redirectFor(s, Routes.managerMaterial(mgMaterial)), isNotNull);
      if (role == Role.MANAGER) {
        expect(redirectFor(s, Routes.manager), isNull);
        expect(redirectFor(s, Routes.mentor), Routes.manager);
      }
    }
  });
  test('Manager money accepts JS safe integer and rejects fractions, negative and overflow', () {
    expect(managerMoney(Json({'n': 9007199254740991}), 'n'), 9007199254740991);
    for (final n in [-1, 1.2, 9007199254740992, '100']) {
      expect(() => managerMoney(Json({'n': n}), 'n'), throwsA(isA<ApiError>()));
    }
  });
  test('Read every Manager API against contract fixture, including all conflict statuses', () async {
    final s = setup(),
        leave = ManagerLeaveApi(s.api),
        materials = ManagerMaterialsApi(s.api),
        cash = ManagerCollectionsApi(s.api),
        ops = ManagerOperationsApi(s.api);
    expect((await s.api.courses()).single.course.id, mgCourse);
    expect((await s.api.course(mgCourse)).units.single.id, mgUnit);
    expect((await s.api.people('MENTOR', '')).single.active, true);
    expect((await s.api.person('STUDENT', mgStudent)).id, mgStudent);
    expect((await s.api.classes()).single.id, mgClass);
    expect((await s.api.classDetail(mgClass)).activeStudents, 1);
    expect((await s.api.classUnits(mgClass)).single.number, 1);
    expect((await s.api.studentClasses(mgStudent)).single.orderId, mgOrder);
    expect((await s.api.mentorSchedule(mgMentor, DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 16))).zone, mgZone);
    expect(await leave.pendingCount(), 1);
    expect((await leave.list((status: null, mentorId: null))).single.mentorId, mgMentor);
    expect((await leave.detail(mgLeave)).conflictCount, 1);
    expect(await materials.count(MaterialReviewStatus.PENDING_REVIEW), 1);
    expect((await materials.list((unitId: mgUnit, status: null, type: null))).length, 2);
    expect((await materials.detail(mgMaterial)).detail.html, contains('<strong>'));
    expect(await cash.count(), 1);
    expect((await cash.list((status: null, code: '', classId: null))).single.amount, 1000000);
    expect((await cash.detail(mgOrder)).canConfirm, true);
    expect((await ops.timetable(mgClass)).sessions.single.id, mgSession);
    expect((await ops.candidates((id: mgClass, session: false))).affected, 1);
    expect((await ops.candidates((id: mgSession, session: true))).version, 2);
    expect((await ops.incomplete()).single.expired, true);
    expect((await ops.report(mgClass)).single.rate, 77.78);
    expect((await ops.audits(mgSession)).single.action, 'MARK');
    s.wire.conflictStatus = 'RESOLVED';
    expect((await ops.conflicts()).single.status, MakeupConflictStatus.RESOLVED);
    expect((await ops.makeupCandidates(mgConflict)).single.capacity, 3);
  });
  test('Malformed identity, zone, role and zero attendance denominator fail safely', () async {
    final s = setup();
    s.wire.readOverride = (o) => o.path == 'manager/mentors/$mgMentor' ? mgPerson('STUDENT') : null;
    await expectLater(s.api.person('MENTOR', mgMentor), throwsA(isA<ApiError>()));
    expect(() => s.api.people('ADMIN', ''), throwsA(isA<ApiError>()));
    s.wire.readOverride = (o) => o.path.endsWith('/schedule')
        ? s.wire.page(
            o,
            [],
            meta: {'from': o.queryParameters['from'], 'to': o.queryParameters['to'], 'timeZone': 'Invalid/Zone'},
          )
        : null;
    await expectLater(
      s.api.mentorSchedule(mgMentor, DateTime.utc(2026), DateTime.utc(2026, 1, 8)),
      throwsA(isA<ApiError>()),
    );
    final row = {
      'enrollmentId': mgId(31),
      'student': {'id': mgStudent, 'displayName': 'Student'},
      'present': 0,
      'absent': 0,
      'unmarked': 1,
      'excluded': 0,
      'makeupPending': 0,
      'finalizedEligibleCount': 0,
      'rate': null,
    };
    expect(ManagerAttendanceRow.fromJson(Json(row)).rate, isNull);
    expect(() => ManagerAttendanceRow.fromJson(Json({...row, 'rate': 101})), throwsA(isA<ApiError>()));
  });
  test('Pagination reads all pages and rejects changed totals and duplicate IDs', () async {
    final s = setup();
    s.wire.readOverride = (o) {
      if (o.path != 'manager/mentors') return null;
      final n = o.queryParameters['page'];
      return {
        'items': [mgPerson('MENTOR', id: mgId(n == 1 ? 2 : 20))],
        'page': n,
        'pageSize': 1,
        'total': 2,
      };
    };
    expect((await s.api.people('MENTOR', '')).length, 2);
    s.wire.readOverride = (o) => {
      'items': [mgPerson('MENTOR')],
      'page': o.queryParameters['page'],
      'pageSize': 1,
      'total': 2,
    };
    await expectLater(s.api.people('MENTOR', ''), throwsA(isA<ApiError>()));
    s.wire.readOverride = (o) => {
      'items': [mgPerson('MENTOR', id: mgId(o.queryParameters['page'] == 1 ? 2 : 20))],
      'page': o.queryParameters['page'],
      'pageSize': 1,
      'total': o.queryParameters['page'] == 1 ? 2 : 3,
    };
    await expectLater(s.api.people('MENTOR', ''), throwsA(isA<ApiError>()));
  });
  test('Assignment candidates reject changed version across pages', () async {
    final s = setup();
    s.wire.readOverride = (o) => s.wire.page(
      o,
      [],
      meta: {
        'items': [
          {'id': mgId(o.queryParameters['page'] == 1 ? 2 : 20), 'displayName': 'Mentor', 'isCurrent': false},
        ],
        'pageSize': 1,
        'total': 2,
        'classId': mgClass,
        'assignmentVersion': o.queryParameters['page'],
        'timeZone': mgZone,
        'asOf': mgNow,
        'affectedSessionCount': 1,
        'availabilityBasis': 'TEACHING_SCHEDULE_AND_APPROVED_LEAVE',
      },
    );
    await expectLater(
      ManagerOperationsApi(s.api).candidates((id: mgClass, session: false)),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 409)),
    );
  });
  test('Leave lost response replays exact receipt across closing/reopening screen', () async {
    final s = setup(), p = managerLeaveCommandProvider(mgLeave), detail = await ManagerLeaveApi(s.api).detail(mgLeave);
    var sub = s.scope.listen(p, (_, _) {});
    final c = s.scope.read(p.notifier);
    s.wire.loseNextWrite = true;
    expect(await c.decide(detail, approve: true, reason: '  Đã xem  ', acknowledge: true), isNull);
    expect(s.scope.read(p).retryPending, true);
    sub.close();
    await s.scope.pump();
    sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    expect((await s.scope.read(p.notifier).retry())?.request.version, 2);
    final writes = s.wire.requests.where((r) => r.method == 'POST').toList();
    expect(writes.length, 2);
    expect(writes[1].headers['Idempotency-Key'], writes[0].headers['Idempotency-Key']);
    expect(writes[1].body, writes[0].body);
    expect((writes[0].body! as Map)['reason'], 'Đã xem');
    expect(s.wire.leaveVersion, 2);
  });
  test('Leave requires conflict acknowledgement; 409 needs latest decision, no retry', () async {
    final s = setup(), p = managerLeaveCommandProvider(mgLeave), detail = await ManagerLeaveApi(s.api).detail(mgLeave);
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final c = s.scope.read(p.notifier);
    expect(() => c.decide(detail, approve: true, reason: 'OK', acknowledge: false), throwsA(isA<ApiError>()));
    s.wire.conflictNextPath = 'management/mentor-leave-requests/$mgLeave/approve';
    expect(await c.decide(detail, approve: true, reason: 'OK', acknowledge: true), isNull);
    expect(s.scope.read(p).conflict, true);
    expect(await c.retry(), isNull);
    expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
    await ManagerLeaveApi(s.api).detail(mgLeave);
    c.reviewed();
    expect(await c.decide(detail, approve: false, reason: 'Chưa phù hợp', acknowledge: false), isNotNull);
  });
  test('Assignment and makeup receipts preserve versions and do not double apply', () async {
    final s = setup(),
        target = (id: mgClass, session: false),
        p = managerAssignmentProvider((id: mgClass, session: false));
    final a = s.scope.listen(p, (_, _) {});
    addTearDown(a.close);
    s.wire.loseNextWrite = true;
    final c = s.scope.read(p.notifier);
    await c.assign(version: 3, mentorId: mgId(20), reason: 'Thay giảng viên');
    expect(s.scope.read(p).retryPending, true);
    expect((await c.retry())?.version, 4);
    expect(s.wire.classVersion, 4);
    expect((await ManagerOperationsApi(s.api).candidates(target)).version, 4);
    final mp = managerMakeupCommandProvider(mgConflict), sub = s.scope.listen(mp, (_, _) {});
    addTearDown(sub.close);
    final ops = ManagerOperationsApi(s.api),
        conflict = (await ops.conflicts()).single,
        candidate = (await ops.makeupCandidates(mgConflict)).single;
    s.wire.loseNextWrite = true;
    final mc = s.scope.read(mp.notifier);
    await mc.place(conflict, candidate, 'Đã kiểm nội dung');
    expect((await mc.retry())?.status, 'ASSIGNED');
    expect(s.wire.conflictVersion, 2);
    final assigned = (await ops.conflicts()).single;
    expect((await mc.cancel(assigned, 'Đổi lịch'))?.status, 'CANCELLED');
    expect(s.wire.conflictVersion, 3);
  });
  test('Material unknown cannot repeat write, must GET and adopt latest revision', () async {
    final s = setup(), p = managerMaterialCommandProvider((id: mgDraft, create: false));
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final c = s.scope.read(p.notifier);
    s.wire.loseNextWrite = true;
    await c.run('patch', {'expectedRevision': 1, 'title': 'Đã sửa'});
    expect(s.scope.read(p).retryPending, true);
    c.reviewed();
    expect(s.scope.read(p).retryPending, true);
    expect(await c.run('patch', {'expectedRevision': 1, 'title': 'Không gửi lại'}), isNull);
    expect((await c.readLatest())?.detail.material.revision, 2);
    c.reviewed();
    expect(
      (await c.run('patch', {'expectedRevision': 2, 'title': 'Lần sửa mới'}))?.snapshot?.detail.material.revision,
      3,
    );
    final writes = s.wire.requests.where((r) => r.method == 'PATCH').toList();
    expect(writes.length, 2);
    expect(writes.every((r) => !r.headers.containsKey('Idempotency-Key')), true);
  });
  test('Create unknown can reconcile owned inventory, rejects unrelated owner/unit', () async {
    final s = setup(), p = managerMaterialCommandProvider((id: mgUnit, create: true));
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final c = s.scope.read(p.notifier);
    s.wire.loseNextWrite = true;
    await c.run('create', {'contentType': 'ARTICLE', 'title': 'Bài mới', 'contentText': 'Nội dung'});
    expect(s.scope.read(p).retryPending, true);
    final api = ManagerMaterialsApi(s.api);
    await expectLater(c.adoptExisting(await api.detail(mgMaterial)), throwsA(isA<ApiError>()));
    await c.adoptExisting(await api.detail(mgId(17)));
    expect(s.scope.read(p).result?.snapshot?.detail.material.id, mgId(17));
    expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
  });
  test('CASH requires exact amount and lost response recovery only GETs', () async {
    final s = setup(), p = managerCashCommandProvider(mgOrder);
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final c = s.scope.read(p.notifier);
    expect(await c.confirm(999999), isNull);
    expect(s.wire.cashPaid, false);
    expect(s.wire.requests.where((r) => r.method == 'POST'), isEmpty);
    s.wire.loseNextWrite = true;
    await c.confirm(1000000);
    expect(s.scope.read(p).retryPending, true);
    expect(await c.confirm(1000000), isNull);
    expect((await c.check())?.canConfirm, false);
    expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
  });
  test('CASH acknowledged then GET fails: check never repeats POST', () async {
    final s = setup(wire: ManagerFixtureAdapter()..failPaidDetail = true), p = managerCashCommandProvider(mgOrder);
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final c = s.scope.read(p.notifier);
    await c.confirm(1000000);
    expect(s.scope.read(p).retryPending, true);
    expect(await c.check(), isNotNull);
    expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
  });
  test('Late mutation response cannot update the next account or replay its receipt', () async {
    final s = setup(), p = managerLeaveCommandProvider(mgLeave), detail = await ManagerLeaveApi(s.api).detail(mgLeave);
    final sub = s.scope.listen(p, (_, _) {});
    addTearDown(sub.close);
    final held = Completer<ResponseBody>();
    s.wire.heldResponse = held;
    final c = s.scope.read(p.notifier), pending = c.decide(detail, approve: true, reason: 'OK', acknowledge: true);
    while (s.wire.requests.where((r) => r.method == 'POST').isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    (s.scope.read(sessionProvider.notifier) as ManagerFixtureSession).change();
    await s.scope.pump();
    held.complete(s.wire.response({'request': mgLeaveJson(status: 'APPROVED', version: 2)}));
    expect(await pending, isNull);
    expect(s.scope.read(p).result, isNull);
    expect(await s.scope.read(p.notifier).retry(), isNull);
  });
  test('Favorites persist by actor, fixed first three and max six', () async {
    final s = setup();
    await s.scope.read(managerFavoritesProvider.future);
    final c = s.scope.read(managerFavoritesProvider.notifier);
    for (final u in ManagerUtility.values) {
      await c.toggle(u);
    }
    expect(s.scope.read(managerFavoritesProvider).requireValue.length, 6);
    expect(s.scope.read(managerFavoritesProvider).requireValue.take(3), managerFixedFavorites);
    (s.scope.read(sessionProvider.notifier) as ManagerFixtureSession).change();
    await s.scope.pump();
    expect(await s.scope.read(managerFavoritesProvider.future), managerFixedFavorites);
  });
  for (final loseComplete in [false, true]) {
    test('Manager upload READY and lost complete=$loseComplete require explicit read/use', () async {
      final files = MemoryFilesApi()..loseCompleteResponse = loseComplete, put = MemoryUploadClient();
      final scope = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sessionProvider.overrideWith(ManagerFixtureSession.new),
          filesApiProvider.overrideWithValue(files),
          uploadClientProvider.overrideWithValue(put),
          managerUploadWaitProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(scope.dispose);
      final p = managerUploadProvider((unitId: mgUnit, slot: 'primary')),
          sub = scope.listen(managerUploadProvider((unitId: mgUnit, slot: 'primary')), (_, _) {});
      addTearDown(sub.close);
      final c = scope.read(p.notifier);
      await c.start(
        PickedUploadFile(
          name: 'test.pdf',
          size: 4,
          mimeType: 'application/pdf',
          openRead: () => Stream.value([1, 2, 3, 4]),
        ),
      );
      if (loseComplete) {
        expect(scope.read(p).checkRequired, true);
        await c.check();
      }
      expect(scope.read(p).file?.id, isNotNull);
      expect(scope.read(p).file?.mimeType, 'application/pdf');
      expect(put.puts, 1);
      expect(files.completes, 1);
      expect(files.courseUnitId, mgUnit);
    });
  }
  test('Read-only PAYOS and payment review cannot be confirmed', () {
    final payos = CollectionOrder.fromJson(Json({...mgOrderJson(), 'paymentType': 'PAYOS'}));
    expect(payos.canConfirm, false);
  });
  test('Manager real login accepts MANAGER, logout clears actor and private state', () async {
    final wire = ManagerFixtureAdapter()..loggedIn = false, client = managerFixtureClient(wire);
    final scope = ProviderContainer(retry: (_, _) => null, overrides: [apiClientProvider.overrideWithValue(client)]);
    addTearDown(() {
      scope.dispose();
      client.dio.close(force: true);
    });
    final c = scope.read(sessionProvider.notifier);
    while (!scope.read(sessionProvider).ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await c.login('manager@example.test', 'synthetic-only');
    expect(scope.read(sessionProvider).user?.role, Role.MANAGER);
    final epoch = scope.read(sessionEpochProvider);
    await c.logout();
    expect(scope.read(sessionProvider).user, isNull);
    expect(scope.read(sessionEpochProvider), greaterThan(epoch));
  });
  test('Queued Manager reads do not start under a new account and concurrency stays bounded', () async {
    final s = setup(), gate = Completer<void>();
    s.wire.heldReadGate = gate;
    final pending = List.generate(
      5,
      (_) => s.api.people('MENTOR', '').then<Object?>((v) => v, onError: (Object e) => e),
    );
    while (s.wire.requests.length < 3) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(s.wire.requests.length, 3);
    s.api.client.sessionEpoch++;
    s.wire.heldReadGate = null;
    gate.complete();
    final results = await Future.wait(pending);
    expect(results.every((r) => r is ApiError), true);
    expect(s.wire.requests.length, 3);
  });
  test('Changing actor during Manager PUT cannot complete or expose the old file', () async {
    final files = MemoryFilesApi(), put = MemoryUploadClient()..gate = Completer<void>();
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(ManagerFixtureSession.new),
        apiClientProvider.overrideWithValue(managerFixtureClient(ManagerFixtureAdapter())),
        filesApiProvider.overrideWithValue(files),
        uploadClientProvider.overrideWithValue(put),
      ],
    );
    addTearDown(scope.dispose);
    final p = managerUploadProvider((unitId: mgUnit, slot: 'primary')),
        sub = scope.listen(managerUploadProvider((unitId: mgUnit, slot: 'primary')), (_, _) {});
    addTearDown(sub.close);
    final pending = scope
        .read(p.notifier)
        .start(
          PickedUploadFile(
            name: 'test.pdf',
            size: 4,
            mimeType: 'application/pdf',
            openRead: () => Stream.value([1, 2, 3, 4]),
          ),
        );
    while (put.puts == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    (scope.read(sessionProvider.notifier) as ManagerFixtureSession).change();
    await scope.pump();
    put.gate!.complete();
    await pending;
    expect(files.completes, 0);
    expect(scope.read(p).fileId, isNull);
    expect(scope.read(p).file, isNull);
  });
}
