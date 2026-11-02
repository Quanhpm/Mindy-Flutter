import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/json.dart';
import '../../mentor/schedule/schedule_models.dart';
import '../manager_api.dart';
import '../manager_models.dart';
import 'operations_models.dart';

final managerOperationsApiProvider = Provider((ref) => ManagerOperationsApi(ref.watch(managerApiProvider)));

class ManagerOperationsApi {
  ManagerOperationsApi(this.api);
  final ManagerApi api;
  Future<ManagedTimetable> timetable(String id, {CancelToken? cancel}) async {
    ManagedTeachingClass? first;
    int? total, size;
    final items = <TeachingSession>[], ids = <String>{}, epoch = api.client.sessionEpoch;
    for (var n = 1; ; n++) {
      if (api.client.sessionEpoch != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
      final j = Json(
        await api.read('management/classes/$id', query: {'page': n, 'pageSize': 100}, cancel: cancel),
        managerErrorCode,
      );
      final info = ManagedTeachingClass.fromJson(j.obj('class'));
      final p = Paged.fromJson(j.obj('sessions'), TeachingSession.fromJson);
      p.check(n, items.length + p.items.length, managerErrorCode);
      if (info.id != id ||
          (first != null && first.version != info.version) ||
          (total != null && total != p.total) ||
          (size != null && size != p.pageSize)) {
        throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
      }
      first ??= info;
      total = p.total;
      size = p.pageSize;
      for (final s in p.items) {
        if (s.classId != id || !ids.add(s.id)) j.fail();
        items.add(s);
      }
      if (items.length == total) return ManagedTimetable(first, List.unmodifiable(items));
    }
  }

  Future<AvailableMentors> candidates(AssignmentTarget target, {CancelToken? cancel}) async {
    final path = target.session ? 'class-sessions' : 'classes';
    final items = <AvailableMentor>[], ids = <String>{};
    int? version, total, size;
    String? zone;
    var affected = 0;
    final epoch = api.client.sessionEpoch;
    for (var n = 1; ; n++) {
      if (api.client.sessionEpoch != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
      final j = Json(
        await api.read(
          'management/$path/${target.id}/available-mentors',
          query: {'page': n, 'pageSize': 100},
          cancel: cancel,
        ),
        managerErrorCode,
      );
      final v = positive(j, target.session ? 'sessionVersion' : 'assignmentVersion'),
          z = managerZone(j),
          p = Paged.fromJson(j, AvailableMentor.fromJson);
      if (j.uuid(target.session ? 'sessionId' : 'classId') != target.id ||
          j.str('availabilityBasis') != 'TEACHING_SCHEDULE_AND_APPROVED_LEAVE' ||
          (version != null && version != v) ||
          (zone != null && zone != z) ||
          (total != null && total != p.total) ||
          (size != null && size != p.pageSize)) {
        throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
      }
      p.check(n, items.length + p.items.length, managerErrorCode);
      version = v;
      zone = z;
      total = p.total;
      size = p.pageSize;
      affected = target.session ? 1 : countValue(j, 'affectedSessionCount');
      for (final item in p.items) {
        if (!ids.add(item.id)) j.fail();
        items.add(item);
      }
      if (items.length == total) return AvailableMentors(List.unmodifiable(items), v, z, affected);
    }
  }

  Future<AssignmentResult> assign(AssignmentTarget target, IdempotentCall call) async {
    final path = target.session ? 'class-sessions' : 'classes';
    final j = Json(
      await api.client.patch('management/$path/${target.id}/mentor', body: call.body, headers: call.headers),
      managerErrorCode,
    );
    final id = j.uuid(target.session ? 'sessionId' : 'classId'),
        version = positive(j, target.session ? 'version' : 'assignmentVersion');
    if (id != target.id ||
        version < (call.body['expectedVersion']! as int) ||
        version > (call.body['expectedVersion']! as int) + 1) {
      j.fail();
    }
    return AssignmentResult(id, version);
  }

  Future<List<IncompleteTeaching>> incomplete({String? classId, String? issue, CancelToken? cancel}) => api.all(
    'management/class-sessions/incomplete',
    IncompleteTeaching.fromJson,
    id: (s) => s.session.id,
    query: {'classId': classId, 'issue': issue},
    cancel: cancel,
  );
  Future<List<ManagerAttendanceRow>> report(String classId, {CancelToken? cancel}) => api.all(
    'management/classes/$classId/attendance-summary',
    ManagerAttendanceRow.fromJson,
    id: (r) => r.id,
    cancel: cancel,
    inspect: (j) {
      if (j.uuid('classId') != classId) j.fail();
      managerZone(j);
      j.dateTime('asOf');
    },
  );
  Future<List<ManagerAttendanceAudit>> audits(String id, {CancelToken? cancel}) => api.all(
    'management/class-sessions/$id/attendance-audits',
    ManagerAttendanceAudit.fromJson,
    id: (r) => r.id,
    cancel: cancel,
  );
  Future<List<MakeupConflict>> conflicts({MakeupConflictStatus? status, CancelToken? cancel}) async {
    Future<List<MakeupConflict>> read(MakeupConflictStatus s) => api.all(
      'management/student-schedule-conflicts',
      MakeupConflict.fromJson,
      id: (c) => c.id,
      query: {'status': s.name},
      cancel: cancel,
    );
    if (status != null) return read(status);
    // Backend mặc định chỉ OPEN/MAKEUP_ASSIGNED. "Tất cả" phải lấy cả RESOLVED.
    final result = <MakeupConflict>[], ids = <String>{};
    for (final s in MakeupConflictStatus.values) {
      for (final item in await read(s)) {
        if (!ids.add(item.id)) throw ApiError.invalidResponse(managerErrorCode);
        result.add(item);
      }
    }
    return List.unmodifiable(result);
  }

  Future<List<MakeupCandidate>> makeupCandidates(String id, {CancelToken? cancel}) => api.all(
    'management/student-schedule-conflicts/$id/makeup-candidates',
    MakeupCandidate.fromJson,
    id: (c) => c.session.id,
    cancel: cancel,
  );
  Future<MakeupDecision> place(String conflictId, IdempotentCall call, {String? placementId}) async {
    final path = placementId == null
        ? 'student-schedule-conflicts/$conflictId/makeup-placement'
        : 'makeup-placements/$placementId/cancel';
    final j = Json(await api.client.post('management/$path', body: call.body, headers: call.headers), managerErrorCode);
    final result = MakeupDecision.fromJson(j);
    if (result.conflictId != conflictId ||
        (placementId != null && (result.id != placementId || result.status != 'CANCELLED')) ||
        (placementId == null && result.status != 'ASSIGNED')) {
      j.fail();
    }
    return result;
  }
}
