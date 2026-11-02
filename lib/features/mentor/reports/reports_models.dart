// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../attendance/attendance_models.dart';
import '../classes/classes_models.dart';
import '../schedule/schedule_models.dart';

class MentorAttendanceCounts {
  const MentorAttendanceCounts({
    required this.present,
    required this.absent,
    required this.unmarked,
    required this.excluded,
    required this.makeupPending,
    required this.finalizedEligible,
    required this.rate,
  });
  final int present, absent, unmarked, excluded, makeupPending, finalizedEligible;
  final double? rate;
  factory MentorAttendanceCounts.fromJson(Json j) {
    final p = j.integer('present'),
        a = j.integer('absent'),
        u = j.integer('unmarked'),
        e = j.integer('excluded'),
        m = j.integer('makeupPending'),
        f = j.integer('finalizedEligibleCount');
    final rate = j.has('rate') ? j.number('rate') : null;
    if ([p, a, u, e, m, f].any((n) => n < 0) ||
        f != p + a ||
        (rate == null) != (f == 0) ||
        (rate != null && (rate < 0 || rate > 100))) {
      j.fail();
    }
    return MentorAttendanceCounts(
      present: p,
      absent: a,
      unmarked: u,
      excluded: e,
      makeupPending: m,
      finalizedEligible: f,
      rate: rate,
    );
  }
}

class EnrollmentAttendance {
  const EnrollmentAttendance({required this.enrollmentId, required this.student, required this.counts});
  final String enrollmentId;
  final TeachingPerson student;
  final MentorAttendanceCounts counts;
  factory EnrollmentAttendance.fromJson(Json j) => EnrollmentAttendance(
    enrollmentId: j.uuid('enrollmentId'),
    student: TeachingPerson.fromJson(j.obj('student')),
    counts: MentorAttendanceCounts.fromJson(j),
  );
}

class ClassAttendanceSummary {
  ClassAttendanceSummary({
    required this.classId,
    required this.timeZone,
    required this.readonly,
    required this.asOf,
    required List<EnrollmentAttendance> items,
  }) : items = List.unmodifiable(items);
  final String classId, timeZone;
  final bool readonly;
  final DateTime asOf;
  final List<EnrollmentAttendance> items;
}

/// Tổng hợp hiển thị từ counts server, không đổi tín chỉ hay cộng các buổi đã loại trừ.
double? weightedAttendance(Iterable<MentorAttendanceCounts> values) {
  var present = 0, eligible = 0;
  for (final value in values) {
    present += value.present;
    eligible += value.finalizedEligible;
  }
  return eligible == 0 ? null : present * 100 / eligible;
}

bool needsAttention(double? rate) => rate != null && rate < 80;

class SessionAttendanceReport {
  const SessionAttendanceReport({required this.row, this.totals, this.error, this.denied = false});
  final MentorWorkspaceSession row;
  final AttendanceTotals? totals;
  final Object? error;
  final bool denied;
  double? get rate =>
      totals == null || totals!.eligible == 0 || totals!.unmarked > 0 ? null : totals!.present * 100 / totals!.eligible;
}

class MentorClassReport {
  MentorClassReport({required this.workspace, required this.summary, required List<SessionAttendanceReport> sessions})
    : sessions = List.unmodifiable(sessions);
  final MentorWorkspace workspace;
  final ClassAttendanceSummary summary;
  final List<SessionAttendanceReport> sessions;
}

enum AttendanceApplicability {
  ELIGIBLE,
  NOT_STARTED,
  NOT_ELIGIBLE,
  PAYMENT_PENDING,
  LEGACY_NO_DATA,
  MAKEUP_PENDING,
  MAKEUP_CREDITED,
}

class StudentAttendanceHistoryRow {
  const StudentAttendanceHistoryRow({
    required this.sessionId,
    required this.enrollmentId,
    required this.rootId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.sessionStatus,
    required this.status,
    required this.applicability,
    required this.excluded,
    required this.creditedStatus,
  });
  final String sessionId, enrollmentId, rootId, title;
  final DateTime startsAt, endsAt;
  final TeachingStatus sessionStatus;
  final AttendanceStatus? status, creditedStatus;
  final AttendanceApplicability applicability;
  final bool excluded;
  String get key => '$enrollmentId:$sessionId';
  factory StudentAttendanceHistoryRow.fromJson(Json j) {
    final from = j.dateTime('startsAt'), to = j.dateTime('endsAt');
    if (!to.isAfter(from)) j.fail();
    final credit = j.has('creditedAttendanceStatus')
        ? j.enumOf('creditedAttendanceStatus', AttendanceStatus.values)
        : null;
    if (credit == AttendanceStatus.UNMARKED) j.fail();
    // Những ID học bù vẫn được kiểm tra, dù UI dùng nhãn applicability thay cho ID kỹ thuật.
    for (final key in ['makeupForSessionId', 'makeupRootSessionId', 'makeupPlacementId', 'creditSessionId']) {
      j.uuidOrNull(key);
    }
    if (j.has('effectiveMentor')) {
      TeachingPerson.fromJson(j.obj('effectiveMentor'));
    }
    j.enumOf('assignmentType', TeachingAssignment.values);
    return StudentAttendanceHistoryRow(
      sessionId: j.uuid('sessionId'),
      enrollmentId: j.uuid('enrollmentId'),
      rootId: j.uuid('rootSessionId'),
      title: j.str('title'),
      startsAt: from,
      endsAt: to,
      sessionStatus: j.enumOf('sessionStatus', TeachingStatus.values),
      status: j.has('attendanceStatus') ? j.enumOf('attendanceStatus', AttendanceStatus.values) : null,
      applicability: j.enumOf('attendanceApplicability', AttendanceApplicability.values),
      excluded: j.boolean('excluded'),
      creditedStatus: credit,
    );
  }
}

class StudentAttendanceHistory {
  StudentAttendanceHistory({required this.timeZone, required List<StudentAttendanceHistoryRow> items})
    : items = List.unmodifiable(items);
  final String timeZone;
  final List<StudentAttendanceHistoryRow> items;
}

class StudentAttendanceSummary {
  const StudentAttendanceSummary({required this.counts, required this.timeZone});
  final MentorAttendanceCounts counts;
  final String timeZone;
}
