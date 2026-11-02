// ignore_for_file: constant_identifier_names
import '../../core/network/json.dart';
import '../courses/courses_models.dart';
import '../my_classes/my_classes_models.dart';

/// Lịch học tuần (`me/schedule`) bỏ SESSION_MAKEUP như bản RN.
enum ScheduleAccess { FULL, CASH_PREVIEW, SESSION_MAKEUP }

class ScheduleSession {
  const ScheduleSession({
    required this.sessionId,
    required this.sessionNumber,
    required this.sessionTitle,
    required this.sessionStatus,
    required this.startsAt,
    required this.endsAt,
    required this.classId,
    required this.classCode,
    required this.className,
    required this.classStatus,
    required this.courseTitle,
    required this.deliveryMode,
    required this.mentorName,
    required this.roomName,
    required this.access,
  });

  final String sessionId;
  final int sessionNumber;
  final String sessionTitle;
  final SessionStatus sessionStatus;
  final DateTime startsAt;
  final DateTime endsAt;
  final String classId;
  final String classCode;
  final String className;
  final ClassStatus classStatus;
  final String courseTitle;
  final DeliveryMode deliveryMode;
  final String? mentorName;
  final String? roomName;
  final ScheduleAccess access;

  factory ScheduleSession.fromJson(Json j) {
    j.uuid('courseId');
    j.uuid('classUnitId');
    j.uuid('enrollmentId');
    final s = ScheduleSession(
      sessionId: j.uuid('sessionId'),
      sessionNumber: j.integer('sessionNumber'),
      sessionTitle: j.str('sessionTitle'),
      sessionStatus: j.enumOf('sessionStatus', SessionStatus.values),
      startsAt: j.dateTime('startsAt'),
      endsAt: j.dateTime('endsAt'),
      classId: j.uuid('classId'),
      classCode: j.str('classCode'),
      className: j.str('className'),
      classStatus: j.enumOf('classStatus', ClassStatus.values),
      courseTitle: j.str('courseTitle'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      mentorName: j.objOrNull('mentor')?.nonEmpty('displayName'),
      roomName: j.strOrNull('roomName'),
      access: j.enumOf('accessMode', ScheduleAccess.values),
    );
    if (!s.endsAt.isAfter(s.startsAt)) j.fail();
    return s;
  }
}

class ScheduleWeek {
  const ScheduleWeek({required this.items, required this.timeZone, required this.asOf});
  final List<ScheduleSession> items;
  final String timeZone;
  final DateTime asOf;
}
