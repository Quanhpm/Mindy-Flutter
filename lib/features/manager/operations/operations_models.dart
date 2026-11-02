// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../mentor/schedule/schedule_models.dart';
import '../../my_classes/my_classes_models.dart';
import '../manager_models.dart';

class ManagedTeachingClass {
  const ManagedTeachingClass(this.id, this.code, this.name, this.mentor, this.version, this.status);
  final String id, code, name;
  final TeachingPerson mentor;
  final int version;
  final ClassStatus status;
  factory ManagedTeachingClass.fromJson(Json j) => ManagedTeachingClass(
    j.uuid('id'),
    j.str('code'),
    j.str('name'),
    TeachingPerson.fromJson(j.obj('primaryMentor')),
    positive(j, 'assignmentVersion'),
    j.enumOf('status', ClassStatus.values),
  );
}

class ManagedTimetable {
  const ManagedTimetable(this.info, this.sessions);
  final ManagedTeachingClass info;
  final List<TeachingSession> sessions;
}

class AvailableMentor {
  const AvailableMentor(this.id, this.name, this.current);
  final String id, name;
  final bool current;
  factory AvailableMentor.fromJson(Json j) =>
      AvailableMentor(j.uuid('id'), j.str('displayName'), j.boolean('isCurrent'));
}

class AvailableMentors {
  const AvailableMentors(this.items, this.version, this.zone, this.affected);
  final List<AvailableMentor> items;
  final int version, affected;
  final String zone;
}

typedef AssignmentTarget = ({String id, bool session});

class AssignmentResult {
  const AssignmentResult(this.id, this.version);
  final String id;
  final int version;
}

class IncompleteTeaching {
  const IncompleteTeaching(this.session, this.issue, this.expired);
  final TeachingSession session;
  final String issue;
  final bool? expired;
  factory IncompleteTeaching.fromJson(Json j) {
    final issue = j.str('issue');
    if (!['OVERDUE_NOT_STARTED', 'STARTED_NOT_FINALIZED'].contains(issue)) j.fail();
    return IncompleteTeaching(
      TeachingSession.fromJson(j.obj('session')),
      issue,
      j.has('deadlineExpired') ? j.boolean('deadlineExpired') : null,
    );
  }
}

class ManagerAttendanceRow {
  const ManagerAttendanceRow(
    this.id,
    this.student,
    this.present,
    this.absent,
    this.unmarked,
    this.excluded,
    this.pending,
    this.rate,
  );
  final String id;
  final TeachingPerson student;
  final int present, absent, unmarked, excluded, pending;
  final double? rate;
  factory ManagerAttendanceRow.fromJson(Json j) {
    final rate = j.has('rate') ? j.number('rate') : null;
    if (rate != null && (rate < 0 || rate > 100)) j.fail();
    countValue(j, 'finalizedEligibleCount');
    return ManagerAttendanceRow(
      j.uuid('enrollmentId'),
      TeachingPerson.fromJson(j.obj('student')),
      countValue(j, 'present'),
      countValue(j, 'absent'),
      countValue(j, 'unmarked'),
      countValue(j, 'excluded'),
      countValue(j, 'makeupPending'),
      rate,
    );
  }
}

class ManagerAttendanceAudit {
  const ManagerAttendanceAudit(
    this.id,
    this.actor,
    this.oldStatus,
    this.newStatus,
    this.action,
    this.reason,
    this.at,
    this.version,
  );
  final String id, action, newStatus;
  final String? oldStatus, reason;
  final TeachingPerson actor;
  final DateTime at;
  final int version;
  factory ManagerAttendanceAudit.fromJson(Json j) {
    final old = j.strOrNull('oldStatus'), next = j.str('newStatus'), action = j.str('action');
    if ((old != null && !['UNMARKED', 'PRESENT', 'ABSENT'].contains(old)) ||
        !['UNMARKED', 'PRESENT', 'ABSENT'].contains(next) ||
        !['ADMIT', 'MARK', 'FINALIZE', 'CORRECT', 'RECOVER'].contains(action)) {
      j.fail();
    }
    return ManagerAttendanceAudit(
      j.uuid('id'),
      TeachingPerson.fromJson(j.obj('actor')),
      old,
      next,
      action,
      j.strOrNull('reason'),
      j.dateTime('occurredAt'),
      positive(j, 'version'),
    );
  }
}

enum MakeupConflictStatus { OPEN, MAKEUP_ASSIGNED, RESOLVED }

class MakeupConflict {
  const MakeupConflict(
    this.id,
    this.student,
    this.source,
    this.status,
    this.version,
    this.placementId,
    this.placementVersion,
    this.intervals,
  );
  final String id;
  final TeachingPerson student;
  final TeachingSession source;
  final MakeupConflictStatus status;
  final int version;
  final String? placementId;
  final int? placementVersion;
  final List<({String id, DateTime start, DateTime end})> intervals;
  factory MakeupConflict.fromJson(Json j) {
    final pv = j.has('makeupPlacementVersion') ? positive(j, 'makeupPlacementVersion') : null;
    final intervals = j.list('conflictingIntervals', (v) {
      final start = v.dateTime('startsAt'), end = v.dateTime('endsAt');
      if (!end.isAfter(start)) v.fail();
      return (id: v.uuid('sessionId'), start: start, end: end);
    });
    return MakeupConflict(
      j.uuid('id'),
      TeachingPerson.fromJson(j.obj('student')),
      TeachingSession.fromJson(j.obj('sourceSession')),
      j.enumOf('status', MakeupConflictStatus.values),
      positive(j, 'version'),
      j.uuidOrNull('makeupPlacementId'),
      pv,
      List.unmodifiable(intervals),
    );
  }
}

class MakeupCandidate {
  const MakeupCandidate(this.session, this.capacity);
  final TeachingSession session;
  final int capacity;
  factory MakeupCandidate.fromJson(Json j) =>
      MakeupCandidate(TeachingSession.fromJson(j.obj('session')), countValue(j, 'remainingCapacity'));
}

class MakeupDecision {
  const MakeupDecision(this.id, this.conflictId, this.version, this.status);
  final String id, conflictId, status;
  final int version;
  factory MakeupDecision.fromJson(Json j) {
    final p = j.has('placement') ? j.obj('placement') : j, status = p.str('status');
    if (!['ASSIGNED', 'COMPLETED', 'CANCELLED', 'NEEDS_REASSIGNMENT'].contains(status)) j.fail();
    return MakeupDecision(p.uuid('id'), p.uuid('conflictId'), positive(p, 'version'), status);
  }
}
