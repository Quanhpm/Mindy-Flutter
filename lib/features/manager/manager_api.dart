import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/json.dart';
import '../../core/network/pagination.dart';
import '../../core/network/api_error.dart';
import '../../core/utils/concurrent.dart';
import '../mentor/schedule/schedule_models.dart';
import 'manager_models.dart';

final managerApiProvider = Provider((ref) => ManagerApi(ref.watch(apiClientProvider)));

class ManagerApi {
  ManagerApi(this.client);
  final ApiClient client;
  final _reads = AsyncGate(3);
  Future<dynamic> read(String path, {Map<String, Object?>? query, CancelToken? cancel}) {
    final epoch = client.sessionEpoch;
    return _reads.run(() {
      if (epoch != client.sessionEpoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
      return client.get(path, query: query, cancel: cancel);
    });
  }

  Future<Paged<T>> page<T>(
    String path,
    T Function(Json) parse, {
    Map<String, Object?> query = const {},
    CancelToken? cancel,
    void Function(Json)? inspect,
  }) async {
    final j = Json(await read(path, query: query, cancel: cancel), managerErrorCode);
    inspect?.call(j);
    final p = Paged.fromJson(j, parse);
    p.check(query['page'] as int? ?? 1, p.items.length, managerErrorCode);
    return p;
  }

  Future<List<T>> all<T>(
    String path,
    T Function(Json) parse, {
    required String Function(T) id,
    Map<String, Object?> query = const {},
    CancelToken? cancel,
    void Function(Json)? inspect,
  }) {
    final epoch = client.sessionEpoch;
    return readAllPages(
      (n) {
        if (epoch != client.sessionEpoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
        return page(path, parse, query: {...query, 'page': n, 'pageSize': 100}, cancel: cancel, inspect: inspect);
      },
      idOf: id,
      errorCode: managerErrorCode,
    );
  }

  Future<List<ManagedCourse>> courses({CancelToken? cancel}) =>
      all('manager/courses', ManagedCourse.fromJson, id: (c) => c.course.id, cancel: cancel);
  Future<ManagedCourse> course(String id, {CancelToken? cancel}) async {
    final j = Json(await read('manager/courses/$id', cancel: cancel), managerErrorCode);
    final c = ManagedCourse.fromJson(j);
    if (c.course.id != id) j.fail();
    return c;
  }

  Future<List<ManagerPerson>> people(String role, String search, {CancelToken? cancel}) {
    _role(role);
    return all(
      'manager/${role == 'MENTOR' ? 'mentors' : 'students'}',
      (j) {
        final p = ManagerPerson.fromJson(j);
        if (p.role != role) j.fail();
        return p;
      },
      id: (p) => p.id,
      query: {if (search.trim().isNotEmpty) 'q': search.trim()},
      cancel: cancel,
    );
  }

  void _role(String role) {
    if (!['MENTOR', 'STUDENT'].contains(role)) throw ApiError(status: 422, code: 'MANAGER_VALIDATION');
  }

  Future<ManagerPerson> person(String role, String id, {CancelToken? cancel}) async {
    _role(role);
    final j = Json(
      await read('manager/${role == 'MENTOR' ? 'mentors' : 'students'}/$id', cancel: cancel),
      managerErrorCode,
    );
    final p = ManagerPerson.fromJson(j);
    if (p.id != id || p.role != role) j.fail();
    return p;
  }

  Future<List<ManagedClass>> classes({String? mentorId, String search = '', CancelToken? cancel}) => all(
    mentorId == null ? 'manager/classes' : 'manager/mentors/$mentorId/classes',
    ManagedClass.fromJson,
    id: (c) => c.id,
    query: {if (mentorId == null && search.trim().isNotEmpty) 'q': search.trim()},
    cancel: cancel,
  );
  Future<ManagedClassDetail> classDetail(String id, {CancelToken? cancel}) async {
    final j = Json(await read('manager/classes/$id', cancel: cancel), managerErrorCode);
    final d = ManagedClassDetail.fromJson(j);
    if (d.info.id != id) j.fail();
    return d;
  }

  Future<List<ManagedUnit>> classUnits(String id, {CancelToken? cancel}) => all(
    'manager/classes/$id/units',
    (j) => ManagedUnit(j.uuid('id'), j.str('title'), countValue(j, 'position')),
    id: (u) => u.id,
    cancel: cancel,
  );
  Future<List<ManagerStudentClass>> studentClasses(String id, {CancelToken? cancel}) =>
      all('manager/students/$id/classes', ManagerStudentClass.fromJson, id: (c) => c.id, cancel: cancel);
  Future<({List<TeachingSession> items, String zone})> mentorSchedule(
    String id,
    DateTime from,
    DateTime to, {
    CancelToken? cancel,
  }) async {
    String? zone;
    final items = await all(
      'manager/mentors/$id/schedule',
      TeachingSession.fromJson,
      id: (s) => s.id,
      query: {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()},
      cancel: cancel,
      inspect: (j) {
        final z = managerZone(j);
        if ((zone != null && zone != z) ||
            !j.dateTime('from').isAtSameMomentAs(from) ||
            !j.dateTime('to').isAtSameMomentAs(to)) {
          j.fail();
        }
        zone = z;
      },
    );
    if (items.any((s) => s.timeZone != zone)) throw ApiError.invalidResponse(managerErrorCode);
    return (items: items, zone: zone!);
  }
}
