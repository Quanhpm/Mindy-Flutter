import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/idempotency.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';

import 'mentor_fixtures.dart';

String attendanceFixtureId(int number) => '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}';

/// Server trong RAM cho debug/test. Không được import từ lib/ hay build release.
/// Có receipt, version, batch, response mất sau commit và lỗi reload để kiểm tra luồng thật.
class MemoryAttendanceApi extends MentorAttendanceApi {
  MemoryAttendanceApi({
    this.studentCount = 12,
    TeachingStatus status = TeachingStatus.IN_PROGRESS,
    this.expired = false,
    this.sessionId,
  }) : _status = status,
       super(ApiClient(cookieJar: CookieJar())) {
    if (status != TeachingStatus.SCHEDULED) {
      for (var i = 0; i < studentCount; i++) {
        _add(i);
      }
      if (status == TeachingStatus.COMPLETED) {
        for (final key in _records.keys.toList()) {
          _mark(key, AttendanceStatus.ABSENT);
        }
      }
    }
  }
  final int studentCount;
  final String? sessionId;
  bool expired;
  TeachingStatus _status;
  int _version = 2;
  int readCount = 0, committedWrites = 0, failReads = 0;
  int? loseResponseAtCommit;
  bool _lost = false, conflictNextWrite = false;
  Completer<void>? delayNextWrite;
  final _records = <String, AttendanceRecord>{};
  final _receipts = <String, AttendanceWrite>{};
  final _payloads = <String, String>{};
  final calls = <({AttendanceOperation operation, IdempotentCall call})>[];
  int pendingPaymentCount = 1;

  void _add(int index) {
    final guest = index.isOdd;
    final row = AttendanceRecord(
      id: attendanceFixtureId(1000 + index),
      enrollmentId: attendanceFixtureId(2000 + index),
      type: guest ? AttendanceEntryType.MAKEUP : AttendanceEntryType.REGULAR,
      placementId: guest ? attendanceFixtureId(3000 + index) : null,
      student: TeachingPerson(id: attendanceFixtureId(4000 + index), displayName: 'Học viên mẫu ${index + 1}'),
      status: AttendanceStatus.UNMARKED,
      checkedInAt: null,
      admittedAt: previewNow,
    );
    _records[row.key] = row;
  }

  AttendanceHeader get _header {
    final schedule = sampleSchedule();
    final source = schedule.entries
        .firstWhere((entry) => entry.session.id == sessionId, orElse: () => schedule.entries.first)
        .session;
    return AttendanceHeader(
      session: TeachingSession(
        id: sessionId ?? source.id,
        classId: source.classId,
        classUnitId: source.classUnitId,
        title: source.title,
        startsAt: source.startsAt,
        endsAt: source.endsAt,
        status: _status,
        primaryMentor: source.primaryMentor,
        effectiveMentor: source.effectiveMentor,
        assignment: source.assignment,
        version: _version,
        timeZone: previewZone,
        asOf: previewNow,
        actualStartedAt: _status == TeachingStatus.SCHEDULED ? null : source.startsAt,
        actualEndedAt: _status == TeachingStatus.COMPLETED ? source.endsAt : null,
        editableUntil: expired ? previewNow.subtract(const Duration(minutes: 1)) : DateTime.utc(2026, 11, 3, 17),
      ),
      permissions: AttendancePermissions(
        canStart: _status == TeachingStatus.SCHEDULED && !expired,
        canEdit:
            !expired &&
            [_status].any((status) => status == TeachingStatus.IN_PROGRESS || status == TeachingStatus.COMPLETED),
        canFinalize: _status == TeachingStatus.IN_PROGRESS && !expired,
        canSync: _status == TeachingStatus.IN_PROGRESS && !expired,
        canRecover: false,
        canViewAudits: false,
      ),
      totals: AttendanceTotals(
        present: _records.values.where((row) => row.status == AttendanceStatus.PRESENT).length,
        absent: _records.values.where((row) => row.status == AttendanceStatus.ABSENT).length,
        unmarked: _records.values.where((row) => row.status == AttendanceStatus.UNMARKED).length,
        eligible: _records.length,
      ),
    );
  }

  @override
  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) async {
    readCount++;
    if (failReads > 0) {
      failReads--;
      throw ApiError.network();
    }
    return AttendanceRoster(
      header: _header,
      records: _records.values.toList(),
      pendingPaymentCount: pendingPaymentCount,
    );
  }

  bool _mark(String key, AttendanceStatus status) {
    final row = _records[key]!;
    if (row.status == status) return false;
    _records[key] = AttendanceRecord(
      id: row.id,
      enrollmentId: row.enrollmentId,
      type: row.type,
      placementId: row.placementId,
      student: row.student,
      status: status,
      checkedInAt: status == AttendanceStatus.PRESENT ? previewNow : null,
      admittedAt: row.admittedAt,
    );
    return true;
  }

  @override
  Future<AttendanceWrite> execute(String id, AttendanceOperation operation, IdempotentCall call) async {
    calls.add((operation: operation, call: call));
    final delay = delayNextWrite;
    if (delay != null) {
      delayNextWrite = null;
      await delay.future;
    }
    final hash = jsonEncode(call.body);
    final cached = _receipts[call.key];
    if (cached != null) {
      if (_payloads[call.key] != hash) throw ApiError(status: 409, code: 'IDEMPOTENCY_KEY_REUSED');
      return cached;
    }
    if (conflictNextWrite) {
      conflictNextWrite = false;
      if (_records.isNotEmpty) _mark(_records.keys.first, AttendanceStatus.ABSENT);
      _version++;
      throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
    }
    if (call.body['expectedVersion'] != _version) throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
    if (expired) throw ApiError(status: 409, code: 'ATTENDANCE_EDIT_WINDOW_EXPIRED');
    final changedRegular = <String>[], changedGuest = <String>[];
    void mark(String key, AttendanceStatus status) {
      if (_mark(key, status)) {
        final row = _records[key]!;
        if (row.type == AttendanceEntryType.MAKEUP) {
          changedGuest.add(row.placementId!);
        } else {
          changedRegular.add(row.enrollmentId);
        }
      }
    }

    switch (operation) {
      case AttendanceOperation.start:
        if (_status != TeachingStatus.SCHEDULED) throw ApiError(status: 409, code: 'SESSION_STATE_CONFLICT');
        _status = TeachingStatus.IN_PROGRESS;
        for (var i = 0; i < studentCount; i++) {
          _add(i);
        }
        for (final row in _records.values) {
          if (row.type == AttendanceEntryType.MAKEUP) {
            changedGuest.add(row.placementId!);
          } else {
            changedRegular.add(row.enrollmentId);
          }
        }
      case AttendanceOperation.mark:
        for (final raw in call.body['records']! as List<Object?>) {
          final row = raw! as Map<String, Object?>;
          mark('REGULAR:${row['enrollmentId']}', AttendanceStatus.values.byName(row['status']! as String));
        }
        for (final raw in (call.body['guestRecords'] as List<Object?>? ?? const <Object?>[])) {
          final row = raw! as Map<String, Object?>;
          mark('MAKEUP:${row['makeupPlacementId']}', AttendanceStatus.values.byName(row['status']! as String));
        }
      case AttendanceOperation.bulk:
        for (final key in _records.keys.toList()) {
          mark(key, call.body['checked'] == true ? AttendanceStatus.PRESENT : AttendanceStatus.ABSENT);
        }
      case AttendanceOperation.sync:
        _add(_records.length);
        final added = _records.values.last;
        if (added.type == AttendanceEntryType.MAKEUP) {
          changedGuest.add(added.placementId!);
        } else {
          changedRegular.add(added.enrollmentId);
        }
        pendingPaymentCount = 0;
      case AttendanceOperation.finalize:
        if (_status != TeachingStatus.IN_PROGRESS) throw ApiError(status: 409, code: 'SESSION_STATE_CONFLICT');
        for (final key in _records.keys.toList()) {
          if (_records[key]!.status == AttendanceStatus.UNMARKED) mark(key, AttendanceStatus.ABSENT);
        }
        _status = TeachingStatus.COMPLETED;
    }
    if (changedRegular.isNotEmpty ||
        changedGuest.isNotEmpty ||
        [AttendanceOperation.start, AttendanceOperation.sync, AttendanceOperation.finalize].contains(operation)) {
      _version++;
    }
    committedWrites++;
    final result = AttendanceWrite(
      header: _header,
      changedEnrollmentIds: changedRegular,
      changedPlacementIds: changedGuest,
    );
    _receipts[call.key] = result;
    _payloads[call.key] = hash;
    if (loseResponseAtCommit == committedWrites && !_lost) {
      _lost = true;
      throw ApiError.network();
    }
    return result;
  }
}

class MemoryAttendanceRouter extends MentorAttendanceApi {
  MemoryAttendanceRouter() : super(ApiClient(cookieJar: CookieJar()));
  final _sessions = <String, MemoryAttendanceApi>{};
  MemoryAttendanceApi _session(String id) => _sessions.putIfAbsent(id, () => MemoryAttendanceApi(sessionId: id));
  @override
  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) => _session(id).roster(id, cancel: cancel);
  @override
  Future<AttendanceWrite> execute(String id, AttendanceOperation operation, IdempotentCall call) =>
      _session(id).execute(id, operation, call);
}
