import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_api.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/reports/reports_api.dart';
import 'package:mindy_flutter/features/mentor/reports/reports_models.dart';
import 'package:mindy_flutter/features/mentor/reports/reports_providers.dart';
import 'package:mindy_flutter/features/mentor/students/students_api.dart';
import 'package:mindy_flutter/features/mentor/students/students_models.dart';
import 'package:mindy_flutter/features/mentor/students/students_providers.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import '../tool/preview/attendance_fixtures.dart';
import '../tool/preview/classes_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';
import 'mentor_api_test.dart' show body, client;

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
}

class _Classes extends MentorClassesApi {
  _Classes(this.workspaceValue) : super(client((_) => (throw StateError('Unexpected API'))));
  final MentorWorkspace workspaceValue;
  @override
  Future<MentorWorkspace> workspace(String id, {CancelToken? cancel}) async => workspaceValue;
}

class _Students extends MentorStudentsApi {
  _Students(this.rows) : super(client((_) => (throw StateError('Unexpected API'))));
  final List<MentorStudent> rows;
  @override
  Future<List<MentorStudent>> all(String id, {CancelToken? cancel}) async => rows;
}

class _Attendance extends MentorAttendanceApi {
  _Attendance() : super(client((_) => (throw StateError('Unexpected API'))));
  var active = 0, maxActive = 0, calls = 0;
  final ids = <String>[];
  @override
  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) async {
    calls++;
    ids.add(id);
    active++;
    if (active > maxActive) {
      maxActive = active;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
    active--;
    if (id == fixtureId(101)) {
      throw ApiError(status: 403, code: 'MENTOR_SCOPE_REQUIRED');
    }
    return MemoryAttendanceApi(sessionId: id, status: TeachingStatus.COMPLETED).roster(id);
  }
}

Map<String, Object?> countsJson([Map<String, Object?> changes = const {}]) => {
  'present': 8,
  'absent': 2,
  'unmarked': 1,
  'excluded': 1,
  'makeupPending': 1,
  'finalizedEligibleCount': 10,
  'rate': 80,
  ...changes,
};
Map<String, Object?> summaryJson(int page, List<Object?> items, int total) => {
  'classId': fixtureClassId,
  'readonly': false,
  'timeZone': previewZone,
  'asOf': '2026-11-02T07:00:00Z',
  'items': items,
  'page': page,
  'pageSize': 1,
  'total': total,
};
Map<String, Object?> summaryRow(int id) => {
  'enrollmentId': fixtureId(200 + id),
  'student': {'id': fixtureId(300 + id), 'displayName': 'Học viên'},
  ...countsJson(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  test('Phân nhóm lớp giữ CANCELLED riêng và không suy diễn tiến độ', () {
    expect(mentorClassGroup(MentorClassStatus.DRAFT), MentorClassGroup.upcoming);
    expect(mentorClassGroup(MentorClassStatus.OPEN), MentorClassGroup.upcoming);
    expect(mentorClassGroup(MentorClassStatus.COMPLETED), MentorClassGroup.ended);
    expect(mentorClassGroup(MentorClassStatus.CANCELLED), MentorClassGroup.cancelled);
  });
  test('Counts: null khác 0%, loại unmarked/excluded khỏi mẫu số; aggregate có trọng số', () {
    expect(MentorAttendanceCounts.fromJson(Json(countsJson(), 'BAD')).rate, 80);
    expect(
      MentorAttendanceCounts.fromJson(
        Json(countsJson({'present': 0, 'absent': 0, 'finalizedEligibleCount': 0, 'rate': null}), 'BAD'),
      ).rate,
      isNull,
    );
    for (final malformed in [
      {'present': -1},
      {'rate': '80'},
      {'rate': 101},
      {'finalizedEligibleCount': 11},
      {'rate': null},
    ]) {
      expect(() => MentorAttendanceCounts.fromJson(Json(countsJson(malformed), 'BAD')), throwsA(isA<ApiError>()));
    }
    expect(
      weightedAttendance([sampleCounts(present: 1, absent: 0), sampleCounts(present: 1, absent: 9)]),
      closeTo(200 / 11, .0001),
    );
    expect(weightedAttendance([sampleCounts(present: 0, absent: 0)]), isNull);
    expect(formatPercent(0, 'vi'), '0%');
    expect(formatPercent(null, 'vi'), '—');
  });
  test('Tìm tên tiếng Việt không dấu; mốc 80 và tỷ lệ chưa có không vào cần chú ý', () {
    final rows = sampleStudents().rows;
    expect(filterMentorStudents(rows, 'dang thuy', MentorStudentFilter.all).single.student.name, 'Đặng Thùy Dương');
    expect(filterMentorStudents(rows, '', MentorStudentFilter.attention), hasLength(1));
    expect(filterMentorStudents(rows, '', MentorStudentFilter.regular), hasLength(1));
    expect(needsAttention(80), isFalse);
    expect(needsAttention(79.99), isTrue);
    expect(needsAttention(null), isFalse);
  });
  test('Tỷ lệ từng buổi không biến roster chưa đủ hoặc bị từ chối thành 0%', () {
    final row = sampleWorkspaceSessions().first;
    expect(SessionAttendanceReport(row: row, denied: true).rate, isNull);
    expect(
      SessionAttendanceReport(
        row: row,
        totals: const AttendanceTotals(present: 0, absent: 1, unmarked: 0, eligible: 1),
      ).rate,
      0,
    );
    expect(
      SessionAttendanceReport(
        row: row,
        totals: const AttendanceTotals(present: 1, absent: 0, unmarked: 1, eligible: 2),
      ).rate,
      isNull,
    );
  });
  test('Stored progress parse decimal nhưng không chấp nhận policy hoàn thành giả', () {
    final metadata = {
      'completionPolicy': 'UNDEFINED',
      'policyVersion': null,
      'readonly': true,
      'assignmentSummary': {'availability': 'NOT_IMPLEMENTED', 'counts': null},
      'timeZone': previewZone,
      'asOf': '2026-11-02T07:00:00Z',
    };
    expect(StudentStoredProgress.metadata(Json(metadata, 'BAD')), previewZone);
    expect(
      () => StudentStoredProgress.metadata(Json({...metadata, 'completionPolicy': 'ATTENDANCE'}, 'BAD')),
      throwsA(isA<ApiError>()),
    );
    final row = {
      'enrollmentId': fixtureId(200),
      'classUnitId': fixtureId(20),
      'trackingStatus': 'STORED',
      'status': 'IN_PROGRESS',
      'progressPercent': '45.50',
      'completedAt': null,
      'dataQuality': 'VALID',
    };
    expect(StudentStoredUnit.fromJson(Json(row, 'BAD')).percent, '45.50');
    for (final value in ['NaN', '101', '-1', 45]) {
      expect(
        () => StudentStoredUnit.fromJson(Json({...row, 'progressPercent': value}, 'BAD')),
        throwsA(isA<ApiError>()),
      );
    }
  });
  test('Báo cáo đọc hết trang và từ chối metadata lệch lớp, zone hoặc enrollment trùng', () async {
    final pages = <int>[];
    final api = MentorReportsApi(
      client((o) {
        final page = o.queryParameters['page'] as int;
        pages.add(page);
        return body(summaryJson(page, [summaryRow(page)], 2));
      }),
    );
    expect((await api.classSummary(fixtureClassId)).items, hasLength(2));
    expect(pages, [1, 2]);
    for (final change in [
      {'classId': fixtureId(11)},
      {'timeZone': 'Invalid/Zone'},
    ]) {
      await expectLater(
        MentorReportsApi(
          client(
            (_) => body({
              ...summaryJson(1, [summaryRow(1)], 1),
              ...change,
            }),
          ),
        ).classSummary(fixtureClassId),
        throwsA(isA<ApiError>()),
      );
    }
    await expectLater(
      MentorReportsApi(
        client((o) => body(summaryJson(o.queryParameters['page'] as int, [summaryRow(1)], 2))),
      ).classSummary(fixtureClassId),
      throwsA(isA<ApiError>()),
    );
  });
  test('Deep link chỉ-dạy-thay bị chặn trước khi đọc học viên/báo cáo/lịch sử', () async {
    var calls = 0;
    final network = client((_) {
      calls++;
      throw StateError('Private API must not run');
    });
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorClassesApiProvider.overrideWithValue(_Classes(sampleWorkspace(substitute: true))),
        mentorStudentsApiProvider.overrideWithValue(MentorStudentsApi(network)),
        mentorReportsApiProvider.overrideWithValue(MentorReportsApi(network)),
        mentorAttendanceApiProvider.overrideWithValue(MentorAttendanceApi(network)),
      ],
    );
    addTearDown(scope.dispose);
    for (final future in [
      scope.read(mentorStudentsProvider(fixtureClassId).future),
      scope.read(mentorClassReportProvider(fixtureClassId).future),
      scope.read(mentorStudentDetailsProvider((classId: fixtureClassId, studentId: fixtureId(300))).future),
    ]) {
      await expectLater(future, throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)));
    }
    expect(calls, 0);
  });
  test('Ghép theo enrollmentId dù summary khác thứ tự và có ghi danh lịch sử', () async {
    final source = sampleStudents(), summary = sampleClassSummary();
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorPrimaryWorkspaceProvider.overrideWith((_, _) async => sampleWorkspace()),
        mentorStudentsApiProvider.overrideWithValue(_Students(source.rows.map((r) => r.student).toList())),
        mentorClassAttendanceSummaryProvider.overrideWith(
          (_, _) async => ClassAttendanceSummary(
            classId: fixtureClassId,
            timeZone: previewZone,
            readonly: false,
            asOf: previewNow,
            items: summary.items.reversed.toList(),
          ),
        ),
      ],
    );
    addTearDown(scope.dispose);
    final data = await scope.read(mentorStudentsProvider(fixtureClassId).future);
    expect(data.rows.map((r) => r.counts.rate), [90, 60, null]);
  });
  test('Roster từng buổi tối đa 3 đồng thời; skip scope, 403 cục bộ vẫn giữ tổng lớp', () async {
    final api = _Attendance();
    final rows = [
      for (var i = 0; i < 8; i++)
        MentorWorkspaceSession(
          session: sampleEntry(101 + i, previewNow, status: TeachingStatus.COMPLETED).session,
          readContext: i != 1,
          writeNotes: false,
        ),
    ];
    final scope = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        mentorPrimaryWorkspaceProvider.overrideWith((_, _) async => sampleWorkspace()),
        mentorWorkspaceSessionsProvider.overrideWith((_, _) async => rows),
        mentorClassAttendanceSummaryProvider.overrideWith((_, _) async => sampleClassSummary()),
        mentorAttendanceApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(scope.dispose);
    final report = await scope.read(mentorClassReportProvider(fixtureClassId).future);
    expect(api.maxActive, 3);
    expect(api.calls, 7);
    expect(api.ids, isNot(contains(fixtureId(102))));
    expect(report.sessions.where((r) => r.denied), hasLength(2));
    expect(report.sessions.where((r) => r.totals != null), hasLength(6));
    expect(weightedAttendance(report.summary.items.map((r) => r.counts)), 75);
  });
}
