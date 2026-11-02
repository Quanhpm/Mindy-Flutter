import 'package:mindy_flutter/features/mentor/operations/operations_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_models.dart';
import 'mentor_fixtures.dart';

const operationSessionId = '00000000-0000-4000-8000-000000000101';
const operationRequestId = '00000000-0000-4000-8000-000000000701';
LeaveRequest operationRequest({int version = 1, LeaveStatus status = LeaveStatus.PENDING}) => LeaveRequest(
  id: operationRequestId,
  from: '2026-11-12',
  to: '2026-11-12',
  period: LeavePeriod.FULL_DAY,
  status: status,
  reason: 'Lịch công tác đã được thông báo. Đề xuất dạy bù cho đủ buổi.',
  version: version,
  submitted: previewNow,
  expires: previewNow.add(const Duration(days: 9)),
  zone: previewZone,
  count: 1,
  page: 1,
  pageSize: 100,
  items: [
    LeaveItem(
      operationSessionId,
      '00000000-0000-4000-8000-000000000010',
      DateTime.utc(2026, 11, 12, 7),
      DateTime.utc(2026, 11, 12, 8, 30),
      DateTime.utc(2026, 11, 15, 7),
      DateTime.utc(2026, 11, 15, 8, 30),
      null,
    ),
  ],
  extensions: [(classId: '00000000-0000-4000-8000-000000000010', endDate: '2026-12-20')],
  reviewReason: null,
  conflicts: 0,
  asOf: previewNow,
);
TeachingRoom operationRoom() {
  final now = DateTime.now().toUtc();
  final original = sampleEntry(101, now.subtract(const Duration(minutes: 10))).session;
  return TeachingRoom(
    session: TeachingSession(
      id: original.id,
      classId: original.classId,
      classUnitId: original.classUnitId,
      title: original.title,
      startsAt: original.startsAt,
      endsAt: original.endsAt,
      status: TeachingStatus.IN_PROGRESS,
      primaryMentor: original.primaryMentor,
      effectiveMentor: original.effectiveMentor,
      assignment: original.assignment,
      version: 2,
      timeZone: original.timeZone,
      asOf: now,
      editableUntil: now.add(const Duration(days: 1)),
    ),
    roomName: 'Phòng tổng hợp',
    meetingUrl: Uri.parse('https://example.test/meeting'),
  );
}
