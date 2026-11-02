// ignore_for_file: constant_identifier_names
import 'package:flutter/foundation.dart';

import '../shared/remote.dart';

/// Clone `modules/teaching/types/index.ts`. Tên enum giữ đúng giá trị wire.
enum TeachingRole { MENTOR, MANAGER }

enum ClassStatus { DRAFT, OPEN, IN_PROGRESS, COMPLETED, CANCELLED }

enum SessionStatus { SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED }

enum OrderStatus { PAID, PENDING, EXPIRED, CANCELLED }

enum EnrollmentStatus { ACTIVE, PENDING_PAYMENT, COMPLETED, CANCELLED }

enum ClassScope { CLASS, SESSION }

enum ClassAssignment { PRIMARY, SUBSTITUTE, BOTH }

enum SessionAssignment { PRIMARY, SUBSTITUTE }

enum DeliveryMode { ONLINE, OFFLINE }

enum PaymentMethod { CASH, PAYOS }

enum StudentStatus { ACTIVE, SUSPENDED, PENDING_VERIFICATION }

enum Admission { REGULAR, MAKEUP }

@immutable
class TeachingClass {
  const TeachingClass({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.scope,
    required this.assignment,
    this.mentor,
    this.startDate,
    this.endDate,
    this.deliveryMode,
    this.availableSeats,
    this.maxStudents,
    this.course = '',
    this.readClassRoster = false,
    this.readClassReports = false,
    this.authorMaterials = false,
    this.unitCount,
    this.sessionCount,
    this.currentUnit,
    this.elapsedSessions,
    this.meetingUrl,
    this.scheduleDays = const [],
    this.scheduleTime,
    this.room,
    this.nextSessionAt,
    this.enrollmentCounts = const {},
  });

  final String id;
  final String name;
  final String code;
  final ClassStatus status;
  final ClassScope scope;
  final ClassAssignment assignment;
  final String? mentor;

  /// `YYYY-MM-DD`.
  final String? startDate;
  final String? endDate;
  final DeliveryMode? deliveryMode;
  final int? availableSeats;
  final int? maxStudents;
  final String course;
  final bool readClassRoster;
  final bool readClassReports;
  final bool authorMaterials;
  final int? unitCount;
  final int? sessionCount;
  final int? currentUnit;
  final int? elapsedSessions;
  final String? meetingUrl;

  /// Thứ trong tuần, 0 = Thứ Hai.
  final List<int> scheduleDays;
  final String? scheduleTime;
  final String? room;
  final DateTime? nextSessionAt;
  final Map<EnrollmentStatus, int> enrollmentCounts;

  TeachingClass copyWith({
    String? course,
    String? room,
    int? unitCount,
    int? sessionCount,
    int? elapsedSessions,
    List<int>? scheduleDays,
    String? scheduleTime,
    DateTime? nextSessionAt,
    bool clearNextSession = false,
    Map<EnrollmentStatus, int>? enrollmentCounts,
  }) => TeachingClass(
    id: id,
    name: name,
    code: code,
    status: status,
    scope: scope,
    assignment: assignment,
    mentor: mentor,
    startDate: startDate,
    endDate: endDate,
    deliveryMode: deliveryMode,
    availableSeats: availableSeats,
    maxStudents: maxStudents,
    course: course ?? this.course,
    readClassRoster: readClassRoster,
    readClassReports: readClassReports,
    authorMaterials: authorMaterials,
    unitCount: unitCount ?? this.unitCount,
    sessionCount: sessionCount ?? this.sessionCount,
    currentUnit: currentUnit,
    elapsedSessions: elapsedSessions ?? this.elapsedSessions,
    meetingUrl: meetingUrl,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    scheduleTime: scheduleTime ?? this.scheduleTime,
    room: room ?? this.room,
    nextSessionAt: clearNextSession ? null : (nextSessionAt ?? this.nextSessionAt),
    enrollmentCounts: enrollmentCounts ?? this.enrollmentCounts,
  );
}

@immutable
class TeachingSession {
  const TeachingSession({
    required this.id,
    required this.classId,
    required this.unitId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.assignment,
    required this.readSessionContext,
    required this.version,
    this.asOf,
    this.makeupForSessionId,
    this.effectiveMentor,
    this.effectiveMentorId,
    this.primaryMentor,
    this.room,
    this.meetingUrl,
    this.makeup = false,
    this.actualStart,
    this.actualEnd,
  });

  final String id;
  final DateTime? asOf;
  final String? makeupForSessionId;
  final String classId;
  final String unitId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final SessionStatus status;
  final SessionAssignment assignment;
  final bool readSessionContext;
  final String? effectiveMentor;
  final String? effectiveMentorId;
  final String? primaryMentor;
  final String? room;
  final String? meetingUrl;
  final int version;
  final bool makeup;
  final DateTime? actualStart;
  final DateTime? actualEnd;

  TeachingSession withContext({String? room, String? meetingUrl}) => TeachingSession(
    id: id,
    asOf: asOf,
    makeupForSessionId: makeupForSessionId,
    classId: classId,
    unitId: unitId,
    title: title,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status,
    assignment: assignment,
    readSessionContext: readSessionContext,
    effectiveMentor: effectiveMentor,
    effectiveMentorId: effectiveMentorId,
    primaryMentor: primaryMentor,
    room: room,
    meetingUrl: meetingUrl,
    version: version,
    makeup: makeup,
    actualStart: actualStart,
    actualEnd: actualEnd,
  );
}

@immutable
class TeachingStudent {
  const TeachingStudent({
    required this.id,
    this.name,
    this.enrollment,
    this.order,
    this.method,
    this.paidAt,
    this.expiresAt,
    this.email,
    this.phone,
    this.studentStatus,
    this.admission = Admission.REGULAR,
  });

  final String id;
  final String? name;
  final EnrollmentStatus? enrollment;
  final OrderStatus? order;
  final PaymentMethod? method;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final String? email;
  final String? phone;
  final StudentStatus? studentStatus;
  final Admission admission;
}

@immutable
class TeachingUnit {
  const TeachingUnit({required this.id, required this.position, required this.title, this.courseUnitId});
  final String id;
  final int position;
  final String title;
  final String? courseUnitId;
}

@immutable
class TeachingData {
  const TeachingData({
    this.classes = const [],
    this.sessions = const [],
    this.students = const [],
    this.units = const [],
    this.total = 0,
    this.classInfo,
    this.session,
  });

  final List<TeachingClass> classes;
  final List<TeachingSession> sessions;
  final List<TeachingStudent> students;
  final List<TeachingUnit> units;
  final int total;
  final TeachingClass? classInfo;
  final TeachingSession? session;

  TeachingData copyWith({
    List<TeachingClass>? classes,
    List<TeachingSession>? sessions,
    List<TeachingStudent>? students,
    List<TeachingUnit>? units,
  }) => TeachingData(
    classes: classes ?? this.classes,
    sessions: sessions ?? this.sessions,
    students: students ?? this.students,
    units: units ?? this.units,
    total: total,
    classInfo: classInfo,
    session: session,
  );

  /// Gộp trang sau vào trang trước theo id (`merge` của useTeachingQuery).
  TeachingData mergeNext(TeachingData next) => TeachingData(
    classes: mergeById(classes, next.classes, (e) => e.id),
    sessions: mergeById(sessions, next.sessions, (e) => e.id),
    students: mergeById(students, next.students, (e) => e.id),
    units: mergeById(units, next.units, (e) => e.id),
    total: next.total,
    classInfo: next.classInfo,
    session: next.session,
  );
}

enum TeachingKind { classes, klass, schedule, context, students, sessionStudents, units, sessions }

@immutable
class TeachingRequest {
  const TeachingRequest({
    required this.kind,
    required this.role,
    this.classId,
    this.sessionId,
    this.unitId,
    this.status,
    this.q,
    this.from,
    this.to,
    this.page = 1,
    this.pageSize = 20,
    this.includeCardDetails = false,
  });

  final TeachingKind kind;
  final TeachingRole role;
  final String? classId;
  final String? sessionId;
  final String? unitId;
  final String? status;
  final String? q;

  /// ISO có offset, vd `2026-11-03T00:00:00+07:00`.
  final String? from;
  final String? to;
  final int page;
  final int pageSize;
  final bool includeCardDetails;

  TeachingRequest withPage(int value) => TeachingRequest(
    kind: kind,
    role: role,
    classId: classId,
    sessionId: sessionId,
    unitId: unitId,
    status: status,
    q: q,
    from: from,
    to: to,
    page: value,
    pageSize: pageSize,
    includeCardDetails: includeCardDetails,
  );

  List<Object?> get _fields => [kind, role, classId, sessionId, unitId, status, q, from, to, page, pageSize, includeCardDetails];

  @override
  bool operator ==(Object other) => other is TeachingRequest && listEquals(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}
