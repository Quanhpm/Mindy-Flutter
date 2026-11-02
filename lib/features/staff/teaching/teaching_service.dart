import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../shared/remote.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';

/// Clone `modules/teaching/services/teachingService.ts` + `teachingSchemas.ts`.
/// `read` ném [RemoteError] (offline/denied/notFound/error/unavailable) thay cho `TeachingResult` lỗi.
final teachingServiceProvider = Provider((ref) => TeachingService(ref.watch(apiClientProvider)));

const _err = 'INVALID_TEACHING_RESPONSE';

class TeachingService {
  TeachingService(this._api);
  final ApiClient _api;

  // ---- schemas ----
  static void _count(int v, Json j) {
    if (v < 0) j.fail();
  }

  static int _nonNeg(Json j, String key) {
    final v = j.integer(key);
    _count(v, j);
    return v;
  }

  static ({String id, String? name}) _mentor(Json j) => (id: j.uuid('id'), name: j.strOrNull('displayName'));

  static TeachingClass _classSummary(Json j) {
    final mentor = _mentor(j.obj('mentor'));
    final scope = j.enumOf('accessScope', ClassScope.values);
    return TeachingClass(
      id: j.uuid('id'),
      code: j.str('code'),
      name: j.str('name'),
      status: j.enumOf('status', ClassStatus.values),
      startDate: j.day('startDate'),
      endDate: j.day('endDate'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      maxStudents: _nonNeg(j, 'maxStudents'),
      availableSeats: _nonNeg(j, 'availableSeats'),
      mentor: mentor.name,
      assignment: j.enumOf('assignmentType', ClassAssignment.values),
      scope: scope,
      readClassRoster: scope == ClassScope.CLASS,
    );
  }

  static Map<EnrollmentStatus, int> _enrollmentCounts(Json j) => {
    for (final s in EnrollmentStatus.values) s: _nonNeg(j, s.name),
  };

  static TeachingSession _session(Json j, {bool allowed = false}) {
    final effective = j.objOrNull('effectiveMentor');
    final effectiveMentor = effective == null ? null : _mentor(effective);
    final version = j.integer('version');
    if (version < 1) j.fail();
    final makeupFor = j.uuidOrNull('makeupForSessionId');
    final makeupRoot = j.uuidOrNull('makeupRootSessionId');
    final caps = j.objOrNull('capabilities');
    return TeachingSession(
      id: j.uuid('sessionId'),
      asOf: j.dateTime('asOf'),
      makeupForSessionId: makeupFor,
      classId: j.uuid('classId'),
      unitId: j.uuid('classUnitId'),
      title: j.str('title'),
      startsAt: j.dateTime('startsAt'),
      endsAt: j.dateTime('endsAt'),
      status: j.enumOf('status', SessionStatus.values),
      assignment: j.enumOf('assignmentType', SessionAssignment.values),
      readSessionContext: caps?.boolean('readSessionContext') ?? allowed,
      effectiveMentor: effectiveMentor?.name,
      effectiveMentorId: effectiveMentor?.id,
      primaryMentor: _mentor(j.obj('primaryMentor')).name,
      version: version,
      makeup: makeupFor != null || makeupRoot != null,
      actualStart: j.dateTimeOrNull('actualStartedAt'),
      actualEnd: j.dateTimeOrNull('actualEndedAt'),
    );
  }

  static ({TeachingSession session, String? room, String? meetingUrl}) _context(Json j) {
    if (j.str('accessScope') != 'SESSION') j.fail();
    final session = _session(j.obj('session'), allowed: true);
    final room = j.strOrNull('roomName');
    final url = j.strOrNull('meetingUrl');
    return (session: session.withContext(room: room, meetingUrl: url), room: room, meetingUrl: url);
  }

  static Paged<T> _page<T>(Object? body, T Function(Json) parse) {
    final p = Paged.fromJson(Json(body, _err), parse);
    if (p.page < 1 || p.pageSize < 1 || p.pageSize > 100 || p.total < 0) Json(body, _err).fail();
    if (p.items.length > p.pageSize || p.items.length > p.total) Json(body, _err).fail();
    return p;
  }

  /// `workspace` schema của mentor.
  static ({
    String id,
    String classId,
    String code,
    String name,
    ClassStatus status,
    String course,
    ClassScope scope,
    ClassAssignment assignment,
    bool readClass,
    bool readClassRoster,
    bool readClassReports,
    bool authorMaterials,
    int units,
    int sessions,
  })
  _workspace(Json j) {
    final caps = j.obj('capabilities');
    return (
      id: j.uuid('id'),
      classId: j.uuid('classId'),
      code: j.str('code'),
      name: j.str('name'),
      status: j.enumOf('status', ClassStatus.values),
      course: (j.obj('course')..uuid('id')).str('title'),
      scope: j.enumOf('accessScope', ClassScope.values),
      assignment: j.enumOf('assignmentType', ClassAssignment.values),
      readClass: caps.boolean('readClass'),
      readClassRoster: caps.boolean('readClassRoster'),
      readClassReports: caps.has('readClassReports') && caps.boolean('readClassReports'),
      authorMaterials: caps.has('authorMaterials') && caps.boolean('authorMaterials'),
      units: _nonNeg(j, 'visibleUnitCount'),
      sessions: _nonNeg(j, 'visibleSessionCount'),
    );
  }

  // ---- transport ----
  Future<Object?> _get(String path, [Map<String, Object?> query = const {}]) async {
    try {
      final Object? body = await _api.get(path, query: query);
      return body;
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on RemoteError {
      rethrow;
    } catch (e) {
      // Sai schema (ApiError.invalidResponse) hoặc lỗi khác -> error.
      throw RemoteError.from(e).kind == RemoteFailure.offline
          ? RemoteError.from(e)
          : const RemoteError(RemoteFailure.error);
    }
  }

  Future<TeachingClass> _enrichMentorCard(TeachingClass summary) async {
    final url = 'mentor/classes/${resourceId(summary.id)}/sessions';
    try {
      final sessions = <TeachingSession>[];
      for (var page = 1; ; page++) {
        final result = _page(await _get(url, {'page': page, 'pageSize': 100}), _session);
        if (result.items.any((s) => s.classId != summary.id)) throw const RemoteError(RemoteFailure.error);
        final previous = sessions.length;
        final merged = mergeById(sessions, result.items, (s) => s.id);
        sessions
          ..clear()
          ..addAll(merged);
        if (sessions.length >= result.total) break;
        if (sessions.length == previous) throw const RemoteError(RemoteFailure.error);
      }
      final s = classSessionSummary(sessions);
      return summary.copyWith(
        sessionCount: s.sessionCount,
        elapsedSessions: s.elapsedSessions,
        scheduleDays: s.scheduleDays,
        scheduleTime: s.scheduleTime,
        nextSessionAt: s.nextSessionAt,
      );
    } catch (e) {
      // Chi tiết phụ không được che danh sách; mất quyền vẫn ném lên.
      if (e is RemoteError && e.kind == RemoteFailure.denied) rethrow;
      return summary;
    }
  }

  Future<TeachingData> read(TeachingRequest r) => _guard(() async {
    if (r.page < 1 || r.pageSize < 1 || r.pageSize > 100) throw const RemoteError(RemoteFailure.error);
    final paging = {'page': r.page, 'pageSize': r.pageSize};
    final mentor = r.role == TeachingRole.MENTOR;
    final root = mentor ? 'mentor/classes' : 'manager/classes';
    switch (r.kind) {
      case TeachingKind.classes: {
        final status = (r.status ?? '').isEmpty ? null : r.status;
        if (status != null && !ClassStatus.values.any((s) => s.name == status)) {
          throw const RemoteError(RemoteFailure.error);
        }
        final q = r.q?.trim() ?? '';
        final result = _page(
          await _get(root, {...paging, 'status': ?status, if (!mentor && q.isNotEmpty) 'q': q}),
          _classSummary,
        );
        var classes = result.items;
        if (mentor && r.includeCardDetails) {
          // Tối đa 3 request song song như RN.
          final out = <TeachingClass>[];
          for (var i = 0; i < classes.length; i += 3) {
            out.addAll(await Future.wait(classes.skip(i).take(3).map(_enrichMentorCard)));
          }
          classes = out;
        }
        return TeachingData(classes: classes, total: result.total);
      }
      case TeachingKind.klass: {
        final body = await _get('$root/${resourceId(r.classId)}');
        if (mentor) {
          final w = _workspace(Json(body, _err));
          if (w.id != r.classId || w.classId != r.classId) throw const RemoteError(RemoteFailure.error);
          if (!w.readClass) throw const RemoteError(RemoteFailure.denied);
          final classScope = w.scope == ClassScope.CLASS;
          return TeachingData(
            classInfo: TeachingClass(
              id: w.id,
              name: w.name,
              code: w.code,
              status: w.status,
              course: w.course,
              scope: w.scope,
              assignment: w.assignment,
              readClassRoster: classScope && w.readClassRoster,
              readClassReports: classScope && w.readClassReports,
              authorMaterials: w.authorMaterials,
              unitCount: w.units,
              sessionCount: w.sessions,
            ),
          );
        }
        final j = Json(body, _err);
        final base = _classSummary(j);
        if (base.id != r.classId) throw const RemoteError(RemoteFailure.error);
        final course = j.obj('course');
        course.uuid('id');
        return TeachingData(
          classInfo: base.copyWith(
            course: '${course.str('code')} · ${course.str('title')}',
            room: j.strOrNull('roomName'),
            unitCount: _nonNeg(j, 'unitCount'),
            sessionCount: _nonNeg(j, 'sessionCount'),
            enrollmentCounts: _enrollmentCounts(j.obj('enrollmentCounts')),
          ),
        );
      }
      case TeachingKind.schedule:
      case TeachingKind.sessions: {
        final schedule = r.kind == TeachingKind.schedule;
        if (schedule && !mentor) throw const RemoteError(RemoteFailure.denied);
        if (schedule && (r.from == null || r.to == null)) throw const RemoteError(RemoteFailure.error);
        final url = schedule
            ? 'mentor/schedule'
            : mentor
            ? '$root/${resourceId(r.classId)}/sessions'
            : 'management/classes/${resourceId(r.classId)}';
        final params = mentor
            ? {...paging, 'from': ?r.from, 'to': ?r.to, if (!schedule) 'unitId': ?r.unitId}
            : paging;
        final body = await _get(url, params);
        final Paged<TeachingSession> result;
        if (mentor) {
          result = _page(body, (j) => _session(j, allowed: schedule));
        } else {
          final j = Json(body, _err);
          if (j.obj('class').uuid('id') != r.classId) j.fail();
          result = _page(j.raw('sessions'), (s) => _session(s, allowed: true));
        }
        if (!schedule && result.items.any((s) => s.classId != r.classId)) throw const RemoteError(RemoteFailure.error);
        return TeachingData(sessions: result.items, total: result.total);
      }
      case TeachingKind.context: {
        final c = _context(Json(await _get('class-sessions/${resourceId(r.sessionId)}/context'), _err));
        if (c.session.id != r.sessionId) throw const RemoteError(RemoteFailure.error);
        return TeachingData(session: c.session);
      }
      case TeachingKind.units: {
        final result = _page(
          await _get('$root/${resourceId(r.classId)}/units', paging),
          (j) => TeachingUnit(
            id: j.uuid('id'),
            courseUnitId: j.uuidOrNull('courseUnitId'),
            title: j.str('title'),
            position: j.integer('position') > 0 ? j.integer('position') : j.fail(),
          ),
        );
        return TeachingData(units: result.items, total: result.total);
      }
      case TeachingKind.students: {
        final classId = resourceId(r.classId);
        TeachingClass? info;
        if (mentor) {
          // Kiểm tra lại quyền roster trên server kể cả khi mở trực tiếp.
          final w = _workspace(Json(await _get('$root/$classId'), _err));
          if (w.id != r.classId ||
              w.classId != r.classId ||
              !w.readClass ||
              w.scope != ClassScope.CLASS ||
              !w.readClassRoster) {
            throw const RemoteError(RemoteFailure.denied);
          }
          info = TeachingClass(
            id: w.id,
            name: w.name,
            code: w.code,
            status: w.status,
            course: w.course,
            scope: w.scope,
            assignment: w.assignment,
            readClassRoster: true,
            unitCount: w.units,
            sessionCount: w.sessions,
          );
        }
        final body = await _get('$root/$classId/students', {
          ...paging,
          if ((r.status ?? '').isNotEmpty) 'orderStatus': r.status,
        });
        TeachingStudent roster(Json j, {bool manager = false}) => TeachingStudent(
          id: j.uuid('enrollmentId'),
          name: j.strOrNull('studentName'),
          enrollment: j.enumOf('enrollmentStatus', EnrollmentStatus.values),
          order: j.enumOf('orderStatus', OrderStatus.values),
          method: j.enumOf('paymentType', PaymentMethod.values),
          paidAt: j.dateTimeOrNull('paidAt'),
          expiresAt: j.dateTime('expiresAt'),
          email: manager ? j.nonEmpty('email') : null,
          phone: manager ? j.strOrNull('phone') : null,
          studentStatus: manager ? j.enumOf('studentStatus', StudentStatus.values) : null,
        );
        final result = _page(body, (j) => roster(j, manager: !mentor));
        return TeachingData(classInfo: info, students: result.items, total: result.total);
      }
      case TeachingKind.sessionStudents: {
        final id = resourceId(r.sessionId);
        final current = _context(Json(await _get('class-sessions/$id/context'), _err));
        if (current.session.id != r.sessionId) throw const RemoteError(RemoteFailure.error);
        if (current.session.status == SessionStatus.CANCELLED) throw const RemoteError(RemoteFailure.unavailable);
        final suffix = current.session.status == SessionStatus.SCHEDULED ? 'attendance-candidates' : 'attendance';
        final result = _page(await _get('class-sessions/$id/$suffix', paging), (j) {
          final student = _mentor(j.obj('student'));
          final placement = j.uuidOrNull('makeupPlacementId');
          return TeachingStudent(
            id: '${j.uuid('enrollmentId')}:${placement ?? 'regular'}',
            name: student.name,
            admission: j.enumOf('entryType', Admission.values),
          );
        });
        return TeachingData(students: result.items, total: result.total);
      }
    }
  });
}
