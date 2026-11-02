import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_models.dart';
import 'package:mindy_flutter/features/notifications/notifications_models.dart';

/// Dữ liệu giả cố định cho review UI/golden. Không được import từ lib/main.dart.
final previewNow = DateTime.utc(2026, 11, 2, 7, 15);
const previewDay = '2026-11-02';
const previewZone = 'Asia/Ho_Chi_Minh';
const previewMentor = TeachingPerson(id: '00000000-0000-4000-8000-000000000001', displayName: 'Trần Thị Linh');
const previewPrimaryMentor = TeachingPerson(
  id: '00000000-0000-4000-8000-000000000002',
  displayName: 'Nguyễn Hoàng Long',
);

TeachingEntry sampleEntry(
  int index,
  DateTime start, {
  bool substitute = false,
  TeachingStatus status = TeachingStatus.SCHEDULED,
}) {
  final primary = substitute ? previewPrimaryMentor : previewMentor;
  return TeachingEntry(
    className: substitute ? 'IELTS 6.5 Intensive K08' : 'Giao tiếp B1 · Lớp 07',
    classCode: substitute ? 'IELTS-K08' : 'GTB1-07',
    roomName: substitute ? 'Phòng 301' : 'Phòng 204',
    session: TeachingSession(
      id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
      classId: '00000000-0000-4000-8000-000000000010',
      classUnitId: '00000000-0000-4000-8000-000000000020',
      title: 'Unit 5',
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 90)),
      status: status,
      primaryMentor: primary,
      effectiveMentor: previewMentor,
      assignment: substitute ? TeachingAssignment.SUBSTITUTE : TeachingAssignment.PRIMARY,
      version: 1,
      timeZone: previewZone,
      asOf: previewNow,
    ),
  );
}

TeachingSchedule sampleSchedule() => TeachingSchedule(
  timeZone: previewZone,
  entries: [
    sampleEntry(101, DateTime.utc(2026, 11, 2, 7)),
    sampleEntry(102, DateTime.utc(2026, 11, 2, 11, 30), substitute: true),
    sampleEntry(103, DateTime.utc(2026, 11, 3, 12), substitute: true),
    sampleEntry(104, DateTime.utc(2026, 10, 26, 11), substitute: true, status: TeachingStatus.COMPLETED),
    sampleEntry(105, DateTime.utc(2026, 11, 5, 7), status: TeachingStatus.CANCELLED),
  ],
);

TeachingRoom sampleRoom({bool noLink = false, TeachingEntry? entry}) => TeachingRoom(
  session: (entry ?? sampleSchedule().entries.first).session,
  roomName: (entry ?? sampleSchedule().entries.first).roomName,
  meetingUrl: noLink ? null : Uri.parse('https://example.test/meeting'),
);

List<MindyNotification> sampleNotifications() => [
  for (var i = 0; i < 3; i++)
    MindyNotification(
      id: '00000000-0000-4000-8000-${(200 + i).toString().padLeft(12, '0')}',
      actorId: previewPrimaryMentor.id,
      conversationId: '00000000-0000-4000-8000-000000000300',
      messageId: '00000000-0000-4000-8000-${(400 + i).toString().padLeft(12, '0')}',
      title: 'Tin nhắn mới',
      body: 'Bạn có tin nhắn mới.',
      createdAt: previewNow.subtract(Duration(minutes: 10 + i * 30)),
      readAt: i == 2 ? previewNow : null,
    ),
];
