// ignore_for_file: constant_identifier_names
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import '../teaching/teaching_models.dart';

/// Clone `modules/leave` (types.ts, model.ts, services/leaveService.ts).

enum LeaveStatus { PENDING, APPROVED, REJECTED, WITHDRAWN, EXPIRED }

enum Period { MORNING, AFTERNOON, EVENING, FULL_DAY }

enum ConflictStatus { OPEN, MAKEUP_ASSIGNED, RESOLVED }

enum LeaveRole { MENTOR, MANAGER }

@immutable
class Slot {
  const Slot({required this.startsAt, required this.endsAt});
  final DateTime startsAt;
  final DateTime endsAt;
  Map<String, Object?> toJson() => {
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
  };
}

@immutable
class Mapping extends Slot {
  const Mapping({
    required super.startsAt,
    required super.endsAt,
    required this.version,
    this.targetDate,
    this.targetPeriod,
  });
  final int version;
  final String? targetDate;
  final Period? targetPeriod;
}

@immutable
class SourceSession extends Slot {
  const SourceSession({
    required this.id,
    required this.classId,
    required this.title,
    required this.version,
    required this.assignment,
    required super.startsAt,
    required super.endsAt,
    this.className,
  });
  final String id;
  final String classId;
  final String? className;
  final String title;
  final int version;
  final SessionAssignment assignment;
}

@immutable
class Preview {
  const Preview({
    required this.sources,
    required this.sourceVersions,
    required this.noticeEligible,
    this.noticeDeadline,
    required this.asOf,
  });
  final List<SourceSession> sources;
  final List<({String sessionId, int version})> sourceVersions;
  final bool noticeEligible;
  final DateTime? noticeDeadline;
  final DateTime asOf;
}

@immutable
class LeaveItem extends Slot {
  const LeaveItem({
    required this.id,
    required this.classId,
    required this.sourceSessionId,
    required this.sourceStartsAt,
    required this.sourceEndsAt,
    required this.replacementSessionId,
    required super.startsAt,
    required super.endsAt,
  });
  final String id;
  final String classId;
  final String sourceSessionId;
  final DateTime sourceStartsAt;
  final DateTime sourceEndsAt;
  final String? replacementSessionId;
}

typedef StudentConflictRef = ({String id, String sourceSessionId});

@immutable
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.mentorId,
    required this.fromDate,
    required this.toDate,
    required this.period,
    required this.reason,
    required this.status,
    required this.version,
    required this.submittedAt,
    required this.expiresAt,
    required this.itemCount,
    required this.items,
    this.sourcesCurrent = false,
    this.studentConflictCount,
    this.studentConflicts = const [],
    this.review,
    this.classExtensions = const [],
  });
  final String id;
  final String mentorId;
  final String fromDate;
  final String toDate;
  final Period period;
  final String reason;
  final LeaveStatus status;
  final int version;
  final DateTime submittedAt;
  final DateTime expiresAt;
  final int itemCount;
  final List<LeaveItem> items;
  final bool sourcesCurrent;
  final int? studentConflictCount;
  final List<StudentConflictRef> studentConflicts;
  final ({String reason, DateTime reviewedAt})? review;
  final List<({String classId, String endDate})> classExtensions;

  LeaveRequest copyWith({
    List<LeaveItem>? items,
    List<StudentConflictRef>? studentConflicts,
  }) => LeaveRequest(
    id: id,
    mentorId: mentorId,
    fromDate: fromDate,
    toDate: toDate,
    period: period,
    reason: reason,
    status: status,
    version: version,
    submittedAt: submittedAt,
    expiresAt: expiresAt,
    itemCount: itemCount,
    items: items ?? this.items,
    sourcesCurrent: sourcesCurrent,
    studentConflictCount: studentConflictCount,
    studentConflicts: studentConflicts ?? this.studentConflicts,
    review: review,
    classExtensions: classExtensions,
  );
}

@immutable
class Conflict {
  const Conflict({
    required this.id,
    required this.version,
    required this.status,
    required this.placementId,
    required this.placementVersion,
    required this.studentName,
    required this.source,
    required this.intervals,
  });
  final String id;
  final int version;
  final ConflictStatus status;
  final String? placementId;
  final int? placementVersion;
  final String? studentName;
  final SourceSession source;
  final List<Slot> intervals;
}

typedef Candidate = ({
  SourceSession session,
  String? mentorName,
  int remainingCapacity,
});
typedef LeaveOption = ({String id, String name});

@immutable
class LeaveData {
  const LeaveData({
    this.total = 0,
    this.requests,
    this.request,
    this.preview,
    this.slots,
    this.sessionVersion,
    this.conflicts,
    this.candidates,
    this.options,
    this.replacements,
    this.placedSession,
  });
  final int total;
  final List<LeaveRequest>? requests;
  final LeaveRequest? request;
  final Preview? preview;
  final List<Slot>? slots;
  final int? sessionVersion;
  final List<Conflict>? conflicts;
  final List<Candidate>? candidates;
  final List<LeaveOption>? options;
  final List<SourceSession>? replacements;
  final SourceSession? placedSession;

  int get count =>
      requests?.length ??
      conflicts?.length ??
      candidates?.length ??
      options?.length ??
      request?.items.length ??
      0;

  /// `mergeData` của hooks.ts.
  LeaveData mergeNext(LeaveData next) {
    List<T> unique<T>(List<T>? a, List<T>? b, String Function(T) id) {
      final map = <String, T>{};
      for (final x in [...?a, ...?b]) {
        map[id(x)] = x;
      }
      return map.values.toList();
    }

    return LeaveData(
      total: next.total,
      requests: next.requests == null
          ? null
          : unique(requests, next.requests, (r) => r.id),
      conflicts: next.conflicts == null
          ? null
          : unique(conflicts, next.conflicts, (c) => c.id),
      candidates: next.candidates == null
          ? null
          : unique(candidates, next.candidates, (c) => c.session.id),
      options: next.options == null
          ? null
          : unique(options, next.options, (o) => o.id),
      request: next.request?.copyWith(
        items: unique(request?.items, next.request!.items, (i) => i.id),
        studentConflicts: unique(
          request?.studentConflicts,
          next.request!.studentConflicts,
          (c) => c.id,
        ),
      ),
      preview: next.preview,
      slots: next.slots,
      sessionVersion: next.sessionVersion,
      replacements: next.replacements,
      placedSession: next.placedSession,
    );
  }
}

enum LeaveKind {
  list,
  detail,
  preview,
  slots,
  conflicts,
  candidates,
  classes,
  mentors,
}

@immutable
class LeaveReadRequest {
  const LeaveReadRequest({
    required this.kind,
    required this.role,
    this.id,
    this.status,
    this.mentorId,
    this.classId,
    this.page = 1,
    this.pageSize = 20,
    this.fromDate,
    this.toDate,
    this.period,
    this.targetDate,
    this.targetPeriod,
  });
  final LeaveKind kind;
  final LeaveRole role;
  final String? id;
  final String? status;
  final String? mentorId;
  final String? classId;
  final int page;
  final int pageSize;
  final String? fromDate;
  final String? toDate;
  final Period? period;
  final String? targetDate;
  final Period? targetPeriod;

  List<Object?> get _f => [
    kind,
    role,
    id,
    status,
    mentorId,
    classId,
    page,
    pageSize,
    fromDate,
    toDate,
    period,
    targetDate,
    targetPeriod,
  ];

  LeaveReadRequest withPage(int value) => LeaveReadRequest(
    kind: kind,
    role: role,
    id: id,
    status: status,
    mentorId: mentorId,
    classId: classId,
    page: value,
    pageSize: pageSize,
    fromDate: fromDate,
    toDate: toDate,
    period: period,
    targetDate: targetDate,
    targetPeriod: targetPeriod,
  );

  @override
  bool operator ==(Object other) =>
      other is LeaveReadRequest && listEquals(_f, other._f);

  @override
  int get hashCode => Object.hashAll(_f);
}

enum LeaveOutcomeKind { success, error, offline, denied, notFound, uncertain }

@immutable
class LeaveOutcome {
  const LeaveOutcome(this.kind, {this.data, this.code, this.requestId});
  final LeaveOutcomeKind kind;
  final LeaveData? data;
  final String? code;
  final String? requestId;
  bool get success => kind == LeaveOutcomeKind.success;
}

enum LeaveIntentKind { create, withdraw, approve, reject, place, cancel }

typedef SessionMapping = ({
  String sourceSessionId,
  String targetDate,
  Period targetPeriod,
  DateTime startsAt,
  DateTime endsAt,
});

@immutable
class LeaveIntent {
  const LeaveIntent({
    required this.kind,
    required this.role,
    this.id,
    this.key = '',
    this.reason = '',
    this.expectedVersion,
    this.fromDate,
    this.toDate,
    this.period,
    this.sourceVersions,
    this.sessionMappings,
    this.targetSessionId,
    this.expectedTargetVersion,
  });
  final LeaveIntentKind kind;
  final LeaveRole role;
  final String? id;
  final String key;
  final String reason;
  final int? expectedVersion;
  final String? fromDate;
  final String? toDate;
  final Period? period;
  final List<({String sessionId, int version})>? sourceVersions;
  final List<SessionMapping>? sessionMappings;
  final String? targetSessionId;
  final int? expectedTargetVersion;

  LeaveIntent withKey(String value) => LeaveIntent(
    kind: kind,
    role: role,
    id: id,
    key: value,
    reason: reason,
    expectedVersion: expectedVersion,
    fromDate: fromDate,
    toDate: toDate,
    period: period,
    sourceVersions: sourceVersions == null
        ? null
        : List.unmodifiable(sourceVersions!),
    sessionMappings: sessionMappings == null
        ? null
        : List.unmodifiable(sessionMappings!),
    targetSessionId: targetSessionId,
    expectedTargetVersion: expectedTargetVersion,
  );

  Map<String, Object?> body() => switch (kind) {
    LeaveIntentKind.create => {
      'fromDate': fromDate,
      'toDate': toDate,
      'period': period?.name,
      'reason': reason.trim(),
      'sourceVersions': [
        for (final v
            in sourceVersions ?? const <({String sessionId, int version})>[])
          {'sessionId': v.sessionId, 'version': v.version},
      ],
      'sessionMappings': [
        for (final m in sessionMappings ?? const <SessionMapping>[])
          {
            'sourceSessionId': m.sourceSessionId,
            'targetDate': m.targetDate,
            'targetPeriod': m.targetPeriod.name,
            'startsAt': m.startsAt.toUtc().toIso8601String(),
            'endsAt': m.endsAt.toUtc().toIso8601String(),
          },
      ],
    },
    LeaveIntentKind.approve => {
      'expectedVersion': expectedVersion,
      'reason': reason.trim(),
      'acknowledgeStudentConflicts': false,
    },
    LeaveIntentKind.place => {
      'expectedVersion': expectedVersion,
      'reason': reason.trim(),
      'targetSessionId': targetSessionId,
      'expectedTargetVersion': expectedTargetVersion,
      'contentMatchConfirmed': true,
    },
    _ => {'expectedVersion': expectedVersion, 'reason': reason.trim()},
  };
}

// ---- model.ts

const leaveStatuses = LeaveStatus.values;
const periods = Period.values;

/// `conflictMode`: NEEDS_PLACEMENT | NEEDS_REASSIGNMENT | MAKEUP_ASSIGNED | RESOLVED.
String conflictMode(Conflict value) {
  if (value.status == ConflictStatus.OPEN) {
    return value.placementId != null ? 'NEEDS_REASSIGNMENT' : 'NEEDS_PLACEMENT';
  }
  if (value.placementId == null) {
    throw const RemoteError(
      RemoteFailure.error,
      code: 'INVALID_LEAVE_RESPONSE',
    );
  }
  return value.status.name;
}

bool validDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final d = DateTime.tryParse('${value}T00:00:00Z');
  return d != null && d.toIso8601String().substring(0, 10) == value;
}

/// `invalid` | `before` | `max` | null.
String? dateRangeError(String from, String to) {
  if (!validDay(from) || !validDay(to)) return 'invalid';
  final diff = DateTime.parse(
    '${to}T00:00:00Z',
  ).difference(DateTime.parse('${from}T00:00:00Z')).inDays;
  return diff < 0
      ? 'before'
      : diff >= 93
      ? 'max'
      : null;
}

bool validReason(String value) =>
    value.trim().isNotEmpty && value.trim().length <= 1000;

String _two(int v) => v.toString().padLeft(2, '0');

DateTime _vn(DateTime value) => value.toUtc().add(const Duration(hours: 7));

/// `YYYY-MM-DD` → `DD/MM/YYYY`.
String dateLabel(String value) =>
    value.substring(0, 10).split('-').reversed.join('/');

String timeLabel(DateTime value) {
  final d = _vn(value);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// Ngày `YYYY-MM-DD` theo giờ Việt Nam.
String vietnamDay([DateTime? value]) =>
    _vn(value ?? DateTime.now()).toIso8601String().substring(0, 10);

String instantLabel(DateTime value) =>
    '${timeLabel(value)} ${dateLabel(vietnamDay(value))}';

String rangeLabel(String from, String to) =>
    from == to ? dateLabel(from) : '${dateLabel(from)} – ${dateLabel(to)}';

String slotLabel(Slot value) =>
    '${dateLabel(vietnamDay(value.startsAt))} · ${timeLabel(value.startsAt)}–${timeLabel(value.endsAt)}';

const _hours = {
  Period.MORNING: (0, 12),
  Period.AFTERNOON: (12, 18),
  Period.EVENING: (18, 24),
  Period.FULL_DAY: (0, 24),
};

bool overlaps(Slot a, Slot b) =>
    a.startsAt.isBefore(b.endsAt) && a.endsAt.isAfter(b.startsAt);

bool slotAllowed(
  Slot slot,
  ({String fromDate, String toDate, Period period}) range,
  List<Slot> others,
) {
  if (others.any((o) => overlaps(slot, o))) return false;
  final (start, end) = _hours[range.period]!;
  final last = DateTime.parse('${range.toDate}T00:00:00Z');
  for (
    var date = DateTime.parse('${range.fromDate}T00:00:00Z');
    !date.isAfter(last);
    date = date.add(const Duration(days: 1))
  ) {
    final midnight = date.subtract(const Duration(hours: 7));
    if (overlaps(
      slot,
      Slot(
        startsAt: midnight.add(Duration(hours: start)),
        endsAt: midnight.add(Duration(hours: end)),
      ),
    )) {
      return false;
    }
  }
  return true;
}

Map<String, Mapping> reconcileMappings(
  Map<String, Mapping> mappings,
  Preview preview,
) => {
  for (final e in mappings.entries)
    if (preview.sources.any(
      (s) => s.id == e.key && s.version == e.value.version,
    ))
      e.key: e.value,
};

int leaveRequestBytes(Object body) => Uri.encodeComponent(
  jsonEncode(body),
).replaceAll(RegExp(r'%[A-F\d]{2}', caseSensitive: false), 'x').length;

// ---- service

final leaveServiceProvider = Provider((ref) {
  final epoch = ref.watch(sessionEpochProvider);
  final api = ref.watch(apiClientProvider);
  return LeaveService(
    api,
    canUse: (role) =>
        ref.mounted &&
        ref.read(sessionEpochProvider) == epoch &&
        ref.read(sessionProvider).user?.role.name == role.name,
  );
});

const _err = 'INVALID_LEAVE_RESPONSE';

class LeaveService {
  LeaveService(this._api, {bool Function(LeaveRole)? canUse})
    : _canUse = canUse ?? ((_) => true);
  final ApiClient _api;
  final bool Function(LeaveRole) _canUse;

  static String _prefix(LeaveRole role) => role == LeaveRole.MENTOR
      ? 'mentor/leave-requests'
      : 'management/mentor-leave-requests';

  static int _version(Json j, String key) {
    final v = j.integer(key);
    if (v < 1) j.fail();
    return v;
  }

  static SourceSession _session(Json j) {
    j.dateTime('asOf');
    j.uuid('classUnitId');
    j.enumOf('status', SessionStatus.values);
    final mentor = j.obj('primaryMentor');
    mentor.uuid('id');
    mentor.strOrNull('displayName');
    final effective = j.objOrNull('effectiveMentor');
    effective?.uuid('id');
    effective?.strOrNull('displayName');
    j.uuidOrNull('makeupForSessionId');
    j.uuidOrNull('makeupRootSessionId');
    j.dateTimeOrNull('actualStartedAt');
    j.dateTimeOrNull('actualEndedAt');
    j.objOrNull('capabilities')?.boolean('readSessionContext');
    return SourceSession(
      id: j.uuid('sessionId'),
      classId: j.uuid('classId'),
      className: j.has('className') ? j.strOrNull('className') : null,
      title: j.str('title'),
      startsAt: j.dateTime('startsAt'),
      endsAt: j.dateTime('endsAt'),
      version: _version(j, 'version'),
      assignment: j.enumOf('assignmentType', SessionAssignment.values),
    );
  }

  static SourceSession _placement(Json j) {
    j.uuid('id');
    j.uuid('conflictId');
    _version(j, 'version');
    if (!const [
      'ASSIGNED',
      'COMPLETED',
      'CANCELLED',
      'NEEDS_REASSIGNMENT',
    ].contains(j.str('status'))) {
      j.fail();
    }
    return _session(j.obj('targetSession'));
  }

  static String _day(Json j, String key) {
    final value = j.str(key);
    if (!validDay(value)) j.fail();
    return value;
  }

  static Slot _slot(Json j) =>
      Slot(startsAt: j.dateTime('startsAt'), endsAt: j.dateTime('endsAt'));

  static LeaveRequest _leave(Json j, {bool manager = false}) {
    final review = j.objOrNull('review');
    review?.uuid('reviewerId');
    final items = j.list('items', (i) {
      final id = i.uuid('sourceSessionId');
      _version(i, 'sourceVersion');
      return LeaveItem(
        id: id,
        classId: i.uuid('classId'),
        sourceSessionId: id,
        sourceStartsAt: i.dateTime('sourceStartsAt'),
        sourceEndsAt: i.dateTime('sourceEndsAt'),
        replacementSessionId: i.uuidOrNull('replacementSessionId'),
        startsAt: i.dateTime('startsAt'),
        endsAt: i.dateTime('endsAt'),
      );
    });
    final count = j.integer('itemCount');
    final pageSize = _version(j, 'pageSize');
    if (count < 0 || pageSize > 100) j.fail();
    _version(j, 'page');
    j.dateTime('asOf');
    j.str('timeZone');
    final conflictCount = j.raw('studentConflictCount') == null
        ? null
        : j.integer('studentConflictCount');
    if ((manager && conflictCount == null) ||
        (conflictCount != null && conflictCount < 0)) {
      j.fail();
    }
    return LeaveRequest(
      id: j.uuid('id'),
      mentorId: j.uuid('mentorId'),
      fromDate: _day(j, 'fromDate'),
      toDate: _day(j, 'toDate'),
      period: j.enumOf('period', Period.values),
      reason: j.str('reason'),
      status: j.enumOf('status', LeaveStatus.values),
      version: _version(j, 'version'),
      submittedAt: j.dateTime('submittedAt'),
      expiresAt: j.dateTime('expiresAt'),
      itemCount: count,
      items: items,
      studentConflictCount: conflictCount,
      review: review == null
          ? null
          : (
              reason: review.str('reason'),
              reviewedAt: review.dateTime('reviewedAt'),
            ),
      classExtensions: j.list(
        'classExtensions',
        (e) => (classId: e.uuid('classId'), endDate: _day(e, 'endDate')),
      ),
      sourcesCurrent: manager && j.boolean('sourcesCurrent'),
      studentConflicts: manager
          ? j.list('studentConflicts', (c) {
              final source = c.uuid('sourceSessionId');
              return (
                id: '$source:${c.uuid('studentId')}:${c.uuid('conflictingSessionId')}',
                sourceSessionId: source,
              );
            })
          : const [],
    );
  }

  static Paged<T> _page<T>(Object? body, T Function(Json) parse) {
    final j = Json(body, _err);
    final p = Paged.fromJson(j, parse);
    if (p.page < 1 ||
        p.pageSize < 1 ||
        p.pageSize > 100 ||
        p.total < 0 ||
        p.items.length > p.total ||
        p.items.length > p.pageSize) {
      j.fail();
    }
    return p;
  }

  Future<Object?> _get(
    String path, [
    Map<String, Object?> query = const {},
  ]) async {
    try {
      final Object? body = await _api.get(path, query: query);
      return body;
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  Future<Object?> _postRead(String path, Map<String, Object?> body) async {
    try {
      final Object? res = await _api.post(path, body: body);
      return res;
    } catch (e) {
      throw RemoteError.from(e);
    }
  }

  static LeaveOutcome _fail(Object e) {
    if (e is RemoteError) {
      final kind = switch (e.kind) {
        RemoteFailure.offline => LeaveOutcomeKind.offline,
        RemoteFailure.denied => LeaveOutcomeKind.denied,
        RemoteFailure.notFound => LeaveOutcomeKind.notFound,
        _ => LeaveOutcomeKind.error,
      };
      return LeaveOutcome(kind, code: e.code, requestId: e.requestId);
    }
    return const LeaveOutcome(LeaveOutcomeKind.error, code: 'INVALID_RESPONSE');
  }

  Future<LeaveOutcome> read(LeaveReadRequest r) async {
    try {
      if (!_canUse(r.role)) return const LeaveOutcome(LeaveOutcomeKind.denied);
      if (r.page < 1 || r.pageSize < 1 || r.pageSize > 100) {
        return const LeaveOutcome(
          LeaveOutcomeKind.error,
          code: 'INVALID_INPUT',
        );
      }
      if ((const [LeaveKind.preview, LeaveKind.slots].contains(r.kind) &&
              r.role != LeaveRole.MENTOR) ||
          (const [
                LeaveKind.conflicts,
                LeaveKind.candidates,
                LeaveKind.mentors,
              ].contains(r.kind) &&
              r.role != LeaveRole.MANAGER)) {
        return const LeaveOutcome(LeaveOutcomeKind.denied);
      }
      final paging = {'page': r.page, 'pageSize': r.pageSize};
      final LeaveData data;
      switch (r.kind) {
        case LeaveKind.list:
          if (r.status != null &&
              !LeaveStatus.values.any((s) => s.name == r.status)) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'INVALID_INPUT',
            );
          }
          final body = _page(
            await _get(_prefix(r.role), {
              ...paging,
              'status': ?r.status,
              if (r.role == LeaveRole.MANAGER && r.mentorId != null)
                'mentorId': resourceId(r.mentorId),
            }),
            _leave,
          );
          data = LeaveData(total: body.total, requests: body.items);
        case LeaveKind.detail:
          final manager = r.role == LeaveRole.MANAGER;
          final request = _leave(
            Json(
              await _get('${_prefix(r.role)}/${resourceId(r.id)}', paging),
              _err,
            ),
            manager: manager,
          );
          if (request.id != r.id) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'RESOURCE_MISMATCH',
            );
          }
          data = LeaveData(total: request.itemCount, request: request);
        case LeaveKind.preview:
          final from = r.fromDate ?? '', to = r.toDate ?? '';
          if (!validDay(from) ||
              !validDay(to) ||
              from.compareTo(to) > 0 ||
              r.period == null) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'INVALID_INPUT',
            );
          }
          final j = Json(
            await _postRead('mentor/leave-requests/preview', {
              'fromDate': from,
              'toDate': to,
              'period': r.period!.name,
            }),
            _err,
          );
          final sources = j.list('affectedSessions', _session);
          final versions = j.list(
            'sourceVersions',
            (v) => (
              sessionId: v.uuid('sessionId'),
              version: _version(v, 'version'),
            ),
          );
          j.str('timeZone');
          if (sources.length > 500 ||
              sources.length != versions.length ||
              sources.any(
                (s) => !versions.any(
                  (v) => v.sessionId == s.id && v.version == s.version,
                ),
              )) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'INVALID_RESPONSE',
            );
          }
          data = LeaveData(
            total: sources.length,
            preview: Preview(
              sources: sources,
              sourceVersions: versions,
              noticeEligible: j.boolean('noticeEligible'),
              noticeDeadline: j.dateTimeOrNull('noticeDeadline'),
              asOf: j.dateTime('asOf'),
            ),
          );
        case LeaveKind.slots:
          if (!isUuid(r.id) ||
              !validDay(r.targetDate ?? '') ||
              r.targetPeriod == null) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'INVALID_INPUT',
            );
          }
          final j = Json(
            await _postRead('mentor/leave-requests/makeup-slots', {
              'sourceSessionId': r.id,
              'targetDate': r.targetDate,
              'targetPeriod': r.targetPeriod!.name,
            }),
            _err,
          );
          final slots = j.list('slots', _slot);
          j.dateTime('asOf');
          j.str('timeZone');
          data = LeaveData(
            total: slots.length,
            slots: slots,
            sessionVersion: _version(j, 'sessionVersion'),
          );
        case LeaveKind.conflicts:
          if (r.status != null &&
              !ConflictStatus.values.any((s) => s.name == r.status)) {
            return const LeaveOutcome(
              LeaveOutcomeKind.error,
              code: 'INVALID_INPUT',
            );
          }
          final body = _page(
            await _get('management/student-schedule-conflicts', {
              ...paging,
              'status': ?r.status,
              if (r.classId != null) 'classId': resourceId(r.classId),
            }),
            (c) {
              final placementVersion = c.raw('makeupPlacementVersion') == null
                  ? null
                  : _version(c, 'makeupPlacementVersion');
              final status = c.enumOf('status', ConflictStatus.values);
              final placementId = c.uuidOrNull('makeupPlacementId');
              if (status != ConflictStatus.OPEN && placementId == null) {
                c.fail();
              }
              c.obj('student').uuid('id');
              return Conflict(
                id: c.uuid('id'),
                version: _version(c, 'version'),
                status: status,
                placementId: placementId,
                placementVersion: placementVersion,
                studentName: c.obj('student').strOrNull('displayName'),
                source: _session(c.obj('sourceSession')),
                intervals: c.list('conflictingIntervals', (i) {
                  i.uuid('sessionId');
                  return _slot(i);
                }),
              );
            },
          );
          data = LeaveData(total: body.total, conflicts: body.items);
        case LeaveKind.candidates:
          final body = _page(
            await _get(
              'management/student-schedule-conflicts/${resourceId(r.id)}/makeup-candidates',
              paging,
            ),
            (c) {
              final s = c.obj('session');
              final capacity = c.integer('remainingCapacity');
              if (capacity < 0) c.fail();
              return (
                session: _session(s),
                remainingCapacity: capacity,
                mentorName: s
                    .objOrNull('effectiveMentor')
                    ?.strOrNull('displayName'),
              );
            },
          );
          data = LeaveData(total: body.total, candidates: body.items);
        case LeaveKind.classes:
          final body = _page(
            await _get(
              r.role == LeaveRole.MENTOR ? 'mentor/classes' : 'manager/classes',
              paging,
            ),
            (c) => (id: c.uuid('id'), name: c.str('name')),
          );
          data = LeaveData(total: body.total, options: body.items);
        case LeaveKind.mentors:
          if (r.id != null) {
            final j = Json(
              await _get('manager/mentors/${resourceId(r.id)}'),
              _err,
            );
            final id = j.uuid('id');
            if (id != r.id) {
              return const LeaveOutcome(
                LeaveOutcomeKind.error,
                code: 'RESOURCE_MISMATCH',
              );
            }
            data = LeaveData(
              total: 1,
              options: [(id: id, name: j.strOrNull('displayName') ?? '')],
            );
          } else {
            final body = _page(
              await _get('manager/mentors', paging),
              (p) => (id: p.uuid('id'), name: p.strOrNull('displayName') ?? ''),
            );
            data = LeaveData(total: body.total, options: body.items);
          }
      }
      if (!_canUse(r.role)) return const LeaveOutcome(LeaveOutcomeKind.denied);
      return LeaveOutcome(LeaveOutcomeKind.success, data: data);
    } catch (e) {
      if (!_canUse(r.role)) return const LeaveOutcome(LeaveOutcomeKind.denied);
      return _fail(e is RemoteError ? e : RemoteError.from(e));
    }
  }

  static bool _validBody(LeaveIntent i) {
    if (!isUuid(i.key)) return false;
    if (i.kind == LeaveIntentKind.create) {
      final from = i.fromDate ?? '', to = i.toDate ?? '';
      final versions = i.sourceVersions ?? const [],
          maps = i.sessionMappings ?? const [];
      return validDay(from) &&
          validDay(to) &&
          from.compareTo(to) <= 0 &&
          i.period != null &&
          validReason(i.reason) &&
          versions.isNotEmpty &&
          versions.length <= 500 &&
          versions.length == maps.length &&
          versions.every((v) => isUuid(v.sessionId) && v.version >= 1) &&
          versions.map((v) => v.sessionId).toSet().length == versions.length &&
          maps.map((m) => m.sourceSessionId).toSet().length == maps.length &&
          maps.every(
            (m) =>
                validDay(m.targetDate) &&
                m.startsAt.isBefore(m.endsAt) &&
                versions.any((v) => v.sessionId == m.sourceSessionId),
          );
    }
    if ((i.expectedVersion ?? 0) < 1 || !validReason(i.reason) || !isUuid(i.id)) {
      return false;
    }
    if (i.kind == LeaveIntentKind.place) {
      return isUuid(i.targetSessionId) && (i.expectedTargetVersion ?? 0) >= 1;
    }
    return true;
  }

  Future<LeaveOutcome> write(LeaveIntent intent) async {
    var dispatched = false;
    try {
      if (!_canUse(intent.role)) {
        return const LeaveOutcome(LeaveOutcomeKind.denied);
      }
      final mentorKind = const [
        LeaveIntentKind.create,
        LeaveIntentKind.withdraw,
      ].contains(intent.kind);
      if ((mentorKind ? LeaveRole.MENTOR : LeaveRole.MANAGER) != intent.role) {
        return const LeaveOutcome(LeaveOutcomeKind.denied);
      }
      if (!_validBody(intent)) {
        return const LeaveOutcome(
          LeaveOutcomeKind.error,
          code: 'INVALID_INPUT',
        );
      }
      final target = switch (intent.kind) {
        LeaveIntentKind.create => 'mentor/leave-requests',
        LeaveIntentKind.place =>
          'management/student-schedule-conflicts/${resourceId(intent.id)}/makeup-placement',
        LeaveIntentKind.cancel =>
          'management/makeup-placements/${resourceId(intent.id)}/cancel',
        _ =>
          '${_prefix(intent.role)}/${resourceId(intent.id)}/${intent.kind.name}',
      };
      dispatched = true;
      Object? response;
      try {
        response = await _api.post(
          target,
          body: intent.body(),
          headers: {'Idempotency-Key': intent.key},
        );
      } on ApiError catch (e) {
        if (e.isNetwork) {
          return LeaveOutcome(
            LeaveOutcomeKind.uncertain,
            code: 'NETWORK',
            requestId: e.requestId,
          );
        }
        final kind = e.status == 401 || e.status == 403
            ? LeaveOutcomeKind.denied
            : e.status == 404
            ? LeaveOutcomeKind.notFound
            : (e.status >= 500 || e.status == 408)
            ? LeaveOutcomeKind.uncertain
            : LeaveOutcomeKind.error;
        return LeaveOutcome(kind, code: e.code, requestId: e.requestId);
      }
      final j = Json(response, _err);
      if (!_canUse(intent.role)) {
        return const LeaveOutcome(LeaveOutcomeKind.denied);
      }
      if (intent.kind == LeaveIntentKind.place) {
        final p = j.obj('placement');
        final session = _placement(p);
        _version(j, 'conflictVersion');
        _version(j, 'targetSessionVersion');
        if (p.uuid('conflictId') != intent.id ||
            session.id != intent.targetSessionId ||
            p.str('status') != 'ASSIGNED') {
          return const LeaveOutcome(LeaveOutcomeKind.uncertain);
        }
        return LeaveOutcome(
          LeaveOutcomeKind.success,
          data: LeaveData(placedSession: session),
        );
      }
      if (intent.kind == LeaveIntentKind.cancel) {
        _placement(j);
        if (j.uuid('id') != intent.id || j.str('status') != 'CANCELLED') {
          return const LeaveOutcome(LeaveOutcomeKind.uncertain);
        }
        return const LeaveOutcome(LeaveOutcomeKind.success, data: LeaveData());
      }
      final approve = intent.kind == LeaveIntentKind.approve;
      if (approve) {
        if (j.integer('studentConflictCount') < 0) j.fail();
        j.list(
          'classExtensions',
          (e) => (classId: e.uuid('classId'), endDate: _day(e, 'endDate')),
        );
      }
      final result = _leave(approve ? j.obj('request') : j);
      final expected = switch (intent.kind) {
        LeaveIntentKind.create => LeaveStatus.PENDING,
        LeaveIntentKind.withdraw => LeaveStatus.WITHDRAWN,
        LeaveIntentKind.approve => LeaveStatus.APPROVED,
        _ => LeaveStatus.REJECTED,
      };
      if ((intent.id != null && result.id != intent.id) ||
          result.status != expected) {
        return const LeaveOutcome(LeaveOutcomeKind.uncertain);
      }
      return LeaveOutcome(
        LeaveOutcomeKind.success,
        data: LeaveData(
          total: result.itemCount,
          request: result,
          replacements: approve ? j.list('replacements', _session) : null,
        ),
      );
    } catch (e) {
      if (e is RemoteError) return _fail(e);
      return LeaveOutcome(
        dispatched ? LeaveOutcomeKind.uncertain : LeaveOutcomeKind.error,
        code: dispatched ? 'INVALID_RESPONSE' : 'INVALID_INPUT',
      );
    }
  }
}
