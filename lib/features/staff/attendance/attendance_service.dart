import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';

/// Clone `services/attendanceService.ts` + `attendanceSchemas.ts`.
/// `read` ném [RemoteError]; `write` trả [WriteResult] (uncertain = có thể server đã nhận).
final attendanceServiceProvider = Provider(
  (ref) => AttendanceService(ref.watch(apiClientProvider), ref.watch(sessionProvider.select((s) => s.user?.id))),
);

const _err = 'INVALID_ATTENDANCE_RESPONSE';
const _uuidV4 = r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

class AttendanceService {
  AttendanceService(this._api, this._userId);
  final ApiClient _api;
  final String? _userId;

  // ---- schemas ----
  static int _count(Json j, String key) => j.integer(key) >= 0 ? j.integer(key) : j.fail();

  static ({String id, String? name}) _person(Json j) => (id: j.uuid('id'), name: j.strOrNull('displayName'));

  static Mark _mark(Json j, String key) => j.enumOf(key, Mark.values);

  static Permissions _permissions(Json j) => Permissions(
    canStart: j.boolean('canStart'),
    canEditAttendance: j.boolean('canEditAttendance'),
    canFinalize: j.boolean('canFinalize'),
    canSyncRoster: j.boolean('canSyncRoster'),
    canRecover: j.boolean('canRecover'),
    canViewAttendanceAudits: j.boolean('canViewAttendanceAudits'),
  );

  AttendanceSession _session(Json j, {Permissions permissions = const Permissions(), String classTitle = ''}) {
    final effective = j.objOrNull('effectiveMentor');
    final mentor = effective == null ? null : _person(effective);
    _person(j.obj('primaryMentor'));
    j.str('timeZone');
    j.enumOf('assignmentType', SessionAssignment.values);
    j.uuidOrNull('makeupForSessionId');
    j.uuidOrNull('makeupRootSessionId');
    final version = j.integer('version');
    if (version < 1) j.fail();
    return AttendanceSession(
      id: j.uuid('sessionId'),
      classId: j.uuid('classId'),
      classTitle: classTitle,
      title: j.str('title'),
      status: j.enumOf('status', SessionStatus.values),
      startsAt: j.dateTime('startsAt'),
      endsAt: j.dateTime('endsAt'),
      actualStartedAt: j.dateTimeOrNull('actualStartedAt'),
      actualEndedAt: j.dateTimeOrNull('actualEndedAt'),
      effectiveMentor: mentor?.name,
      isEffectiveMentor: _userId != null && mentor?.id == _userId,
      editableUntil: j.dateTimeOrNull('editableUntil'),
      asOf: j.dateTime('asOf'),
      version: version,
      permissions: permissions,
    );
  }

  AttendanceSession _attendanceSession(Json j) => _session(j, permissions: _permissions(j.obj('permissions')));

  static Totals _totals(Json j, {int? pending}) {
    final t = Totals(
      eligible: _count(j, 'eligible'),
      present: _count(j, 'present'),
      absent: _count(j, 'absent'),
      unmarked: _count(j, 'unmarked'),
      pendingPaymentCount: pending,
    );
    if (t.eligible != t.present + t.absent + t.unmarked) j.fail();
    return t;
  }

  static ({String enrollmentId, EntryType entryType, String? makeupPlacementId, String? name}) _identity(Json j) {
    final entry = j.enumOf('entryType', EntryType.values);
    final placement = j.uuidOrNull('makeupPlacementId');
    if ((entry == EntryType.MAKEUP) != (placement != null)) j.fail();
    return (
      enrollmentId: j.uuid('enrollmentId'),
      entryType: entry,
      makeupPlacementId: placement,
      name: _person(j.obj('student')).name,
    );
  }

  static Paged<T> _page<T>(Object? body, T Function(Json) parse) {
    final j = Json(body, _err);
    final p = Paged.fromJson(j, parse);
    if (p.page < 1 || p.pageSize < 1 || p.pageSize > 100 || p.total < 0 || p.items.length > p.pageSize) j.fail();
    if (p.items.length > p.total) j.fail();
    return p;
  }

  static Evidence _evidence(Json j) => Evidence(
    evidenceNote: j.str('evidenceNote'),
    admissionBasis: j.enumOf('admissionBasis', Basis.values),
    paidAt: j.dateTime('paidAt'),
    oldSessionStatus: j.enumOf('oldSessionStatus', SessionStatus.values),
    newSessionStatus: j.enumOf('newSessionStatus', SessionStatus.values),
    oldActualStartedAt: j.dateTimeOrNull('oldActualStartedAt'),
    newActualStartedAt: j.dateTime('newActualStartedAt'),
    oldActualEndedAt: j.dateTimeOrNull('oldActualEndedAt'),
    newActualEndedAt: j.dateTime('newActualEndedAt'),
  );

  static ({Note? note, int version, String sessionId}) _note(Json j) {
    final version = _count(j, 'version');
    final n = j.objOrNull('note');
    final note = n == null
        ? null
        : Note(content: n.str('content'), nextSteps: n.str('nextSteps'), updatedAt: n.dateTime('updatedAt'));
    if (n != null ? _count(n, 'version') != version : version != 0) j.fail();
    return (note: note, version: version, sessionId: j.uuid('sessionId'));
  }

  static TeachingClass _classRef(Json j) => TeachingClass(
    id: j.uuid('id'),
    name: j.str('name'),
    code: j.str('code'),
    status: j.enumOf('status', ClassStatus.values),
    scope: ClassScope.CLASS,
    assignment: ClassAssignment.PRIMARY,
  );

  // ---- transport ----
  Future<Object?> _get(String path, [Map<String, Object?> query = const {}]) async {
    try {
      final Object? body = await _api.get(path, query: query);
      return body;
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  Future<List<AttendanceSession>> _classTimetable(String classId) async {
    final result = <String, AttendanceSession>{};
    for (var page = 1; ; page++) {
      final j = Json(await _get('management/classes/${resourceId(classId)}', {'page': page, 'pageSize': 100}), _err);
      final klass = j.obj('class');
      final name = klass.str('name');
      if (klass.uuid('id') != classId) j.fail();
      final sessions = _page(j.raw('sessions'), (s) => _session(s, classTitle: name));
      if (sessions.items.any((s) => s.classId != classId) || sessions.page != page) j.fail();
      final previous = result.length;
      for (final s in sessions.items) {
        result[s.id] = s;
      }
      if (result.length >= sessions.total) return result.values.toList();
      if (result.length == previous) j.fail();
    }
  }

  Future<AttendanceData> read(AttendanceRequest r) async {
    try {
      return await _read(r);
    } on RemoteError {
      rethrow;
    } catch (e) {
      final error = RemoteError.from(e);
      throw error.offline ? error : RemoteError(RemoteFailure.error, code: 'INVALID_RESPONSE', requestId: error.requestId);
    }
  }

  Future<AttendanceData> _read(AttendanceRequest r) async {
    if (r.page < 1 || r.pageSize < 1 || r.pageSize > 100) {
      throw const RemoteError(RemoteFailure.error, code: 'INVALID_PAGE');
    }
    final paging = {'page': r.page, 'pageSize': r.pageSize};
    const managerOnly = [
      AttendanceKind.incomplete,
      AttendanceKind.audits,
      AttendanceKind.classes,
      AttendanceKind.managerSessions,
      AttendanceKind.managementStudents,
      AttendanceKind.recoveryStudents,
    ];
    if (r.role != TeachingRole.MANAGER && managerOnly.contains(r.kind)) throw const RemoteError(RemoteFailure.denied);
    switch (r.kind) {
      case AttendanceKind.attendance:
      case AttendanceKind.context:
        {
          final body = await _get(
            'class-sessions/${resourceId(r.sessionId)}/attendance',
            r.kind == AttendanceKind.context ? {'page': 1, 'pageSize': 1} : paging,
          );
          final j = Json(body, _err);
          final session = _attendanceSession(j.obj('session'));
          if (session.id != r.sessionId) throw const RemoteError(RemoteFailure.error, code: 'RESOURCE_MISMATCH');
          final rows = _page(body, (i) {
            final id = _identity(i);
            i.dateTime('admittedAt');
            return AttendanceRow(
              id: i.uuid('attendanceId'),
              enrollmentId: id.enrollmentId,
              makeupPlacementId: id.makeupPlacementId,
              entryType: id.entryType,
              name: id.name,
              status: _mark(i, 'status'),
              checkedInAt: i.dateTimeOrNull('checkedInAt'),
            );
          });
          return AttendanceData(
            session: session,
            totals: _totals(j.obj('totals'), pending: _count(j, 'pendingPaymentCount')),
            total: rows.total,
            rows: rows.items,
          );
        }
      case AttendanceKind.candidates:
        {
          final body = await _get('class-sessions/${resourceId(r.sessionId)}/attendance-candidates', paging);
          final j = Json(body, _err);
          if (j.raw('provisional') != true) j.fail();
          j.dateTime('asOf');
          final page = _page(body, (i) {
            final id = _identity(i);
            return AttendanceRow(
              id: id.makeupPlacementId ?? id.enrollmentId,
              enrollmentId: id.enrollmentId,
              makeupPlacementId: id.makeupPlacementId,
              entryType: id.entryType,
              name: id.name,
              status: Mark.UNMARKED,
              checkedInAt: null,
            );
          });
          return AttendanceData(total: page.total, rows: page.items);
        }
      case AttendanceKind.note:
        {
          if (r.role != TeachingRole.MENTOR) throw const RemoteError(RemoteFailure.denied);
          final n = _note(Json(await _get('class-sessions/${resourceId(r.sessionId)}/teaching-notes'), _err));
          if (n.sessionId != r.sessionId) throw const RemoteError(RemoteFailure.error, code: 'RESOURCE_MISMATCH');
          return AttendanceData(note: n.note, noteVersion: n.version);
        }
      case AttendanceKind.incomplete:
        {
          final body = await _get('management/class-sessions/incomplete', {
            ...paging,
            if (r.classId != null) 'classId': resourceId(r.classId),
            if (r.issue != null) 'issue': r.issue!.name,
          });
          final j = Json(body, _err);
          j.dateTime('asOf');
          j.str('timeZone');
          final page = _page(body, (i) {
            final session = _session(i.obj('session'));
            return Incomplete(
              id: session.id,
              session: session,
              issue: i.enumOf('issue', Issue.values),
              deadlineExpired: i.raw('deadlineExpired') == null ? null : i.boolean('deadlineExpired'),
            );
          });
          return AttendanceData(
            incomplete: page.items,
            total: page.total,
            sessions: [for (final i in page.items) i.session],
          );
        }
      case AttendanceKind.audits:
        {
          final page = _page(
            await _get('management/class-sessions/${resourceId(r.sessionId)}/attendance-audits', {
              ...paging,
              if (r.enrollmentId != null) 'enrollmentId': resourceId(r.enrollmentId),
              if (r.makeupPlacementId != null) 'makeupPlacementId': resourceId(r.makeupPlacementId),
            }),
            (i) {
              _count(i, 'version');
              i.uuidOrNull('recoveryAuditId');
              final evidence = i.objOrNull('recoveryEvidence');
              return Audit(
                id: i.uuid('id'),
                attendanceId: i.uuid('attendanceId'),
                enrollmentId: i.uuid('enrollmentId'),
                makeupPlacementId: i.uuidOrNull('makeupPlacementId'),
                entryType: i.enumOf('entryType', EntryType.values),
                action: i.enumOf('action', AuditAction.values),
                occurredAt: i.dateTime('occurredAt'),
                oldStatus: i.raw('oldStatus') == null ? null : _mark(i, 'oldStatus'),
                newStatus: _mark(i, 'newStatus'),
                actor: _person(i.obj('actor')).name,
                reason: i.strOrNull('reason'),
                recoveryEvidence: evidence == null ? null : _evidence(evidence),
              );
            },
          );
          return AttendanceData(audits: page.items, total: page.total);
        }
      case AttendanceKind.recoveryStudents:
        {
          final page = _page(
            await _get('manager/classes/${resourceId(r.classId)}/students', paging),
            (i) {
              i.enumOf('orderStatus', OrderStatus.values);
              i.dateTime('expiresAt');
              return RecoveryStudent(
                id: i.uuid('enrollmentId'),
                name: i.strOrNull('studentName'),
                enrollmentStatus: i.enumOf('enrollmentStatus', EnrollmentStatus.values),
                paymentType: i.enumOf('paymentType', PaymentMethod.values),
                paidAt: i.dateTimeOrNull('paidAt'),
              );
            },
          );
          return AttendanceData(students: page.items, total: page.total);
        }
      case AttendanceKind.managementStudents:
        {
          final page = _page(await _get('manager/students', paging), (i) {
            final p = _person(i);
            return ManagementStudent(id: p.id, name: p.name);
          });
          return AttendanceData(managementStudents: page.items, total: page.total);
        }
      case AttendanceKind.classes:
        {
          if (r.studentId != null) {
            final page = _page(
              await _get('manager/students/${resourceId(r.studentId)}/classes', paging),
              (i) => (enrollmentId: i.uuid('enrollmentId'), klass: _classRef(i.obj('class'))),
            );
            return AttendanceData(
              classes: [for (final i in page.items) i.klass],
              managementStudents: [
                ManagementStudent(
                  id: r.studentId!,
                  name: null,
                  enrollments: [
                    for (final i in page.items) StudentEnrollmentRef(classId: i.klass.id, enrollmentId: i.enrollmentId),
                  ],
                ),
              ],
              total: page.total,
            );
          }
          final page = _page(await _get('manager/classes', paging), (i) {
            final mentor = _person(i.obj('mentor'));
            return TeachingClass(
              id: i.uuid('id'),
              code: i.str('code'),
              name: i.str('name'),
              status: i.enumOf('status', ClassStatus.values),
              startDate: i.day('startDate'),
              endDate: i.day('endDate'),
              deliveryMode: i.enumOf('deliveryMode', DeliveryMode.values),
              maxStudents: _count(i, 'maxStudents'),
              availableSeats: _count(i, 'availableSeats'),
              mentor: mentor.name,
              assignment: i.enumOf('assignmentType', ClassAssignment.values),
              scope: i.enumOf('accessScope', ClassScope.values),
            );
          });
          return AttendanceData(classes: page.items, total: page.total);
        }
      case AttendanceKind.managerSessions:
        {
          final items = <AttendanceSession>[];
          if (r.classId != null) {
            items.addAll(await _classTimetable(r.classId!));
          } else {
            // Tiện ích toàn cục cần mọi buổi đang dạy: chỉ đọc lịch từng lớp khi mở tiện ích.
            final seen = <String>{};
            for (var page = 1; ; page++) {
              final index = _page(await _get('management/classes', {'page': page, 'pageSize': 100}), (i) {
                i.str('name');
                i.str('code');
                i.enumOf('status', ClassStatus.values);
                return i.uuid('id');
              });
              final previous = seen.length;
              for (final id in index.items) {
                if (!seen.add(id)) continue;
                items.addAll(await _classTimetable(id));
              }
              if (seen.length >= index.total) break;
              if (seen.length == previous) throw const RemoteError(RemoteFailure.error, code: 'INVALID_PAGE');
            }
          }
          final filtered = items
              .where(
                (s) =>
                    (r.status == null || s.status == r.status) &&
                    switch (r.mode) {
                      ManagerSessionMode.finalize => s.status == SessionStatus.IN_PROGRESS,
                      ManagerSessionMode.history => true,
                      _ => s.actualStartedAt != null,
                    },
              )
              .toList()
            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
          final start = (r.page - 1) * r.pageSize;
          return AttendanceData(
            total: filtered.length,
            sessions: filtered.sublist(start.clamp(0, filtered.length), (r.page * r.pageSize).clamp(0, filtered.length)),
          );
        }
    }
  }

  Future<WriteResult> write(AttendanceIntent intent) async {
    try {
      resourceId(intent.sessionId);
      if (!RegExp(_uuidV4, caseSensitive: false).hasMatch(intent.key)) {
        return const WriteResult(WriteKind.error, code: 'INVALID_KEY');
      }
      if (intent.kind == IntentKind.updateSession) return const WriteResult(WriteKind.error, code: 'UNAVAILABLE');
      if (intent.kind == IntentKind.note && intent.role != TeachingRole.MENTOR) return const WriteResult(WriteKind.denied);
      if (intent.kind == IntentKind.recover && intent.role != TeachingRole.MANAGER) {
        return const WriteResult(WriteKind.denied);
      }
      final reason = intent.reason?.trim() ?? '';
      if (intent.role == TeachingRole.MANAGER && reason.isEmpty) {
        return const WriteResult(WriteKind.error, code: 'REASON_REQUIRED');
      }
      final body = <String, Object?>{
        'expectedVersion': intent.expectedVersion,
        if ((intent.reason ?? '').isNotEmpty) 'reason': intent.reason,
        if (intent.kind == IntentKind.start && intent.actualStartedAt != null) 'actualStartedAt': intent.actualStartedAt,
        if (intent.kind == IntentKind.finalize && intent.actualEndedAt != null) 'actualEndedAt': intent.actualEndedAt,
        if (intent.kind == IntentKind.bulk) 'checked': intent.checked,
        if (intent.kind == IntentKind.save) ...{
          'records': [
            for (final r in intent.records ?? const <({String enrollmentId, Mark status})>[])
              {'enrollmentId': r.enrollmentId, 'status': r.status.name},
          ],
          if (intent.guestRecords != null)
            'guestRecords': [
              for (final r in intent.guestRecords!) {'makeupPlacementId': r.makeupPlacementId, 'status': r.status.name},
            ],
        },
        if (intent.kind == IntentKind.note) ...{'content': intent.content, 'nextSteps': intent.nextSteps},
        if (intent.kind == IntentKind.recover) ...{
          'records': [for (final r in intent.recoveryRecords ?? const <RecoveryRecord>[]) r.toJson()],
          'evidenceNote': intent.evidenceNote,
          'actualStartedAt': intent.actualStartedAt,
          'actualEndedAt': intent.actualEndedAt,
        },
      };
      if (intent.kind == IntentKind.recover && requestBytes(body) > 256 * 1024) {
        return const WriteResult(WriteKind.error, code: 'PAYLOAD_TOO_LARGE');
      }
      if (!_valid(intent, body)) return const WriteResult(WriteKind.error, code: 'INVALID_INPUT');
      if (intent.role == TeachingRole.MANAGER && intent.kind == IntentKind.finalize && intent.actualEndedAt == null) {
        return const WriteResult(WriteKind.error, code: 'INVALID_INPUT');
      }
      final suffix = switch (intent.kind) {
        IntentKind.start => 'start',
        IntentKind.save => 'attendance',
        IntentKind.bulk => 'attendance/bulk',
        IntentKind.sync => 'attendance/sync-roster',
        IntentKind.finalize => 'finalize',
        IntentKind.note => 'teaching-notes',
        IntentKind.recover => 'attendance/recover',
        IntentKind.updateSession => '',
      };
      final url =
          '${intent.kind == IntentKind.recover ? 'management/' : ''}class-sessions/${resourceId(intent.sessionId)}/$suffix';
      final headers = {'Idempotency-Key': intent.key};
      Object? response;
      try {
        response = const [IntentKind.save, IntentKind.bulk, IntentKind.note].contains(intent.kind)
            ? await _api.put(url, body: body, headers: headers)
            : await _api.post(url, body: body, headers: headers);
      } on ApiError catch (e) {
        return _failure(e);
      }
      try {
        final j = Json(response, _err);
        if (intent.kind == IntentKind.note) {
          final n = _note(j);
          if (n.sessionId != intent.sessionId) return const WriteResult(WriteKind.uncertain, code: 'INVALID_RESPONSE');
          return WriteResult(WriteKind.success, data: AttendanceData(note: n.note, noteVersion: n.version));
        }
        final session = _attendanceSession(j.obj('session'));
        if (session.id != intent.sessionId) return const WriteResult(WriteKind.uncertain, code: 'INVALID_RESPONSE');
        final changed = j.uuidList('changedEnrollmentIds').length + j.uuidList('changedMakeupPlacementIds').length;
        return WriteResult(
          WriteKind.success,
          data: AttendanceData(session: session, totals: _totals(j.obj('totals'), pending: 0)),
          changed: changed,
        );
      } catch (_) {
        return const WriteResult(WriteKind.uncertain, code: 'INVALID_RESPONSE');
      }
    } on RemoteError catch (e) {
      return WriteResult(WriteKind.error, code: e.code, requestId: e.requestId);
    } catch (_) {
      return const WriteResult(WriteKind.uncertain, code: 'INVALID_RESPONSE');
    }
  }

  /// Mất mạng / 5xx khi ghi = chưa chắc server đã nhận (uncertain) -> gửi lại cùng key.
  static WriteResult _failure(ApiError e) {
    if (e.isNetwork) return WriteResult(WriteKind.uncertain, code: 'NETWORK', requestId: e.requestId);
    final kind = e.status == 401 || e.status == 403 || e.code == 'SESSION_CHANGED'
        ? WriteKind.denied
        : e.status == 404
        ? WriteKind.notFound
        : e.status >= 500
        ? WriteKind.uncertain
        : WriteKind.error;
    return WriteResult(kind, code: e.code, requestId: e.requestId);
  }

  /// `wire.mutation[kind]` của RN.
  static bool _valid(AttendanceIntent intent, Map<String, Object?> body) {
    int chars(String? v) => (v ?? '').runes.length;
    final reason = body['reason'] as String?;
    if (intent.kind != IntentKind.note) {
      if (intent.expectedVersion < 1) return false;
      if (reason != null && (reason.trim().isEmpty || chars(reason) > 1000)) return false;
    }
    switch (intent.kind) {
      case IntentKind.save:
        {
          final records = intent.records?.length ?? 0, guests = intent.guestRecords?.length ?? 0;
          return records <= 100 && guests <= 100 && records + guests > 0;
        }
      case IntentKind.bulk:
        return intent.checked != null;
      case IntentKind.note:
        return intent.expectedVersion >= 0 &&
            intent.expectedVersion <= 2147483646 &&
            intent.content != null &&
            intent.nextSteps != null &&
            chars(intent.content) <= 10000 &&
            chars(intent.nextSteps) <= 5000;
      case IntentKind.recover:
        {
          final records = intent.recoveryRecords ?? const <RecoveryRecord>[];
          final evidence = intent.evidenceNote?.trim() ?? '';
          return reason != null &&
            evidence.isNotEmpty &&
            chars(intent.evidenceNote) <= 2000 &&
            intent.actualStartedAt != null &&
            intent.actualEndedAt != null &&
            records.isNotEmpty &&
            records.length <= 1000 &&
            records.every((r) => r.status != Mark.UNMARKED);
        }
      default:
        return true;
    }
  }
}
