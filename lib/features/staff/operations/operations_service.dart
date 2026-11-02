// ignore_for_file: constant_identifier_names
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../attendance/attendance_logic.dart';
import '../shared/remote.dart';
import '../teaching/teaching_models.dart';

/// Clone `modules/operations` (types, model, services). Chỉ Quản lý.

@immutable
class OpsSession {
  const OpsSession({required this.session, required this.asOf, required this.makeupForSessionId, this.classTitle = ''});
  final TeachingSession session;
  final DateTime asOf;
  final String? makeupForSessionId;
  final String classTitle;
}

@immutable
class OpsClassInfo {
  const OpsClassInfo({required this.id, required this.name, required this.status, required this.startDate, required this.endDate});
  final String id;
  final String name;
  final ClassStatus status;
  final String startDate;
  final String endDate;
}

@immutable
class OpsCandidate {
  const OpsCandidate({required this.id, required this.name, required this.isCurrent});
  final String id;
  final String? name;
  final bool isCurrent;
}

enum CollectorSource { MANAGER, LEGACY_MENTOR }

@immutable
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.classId,
    required this.className,
    required this.courseTitle,
    required this.totalAmount,
    required this.quantity,
    required this.priceAmount,
  });
  final String id;
  final String classId;
  final String className;
  final String courseTitle;
  final int totalAmount;
  final int quantity;
  final int priceAmount;
}

@immutable
class CashOrder {
  const CashOrder({
    required this.id,
    required this.orderCode,
    required this.paymentType,
    required this.status,
    required this.totalAmount,
    required this.expiresAt,
    required this.createdAt,
    required this.paidAt,
    required this.student,
    required this.confirmedBy,
    required this.details,
  });
  final String id;
  final String orderCode;
  final PaymentMethod paymentType;
  final OrderStatus status;
  final int totalAmount;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? paidAt;
  final ({String id, String? name}) student;
  final ({String id, String? name, CollectorSource source})? confirmedBy;
  final List<OrderDetail> details;
}

enum OpsKind { context, klass, candidates, impact, orders, order, classes }

@immutable
class OpsRequest {
  const OpsRequest({
    required this.kind,
    this.id,
    this.status,
    this.search,
    this.classId,
    this.orderCode,
    this.page = 1,
    this.pageSize = 20,
  });
  final OpsKind kind;
  final String? id;
  final String? status;
  final String? search;
  final String? classId;
  final String? orderCode;
  final int page;
  final int pageSize;

  OpsRequest withPage(int value) => OpsRequest(
    kind: kind,
    id: id,
    status: status,
    search: search,
    classId: classId,
    orderCode: orderCode,
    page: value,
    pageSize: pageSize,
  );

  List<Object?> get _f => [kind, id, status, search, classId, orderCode, page, pageSize];
  @override
  bool operator ==(Object other) => other is OpsRequest && listEquals(_f, other._f);
  @override
  int get hashCode => Object.hashAll(_f);
}

@immutable
class OpsData {
  const OpsData({
    this.session,
    this.classInfo,
    this.candidates = const [],
    this.sessionVersion,
    this.classes = const [],
    this.orders = const [],
    this.order,
    this.impact,
    this.classEndDate,
    this.total = 0,
    required this.asOf,
  });
  final OpsSession? session;
  final OpsClassInfo? classInfo;
  final List<OpsCandidate> candidates;
  final int? sessionVersion;
  final List<OpsClassInfo> classes;
  final List<CashOrder> orders;
  final CashOrder? order;
  final ({int total, int? present, int? absent})? impact;
  final String? classEndDate;
  final int total;
  final DateTime asOf;

  int get count => candidates.length + classes.length + orders.length;

  OpsData mergeNext(OpsData next) => OpsData(
    session: next.session,
    classInfo: next.classInfo,
    candidates: mergeById(candidates, next.candidates, (e) => e.id),
    sessionVersion: next.sessionVersion,
    classes: mergeById(classes, next.classes, (e) => e.id),
    orders: mergeById(orders, next.orders, (e) => e.id),
    order: next.order,
    impact: next.impact,
    classEndDate: next.classEndDate,
    total: next.total,
    asOf: next.asOf,
  );
}

enum OpsMutationKind { assign, reschedule, cancel, replace, collect }

@immutable
class OpsMutation {
  const OpsMutation({
    required this.kind,
    required this.id,
    this.key = '',
    this.expectedVersion = 0,
    this.reason = '',
    this.mentorId,
    this.clearMentor = false,
    this.startsAt,
    this.endsAt,
    this.title,
    this.classUnitId,
    this.receivedAmount,
  });
  final OpsMutationKind kind;
  final String id;
  final String key;
  final int expectedVersion;
  final String reason;
  final String? mentorId;

  /// `mentorId: null` = trả buổi về mentor chính.
  final bool clearMentor;
  final String? startsAt;
  final String? endsAt;
  final String? title;
  final String? classUnitId;
  final int? receivedAmount;

  OpsMutation withKey(String value) => OpsMutation(
    kind: kind,
    id: id,
    key: value,
    expectedVersion: expectedVersion,
    reason: reason,
    mentorId: mentorId,
    clearMentor: clearMentor,
    startsAt: startsAt,
    endsAt: endsAt,
    title: title,
    classUnitId: classUnitId,
    receivedAmount: receivedAmount,
  );
}

enum OpsResultKind { success, error, offline, denied, notFound, uncertain }

@immutable
class OpsResult {
  const OpsResult(this.kind, {this.data, this.code, this.requestId});
  final OpsResultKind kind;
  final OpsData? data;
  final String? code;
  final String? requestId;
  bool get success => kind == OpsResultKind.success;
}

// ---- model.ts ----
String formatMoney(int value) => value >= 0
    ? '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} ₫'
    : '—';

int? moneyValue(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  final n = int.tryParse(digits);
  return n != null && n > 0 && n <= 9007199254740991 ? n : null;
}

/// Thao tác điều phối được phép theo trạng thái buổi.
List<String> sessionActions(SessionStatus status, DateTime startsAt, DateTime? asOf) {
  if (status == SessionStatus.CANCELLED) return const ['replace'];
  if (status == SessionStatus.COMPLETED) return const [];
  if (status == SessionStatus.IN_PROGRESS || (asOf != null && !startsAt.isAfter(asOf))) return const ['cancel'];
  return const ['reschedule', 'assign', 'cancel'];
}

String? replacementEnd(String start, int duration) {
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(start)) return null;
  final p = start.split(':').map(int.parse).toList();
  final end = p[0] * 60 + p[1] + duration;
  if (end < 0 || end >= 1440) return null;
  return '${(end ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
}

bool validSchedule(String date, String start, String end, DateTime asOf) {
  final from = parseVietnamTime(date, start), to = parseVietnamTime(date, end);
  if (from == null || to == null) return false;
  final f = DateTime.parse(from), t = DateTime.parse(to);
  return t.isAfter(f) && f.isAfter(asOf);
}

bool canCollect(CashOrder order, DateTime asOf) =>
    order.paymentType == PaymentMethod.CASH && order.status == OrderStatus.PENDING && order.expiresAt.isAfter(asOf);

// ---- service ----
final operationsServiceProvider = Provider((ref) {
  ref.watch(sessionEpochProvider);
  return OperationsService(ref.watch(apiClientProvider));
});

const _err = 'INVALID_OPERATIONS_RESPONSE';

class OperationsService {
  OperationsService(this._api);
  final ApiClient _api;

  static ({String id, String? name}) _person(Json j) => (id: j.uuid('id'), name: j.strOrNull('displayName'));

  static OpsSession _session(Json j) {
    final effective = j.objOrNull('effectiveMentor');
    final mentor = effective == null ? null : _person(effective);
    final makeupFor = j.uuidOrNull('makeupForSessionId');
    j.uuidOrNull('makeupRootSessionId');
    j.str('timeZone');
    final asOf = j.dateTime('asOf');
    final version = j.integer('version');
    if (version < 1) j.fail();
    return OpsSession(
      asOf: asOf,
      makeupForSessionId: makeupFor,
      session: TeachingSession(
        id: j.uuid('sessionId'),
        asOf: asOf,
        makeupForSessionId: makeupFor,
        classId: j.uuid('classId'),
        unitId: j.uuid('classUnitId'),
        title: j.str('title'),
        startsAt: j.dateTime('startsAt'),
        endsAt: j.dateTime('endsAt'),
        status: j.enumOf('status', SessionStatus.values),
        assignment: j.enumOf('assignmentType', SessionAssignment.values),
        readSessionContext: true,
        effectiveMentor: mentor?.name,
        effectiveMentorId: mentor?.id,
        primaryMentor: _person(j.obj('primaryMentor')).name,
        version: version,
        makeup: makeupFor != null,
        actualStart: j.dateTimeOrNull('actualStartedAt'),
        actualEnd: j.dateTimeOrNull('actualEndedAt'),
      ),
    );
  }

  static OpsClassInfo _classInfo(Json j) => OpsClassInfo(
    id: j.uuid('id'),
    name: j.str('name'),
    status: j.enumOf('status', ClassStatus.values),
    startDate: j.day('startDate'),
    endDate: j.day('endDate'),
  );

  static int _money(Json j, String key) => j.amount(key);

  static OrderDetail _detail(Json j) {
    final quantity = j.integer('quantity');
    if (quantity < 1) j.fail();
    return OrderDetail(
      id: j.uuid('id'),
      classId: j.uuid('classId'),
      className: j.str('className'),
      courseTitle: j.str('courseTitle'),
      totalAmount: _money(j, 'totalAmount'),
      priceAmount: _money(j, 'priceAmount'),
      quantity: quantity,
    );
  }

  static CashOrder _order(Json j, {bool requireDetails = false}) {
    final payment = j.objOrNull('payment');
    final confirmed = payment?.objOrNull('confirmedBy');
    final student = j.objOrNull('student');
    return CashOrder(
      id: j.uuid('id'),
      orderCode: j.str('orderCode'),
      paymentType: j.enumOf('paymentType', PaymentMethod.values),
      status: j.enumOf('status', OrderStatus.values),
      totalAmount: _money(j, 'totalAmount'),
      expiresAt: j.dateTime('expiresAt'),
      paidAt: j.dateTimeOrNull('paidAt'),
      createdAt: j.dateTime('createdAt'),
      student: student == null ? (id: '', name: null) : _person(student),
      confirmedBy: confirmed == null
          ? null
          : (
              id: confirmed.uuid('id'),
              name: confirmed.strOrNull('displayName'),
              source: confirmed.enumOf('source', CollectorSource.values),
            ),
      details: requireDetails || j.has('details') ? j.list('details', _detail) : const [],
    );
  }

  static Paged<T> _page<T>(Object? body, T Function(Json) parse) {
    final j = Json(body, _err);
    final p = Paged.fromJson(j, parse);
    if (p.page < 1 || p.pageSize < 1 || p.pageSize > 100 || p.total < 0 || p.items.length > p.pageSize) j.fail();
    return p;
  }

  Future<Object?> _get(String path, [Map<String, Object?> query = const {}]) async {
    try {
      final Object? body = await _api.get(path, query: query);
      return body;
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  static OpsResult _fail(Object e) {
    if (e is RemoteError) {
      final kind = switch (e.kind) {
        RemoteFailure.offline => OpsResultKind.offline,
        RemoteFailure.denied => OpsResultKind.denied,
        RemoteFailure.notFound => OpsResultKind.notFound,
        _ => OpsResultKind.error,
      };
      return OpsResult(kind, code: e.code, requestId: e.requestId);
    }
    return const OpsResult(OpsResultKind.error, code: 'INVALID_RESPONSE');
  }

  Future<OpsResult> read(OpsRequest r) async {
    try {
      if (r.page < 1 || r.pageSize < 1 || r.pageSize > 100) return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
      final paging = {'page': r.page, 'pageSize': r.pageSize};
      final now = DateTime.now();
      final OpsData data;
      switch (r.kind) {
        case OpsKind.context:
          {
            final j = Json(await _get('class-sessions/${resourceId(r.id)}/context'), _err);
            final s = _session(j.obj('session'));
            if (s.session.id != r.id) return const OpsResult(OpsResultKind.error, code: 'RESOURCE_MISMATCH');
            data = OpsData(
              session: OpsSession(
                session: s.session.withContext(room: j.strOrNull('roomName'), meetingUrl: j.strOrNull('meetingUrl')),
                asOf: s.asOf,
                makeupForSessionId: s.makeupForSessionId,
              ),
              asOf: s.asOf,
            );
          }
        case OpsKind.klass:
          {
            final info = _classInfo(Json(await _get('manager/classes/${resourceId(r.id)}'), _err));
            if (info.id != r.id) return const OpsResult(OpsResultKind.error, code: 'RESOURCE_MISMATCH');
            data = OpsData(classInfo: info, asOf: now);
          }
        case OpsKind.candidates:
          {
            final search = r.search?.trim() ?? '';
            final body = await _get('management/class-sessions/${resourceId(r.id)}/available-mentors', {
              ...paging,
              if (search.isNotEmpty) 'search': search.length > 100 ? search.substring(0, 100) : search,
            });
            final j = Json(body, _err);
            final page = _page(body, (i) {
              final p = _person(i);
              return OpsCandidate(id: p.id, name: p.name, isCurrent: i.boolean('isCurrent'));
            });
            if (j.uuid('sessionId') != r.id) return const OpsResult(OpsResultKind.error, code: 'RESOURCE_MISMATCH');
            final version = j.integer('sessionVersion');
            if (version < 1) j.fail();
            data = OpsData(candidates: page.items, sessionVersion: version, total: page.total, asOf: j.dateTime('asOf'));
          }
        case OpsKind.orders:
          {
            final code = r.orderCode?.trim().toUpperCase() ?? '';
            final status = r.status;
            if (status != null && !OrderStatus.values.any((s) => s.name == status)) {
              return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
            }
            final page = _page(
              await _get('manager/orders', {
                ...paging,
                'paymentType': 'CASH',
                if (code.isNotEmpty) 'orderCode': code,
                if (code.isEmpty && status != null) 'status': status,
                if (code.isEmpty && r.classId != null) 'classId': resourceId(r.classId),
              }),
              _order,
            );
            if (page.items.any((o) => o.paymentType != PaymentMethod.CASH)) {
              return const OpsResult(OpsResultKind.error, code: 'INVALID_RESPONSE');
            }
            data = OpsData(orders: page.items, total: page.total, asOf: now);
          }
        case OpsKind.order:
          {
            final order = _order(Json(await _get('manager/orders/${resourceId(r.id)}'), _err), requireDetails: true);
            if (order.id != r.id) return const OpsResult(OpsResultKind.error, code: 'RESOURCE_MISMATCH');
            data = OpsData(order: order, asOf: now);
          }
        case OpsKind.classes:
          {
            final page = _page(
              await _get('manager/classes', {...paging, if ((r.search ?? '').isNotEmpty) 'q': r.search}),
              _classInfo,
            );
            data = OpsData(classes: page.items, total: page.total, asOf: now);
          }
        case OpsKind.impact:
          {
            final j = Json(
              await _get(
                'class-sessions/${resourceId(r.id)}/${r.status == 'IN_PROGRESS' ? 'attendance' : 'attendance-candidates'}',
                {'page': 1, 'pageSize': 1},
              ),
              _err,
            );
            final totals = j.objOrNull('totals');
            data = OpsData(
              asOf: now,
              impact: totals != null
                  ? (total: totals.integer('eligible'), present: totals.integer('present'), absent: totals.integer('absent'))
                  : j.has('total')
                  ? (total: j.integer('total'), present: null, absent: null)
                  : null,
            );
          }
      }
      return OpsResult(OpsResultKind.success, data: data);
    } catch (e) {
      return _fail(RemoteError.from(e));
    }
  }

  Future<OpsResult> write(OpsMutation m) async {
    var dispatched = false;
    try {
      final cash = m.kind == OpsMutationKind.collect;
      final Map<String, Object?> body;
      if (cash) {
        if ((m.receivedAmount ?? 0) <= 0) return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
        body = {'receivedAmount': m.receivedAmount};
      } else {
        final reason = m.reason.trim();
        if (m.expectedVersion < 1 || reason.isEmpty || reason.length > 1000 || !isUuid(m.key)) {
          return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
        }
        body = {
          'expectedVersion': m.expectedVersion,
          'reason': m.reason,
          if (m.kind == OpsMutationKind.assign) 'mentorId': m.clearMentor ? null : m.mentorId,
          if (m.kind == OpsMutationKind.reschedule || m.kind == OpsMutationKind.replace) ...{
            'startsAt': m.startsAt,
            'endsAt': m.endsAt,
          },
          if (m.kind == OpsMutationKind.replace) ...{'classUnitId': m.classUnitId, 'title': m.title},
        };
        if (m.kind == OpsMutationKind.assign && !m.clearMentor && !isUuid(m.mentorId)) {
          return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
        }
        if ((m.kind == OpsMutationKind.reschedule || m.kind == OpsMutationKind.replace) && (m.startsAt == null || m.endsAt == null)) {
          return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
        }
        if (m.kind == OpsMutationKind.replace) {
          final title = m.title?.trim() ?? '';
          if (!isUuid(m.classUnitId) || title.isEmpty || title.length > 250) {
            return const OpsResult(OpsResultKind.error, code: 'INVALID_INPUT');
          }
        }
      }
      final id = resourceId(m.id);
      final suffix = switch (m.kind) {
        OpsMutationKind.assign => 'mentor',
        OpsMutationKind.reschedule => 'schedule',
        OpsMutationKind.replace => 'makeups',
        _ => 'cancel',
      };
      final url = cash ? 'manager/cash-orders/$id/confirm' : 'management/class-sessions/$id/$suffix';
      final headers = cash ? null : {'Idempotency-Key': m.key};
      dispatched = true;
      Object? response;
      try {
        response = cash || m.kind == OpsMutationKind.cancel || m.kind == OpsMutationKind.replace
            ? await _api.post(url, body: body, headers: headers)
            : await _api.patch(url, body: body, headers: headers);
      } on ApiError catch (e) {
        if (e.isNetwork) return OpsResult(OpsResultKind.uncertain, code: 'NETWORK', requestId: e.requestId);
        final kind = e.status == 401 || e.status == 403
            ? OpsResultKind.denied
            : e.status == 404
            ? OpsResultKind.notFound
            : (e.status >= 500 || e.status == 408)
            ? OpsResultKind.uncertain
            : OpsResultKind.error;
        return OpsResult(kind, code: e.code, requestId: e.requestId);
      }
      final j = Json(response, _err);
      if (cash) {
        final order = _order(j, requireDetails: true);
        if (order.id != m.id || order.paymentType != PaymentMethod.CASH || order.status != OrderStatus.PAID) {
          return const OpsResult(OpsResultKind.uncertain, code: 'INVALID_RESPONSE');
        }
        return OpsResult(OpsResultKind.success, data: OpsData(order: order, asOf: DateTime.now()));
      }
      if (m.kind == OpsMutationKind.replace) {
        final s = _session(j.obj('session'));
        if (j.uuid('originalSessionId') != m.id || s.makeupForSessionId != m.id) {
          return const OpsResult(OpsResultKind.uncertain, code: 'RESOURCE_MISMATCH');
        }
        j.integer('originalVersion');
        return OpsResult(OpsResultKind.success, data: OpsData(session: s, asOf: s.asOf, classEndDate: j.day('classEndDate')));
      }
      final s = _session(j);
      if (s.session.id != m.id) return const OpsResult(OpsResultKind.uncertain, code: 'RESOURCE_MISMATCH');
      return OpsResult(OpsResultKind.success, data: OpsData(session: s, asOf: s.asOf));
    } catch (e) {
      if (e is RemoteError) return _fail(e);
      return OpsResult(dispatched ? OpsResultKind.uncertain : OpsResultKind.error, code: dispatched ? 'INVALID_RESPONSE' : 'INVALID_INPUT');
    }
  }
}
