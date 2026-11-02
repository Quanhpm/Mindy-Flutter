import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/features/staff/shared/remote.dart';
import 'package:mindy_flutter/features/staff/teaching/teaching_format.dart';
import 'package:mindy_flutter/features/staff/teaching/teaching_models.dart';

TeachingSession session(String id, String startsAt, SessionStatus status, {String? endsAt}) => TeachingSession(
  id: id,
  classId: 'c',
  unitId: 'u',
  title: id,
  startsAt: DateTime.parse(startsAt),
  endsAt: DateTime.parse(endsAt ?? startsAt).add(const Duration(hours: 2)),
  status: status,
  assignment: SessionAssignment.PRIMARY,
  readSessionContext: true,
  version: 1,
);

void main() {
  test('Ngày giờ theo múi Việt Nam giống format.ts', () {
    final instant = DateTime.parse('2026-11-02T18:30:00Z');
    expect(vietnamDate(instant), '2026-11-03');
    expect(time(instant), '01:30');
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(weekDates('2026-11-05').first, '2026-11-02');
    expect(weekDates('2026-11-08').last, '2026-11-08');
    expect(weekRange('2026-11-05').from, '2026-11-02T00:00:00+07:00');
    expect(calendarDate('2026-11-03'), '03/11/2026');
    expect(shortDate('2026-11-03'), '03/11');
    expect(calendarDate(null), '—');
    expect(monthLabel('2026-11-03', 'vi'), 'Th11');
  });

  test('Chỉ nhận link học http(s) an toàn', () {
    expect(safeMeetingLink('https://meet.google.com/abc')?.host, 'meet.google.com');
    expect(safeMeetingLink('javascript:alert(1)'), isNull);
    expect(safeMeetingLink('https://user:pass@x.com'), isNull);
    expect(safeMeetingLink(null), isNull);
  });

  test('Buổi hôm nay: đang dạy > sắp dạy sớm nhất > đã xong muộn nhất', () {
    const date = '2026-11-03';
    final done1 = session('d1', '2026-11-03T01:00:00+07:00', SessionStatus.COMPLETED);
    final done2 = session('d2', '2026-11-03T05:00:00+07:00', SessionStatus.COMPLETED);
    final later = session('s2', '2026-11-03T18:00:00+07:00', SessionStatus.SCHEDULED);
    final soon = session('s1', '2026-11-03T14:00:00+07:00', SessionStatus.SCHEDULED);
    final live = session('l', '2026-11-03T09:00:00+07:00', SessionStatus.IN_PROGRESS);
    final other = session('x', '2026-11-04T09:00:00+07:00', SessionStatus.IN_PROGRESS);
    expect(selectTodaySession([done1, later, soon, live, other], date)?.id, 'l');
    expect(selectTodaySession([done1, later, soon], date)?.id, 's1');
    expect(selectTodaySession([done1, done2], date)?.id, 'd2');
    expect(selectTodaySession([other], date), isNull);
  });

  test('Tóm tắt lịch lớp giống classSessionSummary.ts', () {
    final now = DateTime.parse('2026-11-04T00:00:00+07:00');
    final s = classSessionSummary([
      session('a', '2026-11-02T18:00:00+07:00', SessionStatus.COMPLETED),
      session('b', '2026-11-05T18:00:00+07:00', SessionStatus.SCHEDULED),
      session('c', '2026-11-07T08:00:00+07:00', SessionStatus.SCHEDULED),
      session('z', '2026-11-06T08:00:00+07:00', SessionStatus.CANCELLED),
    ], now);
    expect(s.sessionCount, 3);
    expect(s.elapsedSessions, 1);
    expect(s.scheduleDays, [3, 5]);
    expect(s.scheduleTime, '18:00 / 08:00');
    expect(s.nextSessionAt, DateTime.parse('2026-11-05T18:00:00+07:00'));
  });

  test('TeachingRequest so sánh theo giá trị (key của provider family)', () {
    const a = TeachingRequest(kind: TeachingKind.classes, role: TeachingRole.MENTOR, pageSize: 100);
    const b = TeachingRequest(kind: TeachingKind.classes, role: TeachingRole.MENTOR, pageSize: 100);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.withPage(2) == a, isFalse);
  });

  test('Lỗi mạng map sang kind RN', () {
    expect(RemoteError.from(ApiError.network()).kind, RemoteFailure.offline);
    expect(RemoteError.from(ApiError(status: 403, code: 'FORBIDDEN')).kind, RemoteFailure.denied);
    expect(RemoteError.from(ApiError(status: 404, code: 'NOT_FOUND')).kind, RemoteFailure.notFound);
    expect(RemoteError.from(ApiError(status: 409, code: 'CONFLICT')).kind, RemoteFailure.conflict);
    expect(RemoteError.from(ApiError.invalidResponse()).kind, RemoteFailure.error);
    expect(RemoteError.from(StateError('x')).kind, RemoteFailure.error);
    expect(() => resourceId('not-a-uuid'), throwsA(isA<RemoteError>()));
  });
}
