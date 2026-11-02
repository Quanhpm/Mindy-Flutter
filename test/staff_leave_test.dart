import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/features/staff/leave/leave_query.dart';
import 'package:mindy_flutter/features/staff/leave/leave_service.dart';
import 'package:mindy_flutter/features/staff/shared/connectivity.dart';
import 'package:mindy_flutter/features/staff/teaching/teaching_models.dart';

const _id = '00000000-0000-4000-8000-000000000001';
const _other = '00000000-0000-4000-8000-000000000002';
const _key = '00000000-0000-4000-8000-000000000003';

Map<String, Object?> _wirePlacement(String id) => {
  'id': id,
  'conflictId': _other,
  'status': 'CANCELLED',
  'version': 2,
  'targetSession': {
    'sessionId': _other,
    'classId': _id,
    'classUnitId': _id,
    'title': 'Học bù',
    'startsAt': '2026-11-04T09:00:00+07:00',
    'endsAt': '2026-11-04T11:00:00+07:00',
    'asOf': '2026-11-03T09:00:00+07:00',
    'status': 'SCHEDULED',
    'assignmentType': 'PRIMARY',
    'version': 1,
    'primaryMentor': {'id': _id, 'displayName': 'Mentor'},
    'effectiveMentor': null,
    'makeupForSessionId': null,
    'makeupRootSessionId': null,
    'actualStartedAt': null,
    'actualEndedAt': null,
  },
};

Slot _slot(String from, String to) =>
    Slot(startsAt: DateTime.parse(from), endsAt: DateTime.parse(to));

class _Api extends ApiClient {
  _Api() : super(cookieJar: CookieJar());
  Object? response, failure;
  final calls = <({String path, Object? body, Map<String, String>? headers})>[];
  Completer<Object?>? pending;

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    calls.add((path: path, body: body, headers: headers));
    if (failure case final error?) throw error;
    return pending == null ? response : await pending!.future;
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?>? query,
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    calls.add((path: path, body: query, headers: null));
    return response;
  }
}

class _Writer extends LeaveService {
  _Writer() : super(_Api());
  final intents = <LeaveIntent>[];
  final outcomes = <LeaveOutcome>[];
  @override
  Future<LeaveOutcome> write(LeaveIntent intent) async {
    intents.add(intent);
    return outcomes.removeAt(0);
  }
}

void main() {
  test('Ngày hợp lệ, thứ tự và giới hạn 93 ngày giống RN', () {
    expect(validDay('2028-02-29'), isTrue);
    expect(validDay('2026-02-29'), isFalse);
    expect(validDay('2026-2-01'), isFalse);
    expect(dateRangeError('2026-11-03', '2026-11-02'), 'before');
    expect(dateRangeError('2026-01-01', '2026-04-03'), isNull);
    expect(dateRangeError('2026-01-01', '2026-04-04'), 'max');
    expect(vietnamDay(DateTime.parse('2026-11-02T18:00:00Z')), '2026-11-03');
  });

  test(
    'Giờ bù không nằm trong buổi nghỉ, không trùng mapping khác, chấp nhận chạm biên',
    () {
      const range = (
        fromDate: '2026-11-03',
        toDate: '2026-11-03',
        period: Period.MORNING,
      );
      expect(
        slotAllowed(
          _slot('2026-11-03T11:00:00+07:00', '2026-11-03T12:00:00+07:00'),
          range,
          [],
        ),
        isFalse,
      );
      final afternoon = _slot(
        '2026-11-03T12:00:00+07:00',
        '2026-11-03T14:00:00+07:00',
      );
      expect(slotAllowed(afternoon, range, []), isTrue);
      expect(
        slotAllowed(afternoon, range, [
          _slot('2026-11-03T14:00:00+07:00', '2026-11-03T16:00:00+07:00'),
        ]),
        isTrue,
      );
      expect(
        slotAllowed(afternoon, range, [
          _slot('2026-11-03T13:59:00+07:00', '2026-11-03T16:00:00+07:00'),
        ]),
        isFalse,
      );
      expect(
        slotAllowed(
          _slot('2026-11-02T23:30:00+07:00', '2026-11-03T00:30:00+07:00'),
          range,
          [],
        ),
        isFalse,
      );
    },
  );

  test('Preview thay version chỉ loại mapping cũ, giữ mapping còn đúng', () {
    final starts = DateTime.parse('2026-11-04T09:00:00+07:00');
    final ends = starts.add(const Duration(hours: 2));
    final mapping = Mapping(startsAt: starts, endsAt: ends, version: 1);
    final preview = Preview(
      sources: [
        SourceSession(
          id: _id,
          classId: _other,
          title: 'Buổi 1',
          version: 2,
          assignment: SessionAssignment.PRIMARY,
          startsAt: starts,
          endsAt: ends,
        ),
      ],
      sourceVersions: [(sessionId: _id, version: 2)],
      noticeEligible: true,
      asOf: starts,
    );
    expect(reconcileMappings({_id: mapping}, preview), isEmpty);
    expect(
      reconcileMappings({
        _id: Mapping(startsAt: starts, endsAt: ends, version: 2),
      }, preview).keys,
      [_id],
    );
    expect(
      leaveRequestBytes({'reason': 'Nghỉ dạy ☀'}),
      utf8.encode(jsonEncode({'reason': 'Nghỉ dạy ☀'})).length,
    );
  });

  test('Không phát lệnh ghi sai role, version hoặc ngày mapping', () async {
    final api = _Api();
    final service = LeaveService(api);
    expect(
      (await service.write(
        const LeaveIntent(
          kind: LeaveIntentKind.approve,
          role: LeaveRole.MENTOR,
          id: _id,
          key: _key,
          reason: 'Duyệt',
          expectedVersion: 1,
        ),
      )).kind,
      LeaveOutcomeKind.denied,
    );
    expect(
      (await service.write(
        const LeaveIntent(
          kind: LeaveIntentKind.withdraw,
          role: LeaveRole.MENTOR,
          id: _id,
          key: _key,
          reason: 'Rút đơn',
          expectedVersion: 0,
        ),
      )).code,
      'INVALID_INPUT',
    );
    final starts = DateTime.parse('2026-11-04T09:00:00+07:00');
    expect(
      (await service.write(
        LeaveIntent(
          kind: LeaveIntentKind.create,
          role: LeaveRole.MENTOR,
          key: _key,
          fromDate: '2026-11-03',
          toDate: '2026-11-03',
          period: Period.FULL_DAY,
          reason: 'Nghỉ dạy',
          sourceVersions: const [(sessionId: _id, version: 1)],
          sessionMappings: [
            (
              sourceSessionId: _id,
              targetDate: '2026-02-30',
              targetPeriod: Period.MORNING,
              startsAt: starts,
              endsAt: starts.add(const Duration(hours: 2)),
            ),
          ],
        ),
      )).code,
      'INVALID_INPUT',
    );
    expect(api.calls, isEmpty);
  });

  test(
    'Ghi timeout / response sai tài nguyên là uncertain; dùng header idempotency',
    () async {
      final api = _Api()..failure = ApiError.network();
      final service = LeaveService(api);
      const intent = LeaveIntent(
        kind: LeaveIntentKind.cancel,
        role: LeaveRole.MANAGER,
        id: _id,
        key: _key,
        reason: 'Xếp lại',
        expectedVersion: 1,
      );
      expect((await service.write(intent)).kind, LeaveOutcomeKind.uncertain);
      expect(api.calls.single.path, 'management/makeup-placements/$_id/cancel');
      expect(api.calls.single.headers?['Idempotency-Key'], _key);
      api
        ..failure = null
        ..response = _wirePlacement(_other);
      expect((await service.write(intent)).kind, LeaveOutcomeKind.uncertain);
      api.response = _wirePlacement(_id);
      expect((await service.write(intent)).success, isTrue);
      api.response = {'id': _id, 'status': 'CANCELLED'};
      expect((await service.write(intent)).kind, LeaveOutcomeKind.uncertain);
    },
  );

  test('Response phiên cũ không được chấp nhận sau khi actor đổi', () async {
    var active = true;
    final api = _Api()..pending = Completer<Object?>();
    final service = LeaveService(api, canUse: (_) => active);
    final response = service.write(
      const LeaveIntent(
        kind: LeaveIntentKind.cancel,
        role: LeaveRole.MANAGER,
        id: _id,
        key: _key,
        reason: 'Hủy',
        expectedVersion: 1,
      ),
    );
    active = false;
    api.pending!.complete({'id': _id, 'status': 'CANCELLED'});
    expect((await response).kind, LeaveOutcomeKind.denied);
  });

  testWidgets(
    'Retry uncertain giữ nguyên payload và key; khóa intent khác trên cùng đơn',
    (tester) async {
      final service = _Writer()
        ..outcomes.addAll([
          const LeaveOutcome(LeaveOutcomeKind.uncertain),
          const LeaveOutcome(LeaveOutcomeKind.success, data: LeaveData()),
        ]);
      late LeaveMutator mutation, competing;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            staffOfflineProvider.overrideWithValue(false),
            sessionEpochProvider.overrideWithValue(0),
            leaveServiceProvider.overrideWithValue(service),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              mutation = LeaveMutator(ref, () {});
              competing = LeaveMutator(ref, () {});
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      const intent = LeaveIntent(
        kind: LeaveIntentKind.reject,
        role: LeaveRole.MANAGER,
        id: _id,
        reason: 'Bản đã xác nhận',
        expectedVersion: 2,
      );
      await mutation.submit(intent);
      expect(mutation.uncertain, isTrue);
      expect(await competing.submit(intent), isNull);
      await mutation.submit(
        const LeaveIntent(
          kind: LeaveIntentKind.reject,
          role: LeaveRole.MANAGER,
          id: _id,
          reason: 'Không được thay payload khi retry',
          expectedVersion: 3,
        ),
      );
      expect(service.intents.length, 2);
      expect(service.intents.first.key, service.intents.last.key);
      expect(service.intents.last.reason, 'Bản đã xác nhận');
      expect(service.intents.last.expectedVersion, 2);
      expect(mutation.intent, isNull);
    },
  );
}
