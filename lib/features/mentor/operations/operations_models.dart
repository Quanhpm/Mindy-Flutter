// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../../core/utils/format.dart';
import '../schedule/schedule_models.dart';

enum LeavePeriod { MORNING, AFTERNOON, EVENING, FULL_DAY }

enum LeaveStatus { PENDING, APPROVED, REJECTED, WITHDRAWN, EXPIRED }

typedef LeaveQuery = ({String fromDate, String toDate, LeavePeriod period});
typedef SlotQuery = ({String sessionId, String targetDate, LeavePeriod period});

class SourceVersion {
  const SourceVersion(this.sessionId, this.version);
  final String sessionId;
  final int version;
  factory SourceVersion.fromJson(Json j) {
    final version = j.integer('version');
    if (version < 1) j.fail();
    return SourceVersion(j.uuid('sessionId'), version);
  }
  Map<String, Object?> toJson() => {'sessionId': sessionId, 'version': version};
}

class LeavePreview {
  LeavePreview({
    required this.sessions,
    required this.versions,
    required this.eligible,
    required this.deadline,
    required this.asOf,
    required this.zone,
  });
  final List<TeachingSession> sessions;
  final List<SourceVersion> versions;
  final bool eligible;
  final DateTime? deadline;
  final DateTime asOf;
  final String zone;
  factory LeavePreview.fromJson(Json j) {
    final sessions = j.list('affectedSessions', TeachingSession.fromJson),
        versions = j.list('sourceVersions', SourceVersion.fromJson);
    final zone = j.nonEmpty('timeZone');
    if (!Dates.isValidZone(zone) ||
        sessions.any((s) => s.timeZone != zone) ||
        sessions.length > 500 ||
        sessions.length != versions.length ||
        sessions.map((s) => s.id).toSet().length != sessions.length ||
        versions.map((v) => v.sessionId).toSet().length != versions.length ||
        sessions.any((s) => !versions.any((v) => v.sessionId == s.id && v.version == s.version))) {
      j.fail();
    }
    return LeavePreview(
      sessions: List.unmodifiable(sessions),
      versions: List.unmodifiable(versions),
      eligible: j.boolean('noticeEligible'),
      deadline: j.dateTimeOrNull('noticeDeadline'),
      asOf: j.dateTime('asOf'),
      zone: zone,
    );
  }
}

class LeaveSlot {
  const LeaveSlot(this.startsAt, this.endsAt);
  final DateTime startsAt, endsAt;
  factory LeaveSlot.fromJson(Json j) {
    final start = j.dateTime('startsAt'), end = j.dateTime('endsAt');
    if (!end.isAfter(start)) j.fail();
    return LeaveSlot(start, end);
  }
}

class LeaveSlots {
  const LeaveSlots(this.items, this.version, this.zone);
  final List<LeaveSlot> items;
  final int version;
  final String zone;
  factory LeaveSlots.fromJson(Json j) {
    final zone = j.nonEmpty('timeZone'), version = j.integer('sessionVersion');
    if (!Dates.isValidZone(zone) || version < 1) j.fail();
    j.dateTime('asOf');
    return LeaveSlots(List.unmodifiable(j.list('slots', LeaveSlot.fromJson)), version, zone);
  }
}

class LeaveMapping {
  const LeaveMapping({required this.sessionId, required this.targetDate, required this.period, required this.slot});
  final String sessionId, targetDate;
  final LeavePeriod period;
  final LeaveSlot slot;
  Map<String, Object?> toJson() => {
    'sourceSessionId': sessionId,
    'targetDate': targetDate,
    'targetPeriod': period.name,
    'startsAt': slot.startsAt.toUtc().toIso8601String(),
    'endsAt': slot.endsAt.toUtc().toIso8601String(),
  };
}

class LeaveDraft {
  const LeaveDraft({required this.query, required this.reason, required this.preview, required this.mappings});
  final LeaveQuery query;
  final String reason;
  final LeavePreview preview;
  final List<LeaveMapping> mappings;
  Map<String, Object?> toJson() => {
    'fromDate': query.fromDate,
    'toDate': query.toDate,
    'period': query.period.name,
    'reason': reason.trim(),
    'sourceVersions': [for (final v in preview.versions) v.toJson()],
    // Backend hiện hỗ trợ sessionMappings cho mọi period, gồm FULL_DAY.
    'sessionMappings': [for (final mapping in mappings) mapping.toJson()],
  };
}

class LeaveItem {
  const LeaveItem(
    this.sessionId,
    this.classId,
    this.sourceStart,
    this.sourceEnd,
    this.start,
    this.end,
    this.replacementId,
  );
  final String sessionId, classId;
  final DateTime sourceStart, sourceEnd, start, end;
  final String? replacementId;
  factory LeaveItem.fromJson(Json j) {
    final version = j.integer('sourceVersion');
    final sourceStart = j.dateTime('sourceStartsAt'), sourceEnd = j.dateTime('sourceEndsAt');
    final start = j.dateTime('startsAt'), end = j.dateTime('endsAt');
    if (version < 1 || !sourceEnd.isAfter(sourceStart) || !end.isAfter(start)) {
      j.fail();
    }
    return LeaveItem(
      j.uuid('sourceSessionId'),
      j.uuid('classId'),
      sourceStart,
      sourceEnd,
      start,
      end,
      j.uuidOrNull('replacementSessionId'),
    );
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.from,
    required this.to,
    required this.period,
    required this.status,
    required this.reason,
    required this.version,
    required this.submitted,
    required this.expires,
    required this.zone,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.items,
    required this.extensions,
    required this.reviewReason,
    required this.conflicts,
    required this.asOf,
  });
  final String id, from, to, reason, zone;
  final LeavePeriod period;
  final LeaveStatus status;
  final int version, count, page, pageSize;
  final int? conflicts;
  final DateTime submitted, expires, asOf;
  final List<LeaveItem> items;
  final List<({String classId, String endDate})> extensions;
  final String? reviewReason;
  factory LeaveRequest.fromJson(Json j) {
    j.uuid('mentorId');
    final version = j.integer('version'),
        count = j.integer('itemCount'),
        page = j.integer('page'),
        size = j.integer('pageSize');
    final zone = j.nonEmpty('timeZone'), from = j.day('fromDate'), to = j.day('toDate');
    final items = j.list('items', LeaveItem.fromJson);
    final conflicts = j.has('studentConflictCount') ? j.integer('studentConflictCount') : null;
    if (version < 1 ||
        count < 0 ||
        page < 1 ||
        size < 1 ||
        items.length > size ||
        items.length > count ||
        to.compareTo(from) < 0 ||
        !Dates.isValidZone(zone) ||
        (conflicts != null && conflicts < 0)) {
      j.fail();
    }
    return LeaveRequest(
      id: j.uuid('id'),
      from: from,
      to: to,
      reason: j.str('reason'),
      period: j.enumOf('period', LeavePeriod.values),
      status: j.enumOf('status', LeaveStatus.values),
      version: version,
      count: count,
      page: page,
      pageSize: size,
      submitted: j.dateTime('submittedAt'),
      expires: j.dateTime('expiresAt'),
      asOf: j.dateTime('asOf'),
      zone: zone,
      items: List.unmodifiable(items),
      conflicts: conflicts,
      extensions: List.unmodifiable(
        j.list('classExtensions', (e) => (classId: e.uuid('classId'), endDate: e.day('endDate'))),
      ),
      reviewReason: j.objOrNull('review')?.str('reason'),
    );
  }
}

class LeaveDetail {
  const LeaveDetail(this.request, this.items);
  final LeaveRequest request;
  final List<LeaveItem> items;
}

class TeachingNote {
  const TeachingNote(this.sessionId, this.version, this.content, this.nextSteps);
  final String sessionId, content, nextSteps;
  final int version;
  factory TeachingNote.fromJson(Json j) {
    final version = j.integer('version'), note = j.objOrNull('note');
    if (version < 0 || (note != null && note.integer('version') != version) || (note == null && version != 0)) {
      j.fail();
    }
    return TeachingNote(j.uuid('sessionId'), version, note?.str('content') ?? '', note?.str('nextSteps') ?? '');
  }
}

class MeetingUpdate {
  const MeetingUpdate(this.sessionId, this.version, this.url, this.effectiveUrl);
  final String sessionId;
  final int version;
  final String? url, effectiveUrl;
  factory MeetingUpdate.fromJson(Json j) {
    j.uuid('classId');
    final version = j.integer('version');
    if (version < 1) j.fail();
    for (final key in ['meetingUrl', 'effectiveMeetingUrl']) {
      final raw = j.strOrNull(key);
      if (raw != null) {
        final uri = Uri.tryParse(raw);
        if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          j.fail();
        }
      }
    }
    return MeetingUpdate(j.uuid('sessionId'), version, j.strOrNull('meetingUrl'), j.strOrNull('effectiveMeetingUrl'));
  }
}
