// ignore_for_file: constant_identifier_names

import '../../../core/network/json.dart';
import '../../../core/utils/format.dart';

enum TeachingStatus { SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED }

enum TeachingAssignment { PRIMARY, SUBSTITUTE }

enum TeachingDisplayStatus { live, upcoming, ended, completed, cancelled }

class TeachingPerson {
  const TeachingPerson({required this.id, required this.displayName});
  final String id;
  final String? displayName;

  factory TeachingPerson.fromJson(Json j) => TeachingPerson(id: j.uuid('id'), displayName: j.strOrNull('displayName'));
}

/// TeachingSessionDto: không có tên lớp/phòng. Không dùng title thay cho tên lớp.
class TeachingSession {
  const TeachingSession({
    required this.id,
    required this.classId,
    required this.classUnitId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.primaryMentor,
    required this.effectiveMentor,
    required this.assignment,
    required this.version,
    required this.timeZone,
    required this.asOf,
    this.actualStartedAt,
    this.actualEndedAt,
    this.editableUntil,
    this.makeupForSessionId,
    this.makeupRootSessionId,
  });

  final String id, classId, classUnitId, title, timeZone;
  final DateTime startsAt, endsAt, asOf;
  final TeachingStatus status;
  final TeachingPerson primaryMentor;
  final TeachingPerson? effectiveMentor;
  final TeachingAssignment assignment;
  final int version;
  final DateTime? actualStartedAt, actualEndedAt, editableUntil;
  final String? makeupForSessionId, makeupRootSessionId;

  factory TeachingSession.fromJson(Json j) {
    final start = j.dateTime('startsAt');
    final end = j.dateTime('endsAt');
    final zone = j.nonEmpty('timeZone');
    final version = j.integer('version');
    if (!end.isAfter(start) || version < 1 || !Dates.isValidZone(zone)) j.fail();
    return TeachingSession(
      id: j.uuid('sessionId'),
      classId: j.uuid('classId'),
      classUnitId: j.uuid('classUnitId'),
      title: j.str('title'),
      startsAt: start,
      endsAt: end,
      status: j.enumOf('status', TeachingStatus.values),
      primaryMentor: TeachingPerson.fromJson(j.obj('primaryMentor')),
      effectiveMentor: j.has('effectiveMentor') ? TeachingPerson.fromJson(j.obj('effectiveMentor')) : null,
      assignment: j.enumOf('assignmentType', TeachingAssignment.values),
      version: version,
      timeZone: zone,
      asOf: j.dateTime('asOf'),
      actualStartedAt: j.dateTimeOrNull('actualStartedAt'),
      actualEndedAt: j.dateTimeOrNull('actualEndedAt'),
      editableUntil: j.dateTimeOrNull('editableUntil'),
      makeupForSessionId: j.uuidOrNull('makeupForSessionId'),
      makeupRootSessionId: j.uuidOrNull('makeupRootSessionId'),
    );
  }

  bool get isSubstitute => assignment == TeachingAssignment.SUBSTITUTE;

  /// Trạng thái trình bày không thay lifecycle server và không cấp quyền điểm danh.
  TeachingDisplayStatus displayStatus(DateTime now) => switch (status) {
    TeachingStatus.CANCELLED => TeachingDisplayStatus.cancelled,
    TeachingStatus.COMPLETED => TeachingDisplayStatus.completed,
    TeachingStatus.IN_PROGRESS => TeachingDisplayStatus.live,
    TeachingStatus.SCHEDULED =>
      now.isBefore(startsAt)
          ? TeachingDisplayStatus.upcoming
          : now.isBefore(endsAt)
          ? TeachingDisplayStatus.live
          : TeachingDisplayStatus.ended,
  };
}

/// Dữ liệu trình bày được ghép từ schedule + mentor/classes + context.
/// roomName null nghĩa là chưa có/không được cấp phòng, không dùng phòng giả.
class TeachingEntry {
  const TeachingEntry({required this.session, required this.className, required this.classCode, this.roomName});
  final TeachingSession session;
  final String className, classCode;
  final String? roomName;
}

class TeachingSchedule {
  TeachingSchedule({required List<TeachingEntry> entries, required this.timeZone})
    : entries = List.unmodifiable(entries);
  final List<TeachingEntry> entries;
  final String timeZone;

  List<TeachingEntry> onDay(String day) =>
      entries.where((e) => Dates.localDay(e.session.startsAt, timeZone) == day).toList()
        ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));

  List<TeachingEntry> get substitutes =>
      entries.where((e) => e.session.isSubstitute).toList()
        ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));

  /// Buổi cần vào trước, lịch sử mới nhất sau; không để buổi cũ che buổi hôm nay.
  List<TeachingEntry> substitutesForDisplay(DateTime now) {
    bool historical(TeachingEntry entry) => switch (entry.session.displayStatus(now)) {
      TeachingDisplayStatus.live || TeachingDisplayStatus.upcoming => false,
      _ => true,
    };
    return substitutes..sort((a, b) {
      final pastA = historical(a), pastB = historical(b);
      if (pastA != pastB) return pastA ? 1 : -1;
      return pastA
          ? b.session.startsAt.compareTo(a.session.startsAt)
          : a.session.startsAt.compareTo(b.session.startsAt);
    });
  }

  TeachingEntry? nextToday(DateTime now) {
    final today = onDay(Dates.localDay(now, timeZone));
    for (final entry in today) {
      if (entry.session.displayStatus(now) == TeachingDisplayStatus.live) return entry;
    }
    for (final entry in today) {
      if (entry.session.displayStatus(now) == TeachingDisplayStatus.upcoming) return entry;
    }
    return null;
  }
}
