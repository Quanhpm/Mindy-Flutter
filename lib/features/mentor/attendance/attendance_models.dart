// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../../core/network/api_error.dart';
import '../schedule/schedule_models.dart';

enum AttendanceStatus { UNMARKED, PRESENT, ABSENT }

enum AttendanceEntryType { REGULAR, MAKEUP }

enum AttendanceOperation { start, mark, bulk, sync, finalize }

class AttendancePermissions {
  const AttendancePermissions({
    required this.canStart,
    required this.canEdit,
    required this.canFinalize,
    required this.canSync,
    required this.canRecover,
    required this.canViewAudits,
  });
  final bool canStart, canEdit, canFinalize, canSync, canRecover, canViewAudits;
  factory AttendancePermissions.fromJson(Json j) => AttendancePermissions(
    canStart: j.boolean('canStart'),
    canEdit: j.boolean('canEditAttendance'),
    canFinalize: j.boolean('canFinalize'),
    canSync: j.boolean('canSyncRoster'),
    canRecover: j.boolean('canRecover'),
    canViewAudits: j.boolean('canViewAttendanceAudits'),
  );
}

class AttendanceTotals {
  const AttendanceTotals({required this.present, required this.absent, required this.unmarked, required this.eligible});
  final int present, absent, unmarked, eligible;
  factory AttendanceTotals.fromJson(Json j) {
    final present = j.integer('present'),
        absent = j.integer('absent'),
        unmarked = j.integer('unmarked'),
        eligible = j.integer('eligible');
    if ([present, absent, unmarked, eligible].any((n) => n < 0) || present + absent + unmarked != eligible) j.fail();
    return AttendanceTotals(present: present, absent: absent, unmarked: unmarked, eligible: eligible);
  }
  bool sameAs(AttendanceTotals other) =>
      present == other.present && absent == other.absent && unmarked == other.unmarked && eligible == other.eligible;
}

class AttendanceHeader {
  const AttendanceHeader({required this.session, required this.permissions, required this.totals});
  final TeachingSession session;
  final AttendancePermissions permissions;
  final AttendanceTotals totals;
  factory AttendanceHeader.fromJson(Json j, String sessionId) {
    final source = j.obj('session');
    final session = TeachingSession.fromJson(source);
    if (session.id != sessionId) j.fail();
    return AttendanceHeader(
      session: session,
      permissions: AttendancePermissions.fromJson(source.obj('permissions')),
      totals: AttendanceTotals.fromJson(j.obj('totals')),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.enrollmentId,
    required this.type,
    required this.placementId,
    required this.student,
    required this.status,
    required this.checkedInAt,
    required this.admittedAt,
  });
  final String id, enrollmentId;
  final AttendanceEntryType type;
  final String? placementId;
  final TeachingPerson student;
  final AttendanceStatus status;
  final DateTime? checkedInAt;
  final DateTime admittedAt;
  String get key => '${type.name}:${type == AttendanceEntryType.MAKEUP ? placementId : enrollmentId}';
  factory AttendanceRecord.fromJson(Json j) {
    final type = j.enumOf('entryType', AttendanceEntryType.values);
    final placement = j.uuidOrNull('makeupPlacementId');
    if ((type == AttendanceEntryType.MAKEUP) != (placement != null)) j.fail();
    return AttendanceRecord(
      id: j.uuid('attendanceId'),
      enrollmentId: j.uuid('enrollmentId'),
      type: type,
      placementId: placement,
      student: TeachingPerson.fromJson(j.obj('student')),
      status: j.enumOf('status', AttendanceStatus.values),
      checkedInAt: j.dateTimeOrNull('checkedInAt'),
      admittedAt: j.dateTime('admittedAt'),
    );
  }
}

class AttendanceRoster {
  AttendanceRoster({required this.header, required List<AttendanceRecord> records, required this.pendingPaymentCount})
    : records = List.unmodifiable(records);
  final AttendanceHeader header;
  final List<AttendanceRecord> records;
  final int pendingPaymentCount;
}

class AttendanceWrite {
  const AttendanceWrite({required this.header, required this.changedEnrollmentIds, required this.changedPlacementIds});
  final AttendanceHeader header;
  final List<String> changedEnrollmentIds, changedPlacementIds;
  factory AttendanceWrite.fromJson(Json j, String sessionId) => AttendanceWrite(
    header: AttendanceHeader.fromJson(j, sessionId),
    changedEnrollmentIds: j.uuidList('changedEnrollmentIds'),
    changedPlacementIds: j.uuidList('changedMakeupPlacementIds'),
  );
}

class AttendanceChange {
  const AttendanceChange({required this.record, required this.status});
  final AttendanceRecord record;
  final AttendanceStatus status;
  Map<String, Object?> get body => {
    if (record.type == AttendanceEntryType.MAKEUP)
      'makeupPlacementId': record.placementId
    else
      'enrollmentId': record.enrollmentId,
    'status': status.name,
  };
}

List<AttendanceChange> attendanceDiff(AttendanceRoster roster, Map<String, AttendanceStatus> draft) {
  final known = roster.records.map((record) => record.key).toSet();
  if (draft.keys.any((key) => !known.contains(key))) throw StateError('Bản nháp không thuộc roster hiện tại');
  return List.unmodifiable([
    for (final record in roster.records)
      if (draft.containsKey(record.key) && draft[record.key] != record.status)
        AttendanceChange(record: record, status: draft[record.key]!),
  ]);
}

List<List<AttendanceChange>> attendanceBatches(List<AttendanceChange> changes) => List.unmodifiable([
  for (var i = 0; i < changes.length; i += 100) List<AttendanceChange>.unmodifiable(changes.skip(i).take(100)),
]);

Map<String, Object?> attendanceBatchBody(List<AttendanceChange> batch, int version) => {
  'expectedVersion': version,
  'records': [
    for (final change in batch)
      if (change.record.type == AttendanceEntryType.REGULAR) change.body,
  ],
  if (batch.any((change) => change.record.type == AttendanceEntryType.MAKEUP))
    'guestRecords': [
      for (final change in batch)
        if (change.record.type == AttendanceEntryType.MAKEUP) change.body,
    ],
};

/// Chỉ thay nhãn lỗi, không suy quyền hay so sánh message của server.
String attendanceErrorKey(Object error) {
  if (error is! ApiError) return 'errors.generic';
  return switch (error.code) {
    'SESSION_VERSION_CONFLICT' => 'mentor.attendance.errors.conflict',
    'SESSION_STATE_CONFLICT' => 'mentor.attendance.errors.stateChanged',
    'ATTENDANCE_START_DAY_CLOSED' => 'mentor.attendance.errors.startClosed',
    'ATTENDANCE_EDIT_WINDOW_EXPIRED' => 'mentor.attendance.errors.expired',
    'IDEMPOTENCY_KEY_REUSED' => 'mentor.attendance.errors.keyReused',
    'ATTENDANCE_ENROLLMENT_NOT_ELIGIBLE' => 'mentor.attendance.errors.rosterChanged',
    'SESSION_ASSIGNMENT_REQUIRED' => 'mentor.session.accessLost',
    'CLASS_SESSION_NOT_FOUND' => 'mentor.attendance.errors.notFound',
    'CLASS_SESSION_OVERNIGHT_NOT_ALLOWED' => 'mentor.attendance.errors.invalidInput',
    'HTTP_ERROR' when error.status == 422 => 'mentor.attendance.errors.invalidInput',
    'NETWORK_ERROR' || 'NETWORK_UNAVAILABLE' => 'errors.NETWORK_UNAVAILABLE',
    _ => 'errors.generic',
  };
}
