import '../../../core/network/json.dart';

typedef ReportRange = ({String from, String to});

enum ReportKind { attendance, progress, studentSummary, history, units }

String? reportRangeProblem(ReportRange r) {
  final a = DateTime.tryParse(r.from), b = DateTime.tryParse(r.to);
  if (a == null || b == null) return 'order';
  if (a.isAfter(b)) return 'order';
  return b.difference(a).inDays + 1 > 93 ? 'max' : null;
}

Map<String, Object?> reportRangeQuery(ReportRange? r) => r == null
    ? {}
    : {
        'from': '${r.from}T00:00:00+07:00',
        'to':
            '${DateTime.parse(r.to).add(const Duration(days: 1)).toIso8601String().substring(0, 10)}T00:00:00+07:00',
      };

class ReportCounts {
  ReportCounts(Json j)
    : present = j.integer('present'),
      absent = j.integer('absent'),
      unmarked = j.integer('unmarked'),
      excluded = j.integer('excluded'),
      makeupPending = j.integer('makeupPending'),
      eligible = j.integer('finalizedEligibleCount'),
      rate = j.has('rate') ? j.number('rate') : null {
    if ([
          present,
          absent,
          unmarked,
          excluded,
          makeupPending,
          eligible,
        ].any((n) => n < 0) ||
        (rate != null && (rate! < 0 || rate! > 100))) {
      j.fail();
    }
  }
  final int present, absent, unmarked, excluded, makeupPending, eligible;
  final double? rate;
}

class ReportEnrollment extends ReportCounts {
  ReportEnrollment(super.j)
    : id = j.uuid('enrollmentId'),
      studentId = j.obj('student').uuid('id'),
      name = j.obj('student').strOrNull('displayName');
  final String id, studentId;
  final String? name;
}

class ReportHistory {
  ReportHistory(Json j)
    : sessionId = j.uuid('sessionId'),
      enrollmentId = j.uuid('enrollmentId'),
      title = j.str('title'),
      startsAt = j.dateTime('startsAt'),
      status = j.str('sessionStatus'),
      attendance = j.strOrNull('attendanceStatus'),
      applicability = j.str('attendanceApplicability'),
      assignment = j.str('assignmentType'),
      credited = j.strOrNull('creditedAttendanceStatus') {
    if (![
          'SCHEDULED',
          'IN_PROGRESS',
          'COMPLETED',
          'CANCELLED',
        ].contains(status) ||
        attendance != null &&
            !['UNMARKED', 'PRESENT', 'ABSENT'].contains(attendance) ||
        ![
          'ELIGIBLE',
          'NOT_STARTED',
          'NOT_ELIGIBLE',
          'PAYMENT_PENDING',
          'LEGACY_NO_DATA',
          'MAKEUP_PENDING',
          'MAKEUP_CREDITED',
        ].contains(applicability) ||
        !['PRIMARY', 'SUBSTITUTE'].contains(assignment) ||
        credited != null && !['PRESENT', 'ABSENT'].contains(credited)) {
      j.fail();
    }
  }
  final String sessionId,
      enrollmentId,
      title,
      status,
      applicability,
      assignment;
  final String? attendance, credited;
  final DateTime startsAt;
}

class ReportProgress {
  ReportProgress(Json j)
    : id = j.uuid('enrollmentId'),
      studentId = j.uuid('studentId'),
      name = j.str('displayName'),
      stored = j.integer('storedUnitCount'),
      untracked = j.integer('untrackedUnitCount'),
      invalid = j.integer('invalidStoredUnitCount') {
    if ([stored, untracked, invalid].any((n) => n < 0)) j.fail();
  }
  final String id, studentId, name;
  final int stored, untracked, invalid;
}

class ReportUnit {
  ReportUnit(Json j)
    : enrollmentId = j.uuid('enrollmentId'),
      unitId = j.uuid('classUnitId'),
      tracking = j.str('trackingStatus'),
      status = j.strOrNull('status'),
      percent = j.strOrNull('progressPercent'),
      completedAt = j.dateTimeOrNull('completedAt'),
      quality = j.str('dataQuality') {
    if (!['STORED', 'UNTRACKED'].contains(tracking) ||
        status != null &&
            !['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'].contains(status) ||
        !['VALID', 'INVALID_PERCENT', 'UNTRACKED'].contains(quality)) {
      j.fail();
    }
  }
  final String enrollmentId, unitId, tracking, quality;
  final String? status, percent;
  final DateTime? completedAt;
}

class ReportData {
  const ReportData({
    this.enrollments = const [],
    this.history = const [],
    this.progress = const [],
    this.units = const [],
    this.summary,
    this.total = 0,
    this.page = 1,
    this.readonly = false,
    required this.asOf,
    required this.timeZone,
  });
  final List<ReportEnrollment> enrollments;
  final List<ReportHistory> history;
  final List<ReportProgress> progress;
  final List<ReportUnit> units;
  final ReportCounts? summary;
  final int total, page;
  final bool readonly;
  final DateTime asOf;
  final String timeZone;
  int get count =>
      enrollments.length + history.length + progress.length + units.length;
}

typedef ReportRequest = ({
  ReportKind kind,
  bool manager,
  String classId,
  String? studentId,
  ReportRange? range,
});
