// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../../core/utils/format.dart';
import '../../courses/courses_models.dart';
import '../schedule/schedule_models.dart';

enum MentorClassStatus { DRAFT, OPEN, IN_PROGRESS, COMPLETED, CANCELLED }

enum MentorClassAssignment { PRIMARY, SUBSTITUTE, BOTH }

enum MentorClassFilter { PRIMARY, SUBSTITUTE, ANY }

enum MentorClassScope { CLASS, SESSION }

enum MentorClassGroup { active, upcoming, ended, cancelled }

enum MentorUnitStatus { LOCKED, OPEN, COMPLETED }

MentorClassGroup mentorClassGroup(MentorClassStatus status) => switch (status) {
  MentorClassStatus.IN_PROGRESS => MentorClassGroup.active,
  MentorClassStatus.OPEN || MentorClassStatus.DRAFT => MentorClassGroup.upcoming,
  MentorClassStatus.COMPLETED => MentorClassGroup.ended,
  MentorClassStatus.CANCELLED => MentorClassGroup.cancelled,
};

class MentorClass {
  const MentorClass({
    required this.id,
    required this.courseId,
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.mode,
    required this.maxStudents,
    required this.availableSeats,
    required this.mentor,
    required this.status,
    required this.assignment,
    required this.scope,
  });
  final String id, courseId, code, name, startDate, endDate;
  final DeliveryMode mode;
  final int maxStudents, availableSeats;
  final TeachingPerson mentor;
  final MentorClassStatus status;
  final MentorClassAssignment assignment;
  final MentorClassScope scope;

  factory MentorClass.fromJson(Json j) {
    final max = j.integer('maxStudents'), seats = j.integer('availableSeats');
    final start = j.day('startDate'), end = j.day('endDate');
    if (max < 1 || seats < 0 || seats > max || start.compareTo(end) > 0) {
      j.fail();
    }
    final assignment = j.enumOf('assignmentType', MentorClassAssignment.values);
    final scope = j.enumOf('accessScope', MentorClassScope.values);
    if ((assignment == MentorClassAssignment.SUBSTITUTE) != (scope == MentorClassScope.SESSION)) {
      j.fail();
    }
    return MentorClass(
      id: j.uuid('id'),
      courseId: j.uuid('courseId'),
      code: j.nonEmpty('code'),
      name: j.nonEmpty('name'),
      startDate: start,
      endDate: end,
      mode: j.enumOf('deliveryMode', DeliveryMode.values),
      maxStudents: max,
      availableSeats: seats,
      mentor: TeachingPerson.fromJson(j.obj('mentor')),
      status: j.enumOf('status', MentorClassStatus.values),
      assignment: assignment,
      scope: scope,
    );
  }
}

class MentorWorkspace {
  const MentorWorkspace({
    required this.id,
    required this.code,
    required this.name,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    required this.scope,
    required this.assignment,
    required this.readonly,
    required this.readClass,
    required this.readRoster,
    required this.readReports,
    required this.authorMaterials,
    required this.unitCount,
    required this.sessionCount,
    required this.timeZone,
    required this.asOf,
  });
  final String id, code, name, courseId, courseTitle, timeZone;
  final MentorClassStatus status;
  final MentorClassScope scope;
  final MentorClassAssignment assignment;
  final bool readonly, readClass, readRoster, readReports, authorMaterials;
  final int unitCount, sessionCount;
  final DateTime asOf;
  bool get primary => scope == MentorClassScope.CLASS && assignment != MentorClassAssignment.SUBSTITUTE;
  factory MentorWorkspace.fromJson(Json j, String classId) {
    final id = j.uuid('id'), count = j.integer('visibleUnitCount'), sessions = j.integer('visibleSessionCount');
    final zone = j.nonEmpty('timeZone'), caps = j.obj('capabilities'), course = j.obj('course');
    if (id != classId || j.uuid('classId') != classId || count < 0 || sessions < 0 || !Dates.isValidZone(zone)) {
      j.fail();
    }
    final scope = j.enumOf('accessScope', MentorClassScope.values);
    final assignment = j.enumOf('assignmentType', MentorClassAssignment.values);
    if ((scope == MentorClassScope.SESSION) != (assignment == MentorClassAssignment.SUBSTITUTE)) {
      j.fail();
    }
    return MentorWorkspace(
      id: id,
      code: j.str('code'),
      name: j.str('name'),
      courseId: course.uuid('id'),
      courseTitle: course.str('title'),
      status: j.enumOf('status', MentorClassStatus.values),
      scope: scope,
      assignment: assignment,
      readonly: j.boolean('readonly'),
      readClass: caps.boolean('readClass'),
      readRoster: caps.boolean('readClassRoster'),
      readReports: caps.boolean('readClassReports'),
      authorMaterials: caps.boolean('authorMaterials'),
      unitCount: count,
      sessionCount: sessions,
      timeZone: zone,
      asOf: j.dateTime('asOf'),
    );
  }
}

class MentorWorkspaceSession {
  const MentorWorkspaceSession({required this.session, required this.readContext, required this.writeNotes});
  final TeachingSession session;
  final bool readContext, writeNotes;
  factory MentorWorkspaceSession.fromJson(Json j) => MentorWorkspaceSession(
    session: TeachingSession.fromJson(j),
    readContext: j.obj('capabilities').boolean('readSessionContext'),
    writeNotes: j.obj('capabilities').boolean('writeTeachingNotes'),
  );
}

class MentorUnit {
  const MentorUnit({
    required this.id,
    required this.classId,
    required this.courseUnitId,
    required this.title,
    required this.position,
    required this.status,
    required this.unlockAt,
  });
  final String id, classId, courseUnitId, title;
  final int position;
  final MentorUnitStatus status;
  final DateTime? unlockAt;
  factory MentorUnit.fromJson(Json j) {
    final position = j.integer('position');
    if (position < 1) j.fail();
    return MentorUnit(
      id: j.uuid('id'),
      classId: j.uuid('classId'),
      courseUnitId: j.uuid('courseUnitId'),
      title: j.str('title'),
      position: position,
      status: j.enumOf('status', MentorUnitStatus.values),
      unlockAt: j.dateTimeOrNull('unlockAt'),
    );
  }
}

class MentorSessionSlot {
  const MentorSessionSlot({
    required this.id,
    required this.unitId,
    required this.title,
    required this.number,
    required this.status,
  });
  final String id, unitId, title;
  final int number;
  final TeachingStatus status;
  factory MentorSessionSlot.fromJson(Json j) {
    final number = j.integer('sessionNumber');
    if (number < 1) j.fail();
    return MentorSessionSlot(
      id: j.uuid('id'),
      unitId: j.uuid('classUnitId'),
      title: j.str('title'),
      number: number,
      status: j.enumOf('status', TeachingStatus.values),
    );
  }
}

class MentorClassOverview {
  MentorClassOverview({
    required this.workspace,
    required List<MentorWorkspaceSession> sessions,
    required this.enrollmentCount,
    this.nextRoom,
    this.roomKnown = false,
    this.roomError,
  }) : sessions = List.unmodifiable(sessions);
  final MentorWorkspace workspace;
  final List<MentorWorkspaceSession> sessions;
  final int? enrollmentCount;
  final String? nextRoom;
  final bool roomKnown;
  final Object? roomError;
  MentorWorkspaceSession? roomToday(DateTime now) {
    final today = Dates.localDay(now, workspace.timeZone);
    final rows =
        sessions
            .where(
              (row) =>
                  row.readContext &&
                  row.session.status != TeachingStatus.CANCELLED &&
                  Dates.localDay(row.session.startsAt, workspace.timeZone) == today,
            )
            .toList()
          ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));
    for (final status in [TeachingDisplayStatus.live, TeachingDisplayStatus.upcoming]) {
      for (final row in rows) {
        if (row.session.displayStatus(now) == status) {
          return row;
        }
      }
    }
    return rows.lastOrNull;
  }

  MentorWorkspaceSession? next(DateTime now) {
    final visible =
        sessions
            .where(
              (row) =>
                  [TeachingDisplayStatus.live, TeachingDisplayStatus.upcoming].contains(row.session.displayStatus(now)),
            )
            .toList()
          ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));
    for (final row in visible) {
      if (row.session.displayStatus(now) == TeachingDisplayStatus.live) {
        return row;
      }
    }
    return visible.isEmpty ? null : visible.first;
  }
}

class MentorClassDetail {
  MentorClassDetail({required this.overview, required List<MentorUnit> units, required List<MentorSessionSlot> slots})
    : units = List.unmodifiable(units),
      slots = List.unmodifiable(slots);
  final MentorClassOverview overview;
  final List<MentorUnit> units;
  final List<MentorSessionSlot> slots;
  MentorSessionSlot? slot(String id) {
    for (final slot in slots) {
      if (slot.id == id) return slot;
    }
    return null;
  }
}
