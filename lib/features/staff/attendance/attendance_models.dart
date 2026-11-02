// ignore_for_file: constant_identifier_names
import 'package:flutter/foundation.dart';

import '../shared/remote.dart';
import '../teaching/teaching_models.dart';

/// Clone `modules/attendance/types.ts`.
enum Mark { UNMARKED, PRESENT, ABSENT }

enum EntryType { REGULAR, MAKEUP }

enum Basis { PAID_BEFORE_START, CASH_LATE_ADMISSION }

enum Issue { OVERDUE_NOT_STARTED, STARTED_NOT_FINALIZED }

enum AuditAction { ADMIT, MARK, FINALIZE, CORRECT, RECOVER }

@immutable
class AttendanceRow {
  const AttendanceRow({
    required this.id,
    required this.enrollmentId,
    required this.makeupPlacementId,
    required this.name,
    required this.entryType,
    required this.status,
    required this.checkedInAt,
  });

  final String id;
  final String enrollmentId;
  final String? makeupPlacementId;
  final String? name;
  final EntryType entryType;
  final Mark status;
  final DateTime? checkedInAt;
}

@immutable
class Permissions {
  const Permissions({
    this.canStart = false,
    this.canEditAttendance = false,
    this.canSyncRoster = false,
    this.canFinalize = false,
    this.canRecover = false,
    this.canViewAttendanceAudits = false,
  });

  final bool canStart;
  final bool canEditAttendance;
  final bool canSyncRoster;
  final bool canFinalize;
  final bool canRecover;
  final bool canViewAttendanceAudits;
}

@immutable
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.classTitle,
    required this.title,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.actualStartedAt,
    required this.actualEndedAt,
    required this.effectiveMentor,
    required this.isEffectiveMentor,
    required this.editableUntil,
    required this.asOf,
    required this.version,
    required this.permissions,
  });

  final String id;
  final String classId;
  final String classTitle;
  final String title;
  final SessionStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? actualStartedAt;
  final DateTime? actualEndedAt;
  final String? effectiveMentor;
  final bool isEffectiveMentor;

  /// null = backend không trả hạn sửa.
  final DateTime? editableUntil;
  final DateTime asOf;
  final int version;
  final Permissions permissions;
}

@immutable
class Totals {
  const Totals({
    required this.eligible,
    required this.present,
    required this.absent,
    required this.unmarked,
    this.pendingPaymentCount,
  });
  final int eligible;
  final int present;
  final int absent;
  final int unmarked;
  final int? pendingPaymentCount;

  int of(String key) => switch (key) {
    'present' => present,
    'absent' => absent,
    'unmarked' => unmarked,
    _ => eligible,
  };
}

@immutable
class Note {
  const Note({
    required this.content,
    required this.nextSteps,
    required this.updatedAt,
  });
  final String content;
  final String nextSteps;
  final DateTime updatedAt;
}

@immutable
class RecoveryStudent {
  const RecoveryStudent({
    required this.id,
    required this.name,
    required this.enrollmentStatus,
    required this.paymentType,
    this.paidAt,
  });
  final String id;
  final String? name;
  final EnrollmentStatus enrollmentStatus;
  final PaymentMethod paymentType;
  final DateTime? paidAt;
}

@immutable
class RecoveryRecord {
  const RecoveryRecord({
    required this.enrollmentId,
    required this.status,
    required this.admissionBasis,
  });
  final String enrollmentId;
  final Mark status;
  final Basis admissionBasis;

  Map<String, Object?> toJson() => {
    'enrollmentId': enrollmentId,
    'status': status.name,
    'admissionBasis': admissionBasis.name,
  };
}

@immutable
class Evidence {
  const Evidence({
    required this.evidenceNote,
    required this.admissionBasis,
    required this.paidAt,
    required this.oldSessionStatus,
    required this.newSessionStatus,
    required this.oldActualStartedAt,
    required this.newActualStartedAt,
    required this.oldActualEndedAt,
    required this.newActualEndedAt,
  });
  final String evidenceNote;
  final Basis admissionBasis;
  final DateTime paidAt;
  final SessionStatus oldSessionStatus;
  final SessionStatus newSessionStatus;
  final DateTime? oldActualStartedAt;
  final DateTime newActualStartedAt;
  final DateTime? oldActualEndedAt;
  final DateTime newActualEndedAt;
}

@immutable
class Audit {
  const Audit({
    required this.id,
    required this.attendanceId,
    required this.enrollmentId,
    required this.makeupPlacementId,
    required this.entryType,
    required this.action,
    required this.occurredAt,
    required this.oldStatus,
    required this.newStatus,
    required this.actor,
    required this.reason,
    required this.recoveryEvidence,
  });
  final String id;
  final String attendanceId;
  final String enrollmentId;
  final String? makeupPlacementId;
  final EntryType entryType;
  final AuditAction action;
  final DateTime occurredAt;
  final Mark? oldStatus;
  final Mark newStatus;
  final String? actor;
  final String? reason;
  final Evidence? recoveryEvidence;
}

@immutable
class Incomplete {
  const Incomplete({
    required this.id,
    required this.session,
    required this.issue,
    required this.deadlineExpired,
  });
  final String id;
  final AttendanceSession session;
  final Issue issue;
  final bool? deadlineExpired;
}

@immutable
class StudentEnrollmentRef {
  const StudentEnrollmentRef({
    required this.classId,
    required this.enrollmentId,
    this.makeupPlacementId,
  });
  final String classId;
  final String enrollmentId;
  final String? makeupPlacementId;
}

@immutable
class ManagementStudent {
  const ManagementStudent({
    required this.id,
    required this.name,
    this.enrollments = const [],
  });
  final String id;
  final String? name;
  final List<StudentEnrollmentRef> enrollments;
}

@immutable
class AttendanceData {
  const AttendanceData({
    this.managementStudents = const [],
    this.sessions = const [],
    this.session,
    this.rows = const [],
    this.total = 0,
    this.totals,
    this.note,
    this.noteVersion = 0,
    this.incomplete = const [],
    this.audits = const [],
    this.students = const [],
    this.classes = const [],
  });

  final List<ManagementStudent> managementStudents;
  final List<AttendanceSession> sessions;
  final AttendanceSession? session;
  final List<AttendanceRow> rows;
  final int total;
  final Totals? totals;
  final Note? note;
  final int noteVersion;
  final List<Incomplete> incomplete;
  final List<Audit> audits;
  final List<RecoveryStudent> students;

  /// Chỉ dùng id, name, code, status, mentor, ngày, hình thức, chỗ (`Pick<TeachingClass>` của RN).
  final List<TeachingClass> classes;

  AttendanceData copyWith({
    List<ManagementStudent>? managementStudents,
    List<AttendanceSession>? sessions,
    List<AttendanceRow>? rows,
    List<Incomplete>? incomplete,
    List<Audit>? audits,
    List<RecoveryStudent>? students,
    List<TeachingClass>? classes,
  }) => AttendanceData(
    managementStudents: managementStudents ?? this.managementStudents,
    sessions: sessions ?? this.sessions,
    session: session,
    rows: rows ?? this.rows,
    total: total,
    totals: totals,
    note: note,
    noteVersion: noteVersion,
    incomplete: incomplete ?? this.incomplete,
    audits: audits ?? this.audits,
    students: students ?? this.students,
    classes: classes ?? this.classes,
  );

  /// Gộp trang sau (`load(next > 1)` của useAttendanceQuery).
  AttendanceData mergeNext(AttendanceData next) {
    final students =
        mergeById(
          managementStudents,
          next.managementStudents,
          (e) => e.id,
        ).map((s) {
          final old = managementStudents.where((o) => o.id == s.id).firstOrNull;
          return ManagementStudent(
            id: s.id,
            name: s.name,
            enrollments: mergeById(
              old?.enrollments ?? const [],
              s.enrollments,
              (e) => e.enrollmentId,
            ),
          );
        }).toList();
    return AttendanceData(
      managementStudents: students,
      sessions: mergeById(sessions, next.sessions, (e) => e.id),
      session: next.session,
      rows: mergeById(rows, next.rows, (e) => e.id),
      total: next.total,
      totals: next.totals,
      note: next.note,
      noteVersion: next.noteVersion,
      incomplete: mergeById(incomplete, next.incomplete, (e) => e.id),
      audits: mergeById(audits, next.audits, (e) => e.id),
      students: mergeById(this.students, next.students, (e) => e.id),
      classes: mergeById(classes, next.classes, (e) => e.id),
    );
  }

  /// Số phần tử của danh sách chính theo loại request (dùng khi đọc hết mọi trang).
  int countFor(AttendanceKind kind) => switch (kind) {
    AttendanceKind.managerSessions => sessions.length,
    AttendanceKind.audits => audits.length,
    AttendanceKind.incomplete => incomplete.length,
    AttendanceKind.recoveryStudents => students.length,
    AttendanceKind.managementStudents => managementStudents.length,
    AttendanceKind.classes => classes.length,
    _ => rows.length,
  };
}

enum AttendanceKind {
  context,
  attendance,
  candidates,
  note,
  incomplete,
  audits,
  recoveryStudents,
  managerSessions,
  classes,
  managementStudents,
}

enum ManagerSessionMode { correction, history, finalize }

@immutable
class AttendanceRequest {
  const AttendanceRequest({
    required this.kind,
    required this.role,
    this.studentId,
    this.mode,
    this.status,
    this.sessionId,
    this.page = 1,
    this.pageSize = 20,
    this.issue,
    this.classId,
    this.enrollmentId,
    this.makeupPlacementId,
    this.all = false,
  });

  final AttendanceKind kind;
  final TeachingRole role;
  final String? studentId;
  final ManagerSessionMode? mode;
  final SessionStatus? status;
  final String? sessionId;
  final int page;
  final int pageSize;
  final Issue? issue;
  final String? classId;
  final String? enrollmentId;
  final String? makeupPlacementId;

  /// `useAttendanceQuery(request, enabled, all = true)`: đọc hết mọi trang.
  final bool all;

  AttendanceRequest withPage(int value) => AttendanceRequest(
    kind: kind,
    role: role,
    studentId: studentId,
    mode: mode,
    status: status,
    sessionId: sessionId,
    page: value,
    pageSize: pageSize,
    issue: issue,
    classId: classId,
    enrollmentId: enrollmentId,
    makeupPlacementId: makeupPlacementId,
    all: all,
  );

  List<Object?> get _fields => [
    kind,
    role,
    studentId,
    mode,
    status,
    sessionId,
    page,
    pageSize,
    issue,
    classId,
    enrollmentId,
    makeupPlacementId,
    all,
  ];

  @override
  bool operator ==(Object other) =>
      other is AttendanceRequest && listEquals(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

enum IntentKind {
  start,
  save,
  bulk,
  sync,
  finalize,
  note,
  recover,
  updateSession,
}

@immutable
class AttendanceIntent {
  const AttendanceIntent({
    required this.key,
    required this.sessionId,
    required this.role,
    required this.expectedVersion,
    required this.kind,
    this.records,
    this.guestRecords,
    this.checked,
    this.reason,
    this.actualEndedAt,
    this.actualStartedAt,
    this.content,
    this.nextSteps,
    this.evidenceNote,
    this.recoveryRecords,
  });

  final String key;
  final String sessionId;
  final TeachingRole role;
  final int expectedVersion;
  final IntentKind kind;
  final List<({String enrollmentId, Mark status})>? records;
  final List<({String makeupPlacementId, Mark status})>? guestRecords;
  final bool? checked;
  final String? reason;
  final String? actualEndedAt;
  final String? actualStartedAt;
  final String? content;
  final String? nextSteps;
  final String? evidenceNote;
  final List<RecoveryRecord>? recoveryRecords;

  AttendanceIntent withKey(String value) => AttendanceIntent(
    key: value,
    sessionId: sessionId,
    role: role,
    expectedVersion: expectedVersion,
    kind: kind,
    records: records == null ? null : List.unmodifiable(records!),
    guestRecords: guestRecords == null
        ? null
        : List.unmodifiable(guestRecords!),
    checked: checked,
    reason: reason,
    actualEndedAt: actualEndedAt,
    actualStartedAt: actualStartedAt,
    content: content,
    nextSteps: nextSteps,
    evidenceNote: evidenceNote,
    recoveryRecords: recoveryRecords == null
        ? null
        : List.unmodifiable(recoveryRecords!),
  );
}

enum WriteKind { success, uncertain, error, denied, notFound }

@immutable
class WriteResult {
  const WriteResult(
    this.kind, {
    this.data,
    this.changed = 0,
    this.code,
    this.requestId,
  });
  final WriteKind kind;
  final AttendanceData? data;
  final int changed;
  final String? code;
  final String? requestId;

  bool get success => kind == WriteKind.success;
}

/// Bản nháp điểm danh: id hàng -> (trạng thái gốc, trạng thái mới, loại).
typedef DraftItem = ({Mark baseStatus, Mark status, EntryType entryType});
typedef Draft = Map<String, DraftItem>;
