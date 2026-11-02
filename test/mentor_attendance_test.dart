import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/idempotency.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';

import 'mentor_api_test.dart' show body, client;
import 'mentor_mf2_test.dart' show sessionJson;

const attendanceId = '00000000-0000-4000-8000-000000000101';
String fixtureId(int value) => '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
Map<String, Object?> permissionsJson({bool start = false}) => {
  'canStart': start,
  'canEditAttendance': !start,
  'canFinalize': !start,
  'canSyncRoster': !start,
  'canRecover': false,
  'canViewAttendanceAudits': false,
};
Map<String, Object?> attendanceHeaderJson(int total, {int version = 2, String status = 'IN_PROGRESS'}) => {
  'session': sessionJson({
    'version': version,
    'status': status,
    'permissions': permissionsJson(),
    'actualStartedAt': '2026-11-02T07:00:00Z',
    'editableUntil': '2026-11-03T17:00:00Z',
  }),
  'totals': {'present': 0, 'absent': 0, 'unmarked': total, 'eligible': total},
};
Map<String, Object?> recordJson(int number, {bool guest = false}) => {
  'attendanceId': fixtureId(1000 + number),
  'enrollmentId': fixtureId(2000 + number),
  'entryType': guest ? 'MAKEUP' : 'REGULAR',
  'makeupPlacementId': guest ? fixtureId(3000 + number) : null,
  'student': {'id': fixtureId(4000 + number), 'displayName': 'Học viên mẫu $number'},
  'status': 'UNMARKED',
  'checkedInAt': null,
  'admittedAt': '2026-11-02T07:00:00Z',
};
AttendanceRoster fixtureRoster(int count) => AttendanceRoster(
  header: AttendanceHeader.fromJson(Json(attendanceHeaderJson(count)), attendanceId),
  pendingPaymentCount: 1,
  records: [for (var i = 0; i < count; i++) AttendanceRecord.fromJson(Json(recordJson(i, guest: i.isOdd)))],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
  });

  test('Diff chỉ chứa dòng đổi, batch 100, khách học bù dùng placement thay enrollment', () {
    final roster = fixtureRoster(205);
    final draft = {for (final row in roster.records) row.key: AttendanceStatus.PRESENT};
    final diff = attendanceDiff(roster, draft);
    final batches = attendanceBatches(diff);
    expect(batches.map((batch) => batch.length), [100, 100, 5]);
    final payload = attendanceBatchBody(batches.first, 2);
    expect(payload['records'], hasLength(50));
    expect(payload['guestRecords'], hasLength(50));
    final guests = payload['guestRecords']! as List<Map<String, Object?>>;
    expect(guests.every((row) => row.containsKey('makeupPlacementId') && !row.containsKey('enrollmentId')), isTrue);
    expect(attendanceDiff(roster, {roster.records.first.key: AttendanceStatus.UNMARKED}), isEmpty);
  });

  test('Regular và MAKEUP cùng enrollment vẫn có hai định danh độc lập', () {
    final regular = AttendanceRecord.fromJson(Json(recordJson(1)));
    final guest = AttendanceRecord.fromJson(Json(recordJson(1, guest: true)));
    expect(regular.enrollmentId, guest.enrollmentId);
    expect(regular.key, isNot(guest.key));
  });

  test('Permission server vẫn cho sửa buổi đã chốt; không tự khóa theo status', () {
    final j = Json(attendanceHeaderJson(0, status: 'COMPLETED'));
    final header = AttendanceHeader.fromJson(j, attendanceId);
    expect(header.session.status, TeachingStatus.COMPLETED);
    expect(header.permissions.canEdit, isTrue);
    expect(
      () => AttendanceTotals.fromJson(Json({'present': 1, 'absent': 0, 'unmarked': 0, 'eligible': 2})),
      throwsA(isA<ApiError>()),
    );
    expect(() => AttendanceRecord.fromJson(Json({...recordJson(1), 'entryType': 'MAKEUP'})), throwsA(isA<ApiError>()));
  });

  test('Roster đọc hết trang và kiểm tra snapshot version', () async {
    final api = MentorAttendanceApi(
      client((request) {
        final page = request.queryParameters['page']! as int;
        final start = (page - 1) * 100, end = page == 1 ? 100 : 101;
        return body({
          ...attendanceHeaderJson(101),
          'items': [for (var i = start; i < end; i++) recordJson(i)],
          'page': page,
          'pageSize': 100,
          'total': 101,
          'pendingPaymentCount': 1,
        });
      }),
    );
    expect((await api.roster(attendanceId)).records, hasLength(101));
    final conflict = MentorAttendanceApi(
      client((request) {
        final page = request.queryParameters['page']! as int;
        return body({
          ...attendanceHeaderJson(101, version: page + 1),
          'items': [for (var i = (page - 1) * 100; i < (page == 1 ? 100 : 101); i++) recordJson(i)],
          'page': page,
          'pageSize': 100,
          'total': 101,
          'pendingPaymentCount': 0,
        });
      }),
    );
    await expectLater(
      conflict.roster(attendanceId),
      throwsA(isA<ApiError>().having((error) => error.code, 'code', 'SESSION_VERSION_CONFLICT')),
    );
  });

  test('Mutation gửi đúng method, Idempotency-Key và version; retry giữ nguyên call', () async {
    final keys = <String>[];
    final api = MentorAttendanceApi(
      client((request) {
        expect(request.method, 'PUT');
        expect(request.path, 'class-sessions/$attendanceId/attendance');
        keys.add(request.headers['Idempotency-Key']! as String);
        expect((request.data! as Map<String, Object?>)['expectedVersion'], 2);
        return body({
          ...attendanceHeaderJson(0, version: 3),
          'changedEnrollmentIds': <String>[],
          'changedMakeupPlacementIds': <String>[],
        });
      }),
    );
    final call = IdempotentCall({'expectedVersion': 2, 'records': <Object?>[]});
    await api.execute(attendanceId, AttendanceOperation.mark, call);
    await api.execute(attendanceId, AttendanceOperation.mark, call);
    expect(keys, [call.key, call.key]);
  });

  test('Bảng lỗi mục 19.8 có câu theo code/status, không dựa message', () {
    final keys = <String, String>{
      'SESSION_ASSIGNMENT_REQUIRED': 'mentor.session.accessLost',
      'CLASS_SESSION_NOT_FOUND': 'mentor.attendance.errors.notFound',
      'SESSION_VERSION_CONFLICT': 'mentor.attendance.errors.conflict',
      'SESSION_STATE_CONFLICT': 'mentor.attendance.errors.stateChanged',
      'ATTENDANCE_START_DAY_CLOSED': 'mentor.attendance.errors.startClosed',
      'ATTENDANCE_EDIT_WINDOW_EXPIRED': 'mentor.attendance.errors.expired',
      'IDEMPOTENCY_KEY_REUSED': 'mentor.attendance.errors.keyReused',
      'ATTENDANCE_ENROLLMENT_NOT_ELIGIBLE': 'mentor.attendance.errors.rosterChanged',
      'CLASS_SESSION_OVERNIGHT_NOT_ALLOWED': 'mentor.attendance.errors.invalidInput',
      'HTTP_ERROR': 'mentor.attendance.errors.invalidInput',
    };
    for (final entry in keys.entries) {
      expect(attendanceErrorKey(ApiError(status: 422, code: entry.key, message: 'Thay đổi bất kỳ')), entry.value);
    }
    expect(attendanceErrorKey(ApiError(status: 500, code: 'HTTP_ERROR')), 'errors.generic');
  });
}
