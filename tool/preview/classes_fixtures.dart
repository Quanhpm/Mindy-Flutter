import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/reports/reports_models.dart';
import 'package:mindy_flutter/features/mentor/reports/reports_providers.dart';
import 'package:mindy_flutter/features/mentor/students/students_models.dart';
import 'package:mindy_flutter/features/mentor/students/students_providers.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import 'mentor_fixtures.dart';
import 'attendance_fixtures.dart';

String fixtureId(int n) => attendanceFixtureId(n);
final fixtureClassId = fixtureId(10);
MentorAttendanceCounts sampleCounts({int present = 8, int absent = 2}) => MentorAttendanceCounts(
  present: present,
  absent: absent,
  unmarked: 0,
  excluded: 1,
  makeupPending: 1,
  finalizedEligible: present + absent,
  rate: present + absent == 0 ? null : present * 100 / (present + absent),
);
MentorWorkspace sampleWorkspace({
  MentorClassStatus status = MentorClassStatus.IN_PROGRESS,
  bool substitute = false,
  String? id,
}) => MentorWorkspace(
  id: id ?? fixtureClassId,
  code: 'GTB1-07',
  name: 'Giao tiếp B1 · Lớp 07',
  courseId: fixtureId(5),
  courseTitle: 'Tiếng Anh giao tiếp',
  status: status,
  scope: substitute ? MentorClassScope.SESSION : MentorClassScope.CLASS,
  assignment: substitute ? MentorClassAssignment.SUBSTITUTE : MentorClassAssignment.PRIMARY,
  readonly: status == MentorClassStatus.COMPLETED || status == MentorClassStatus.CANCELLED,
  readClass: true,
  readRoster: !substitute,
  readReports: !substitute,
  authorMaterials: !substitute,
  unitCount: 1,
  sessionCount: 6,
  timeZone: previewZone,
  asOf: previewNow,
);
List<MentorClass> sampleClasses() => [
  for (final (index, status) in [
    MentorClassStatus.IN_PROGRESS,
    MentorClassStatus.OPEN,
    MentorClassStatus.COMPLETED,
    MentorClassStatus.CANCELLED,
  ].indexed)
    MentorClass(
      id: fixtureId(10 + index),
      courseId: fixtureId(5),
      code: index == 0 ? 'GTB1-07' : 'GTB1-0${index + 7}',
      name: 'Giao tiếp B1 · Lớp ${index + 7}',
      startDate: '2026-10-01',
      endDate: '2026-12-30',
      mode: DeliveryMode.OFFLINE,
      maxStudents: 20,
      availableSeats: 17,
      mentor: previewMentor,
      status: status,
      assignment: MentorClassAssignment.PRIMARY,
      scope: MentorClassScope.CLASS,
    ),
];
List<MentorWorkspaceSession> sampleWorkspaceSessions() => [
  for (final entry in sampleSchedule().entries)
    MentorWorkspaceSession(
      session: entry.session,
      readContext: !entry.session.isSubstitute,
      writeNotes: !entry.session.isSubstitute,
    ),
  MentorWorkspaceSession(
    session: sampleEntry(106, DateTime.utc(2026, 10, 28, 7), status: TeachingStatus.COMPLETED).session,
    readContext: true,
    writeNotes: true,
  ),
];
MentorClassOverview sampleOverview({MentorClassStatus status = MentorClassStatus.IN_PROGRESS}) => MentorClassOverview(
  workspace: sampleWorkspace(status: status),
  sessions: sampleWorkspaceSessions(),
  enrollmentCount: 3,
  nextRoom: 'Phòng 204',
  roomKnown: true,
);
List<MentorUnit> sampleUnits() => [
  MentorUnit(
    id: fixtureId(20),
    classId: fixtureClassId,
    courseUnitId: fixtureId(21),
    title: 'Unit 5 · At work',
    position: 1,
    status: MentorUnitStatus.OPEN,
    unlockAt: previewNow,
  ),
];
MentorClassDetail sampleClassDetail({MentorClassStatus status = MentorClassStatus.IN_PROGRESS}) => MentorClassDetail(
  overview: sampleOverview(status: status),
  units: sampleUnits(),
  slots: [
    for (final (i, row) in sampleWorkspaceSessions().indexed)
      MentorSessionSlot(
        id: row.session.id,
        unitId: row.session.classUnitId,
        title: row.session.title,
        number: i + 1,
        status: row.session.status,
      ),
  ],
);
MentorStudentsData sampleStudents() => MentorStudentsData(
  workspace: sampleWorkspace(),
  rows: [
    for (final (i, name) in ['Nguyễn Minh Anh', 'Đặng Thùy Dương', 'Trần Quốc Bảo'].indexed)
      MentorStudentRow(
        student: MentorStudent(
          enrollmentId: fixtureId(200 + i),
          studentId: fixtureId(300 + i),
          name: name,
          enrollmentStatus: i == 2 ? EnrollmentStatus.PENDING_PAYMENT : EnrollmentStatus.ACTIVE,
          orderStatus: i == 2 ? OrderStatus.PENDING : OrderStatus.PAID,
          paymentType: PaymentType.CASH,
        ),
        counts: i == 2
            ? sampleCounts(present: 0, absent: 0)
            : sampleCounts(present: i == 0 ? 9 : 6, absent: i == 0 ? 1 : 4),
      ),
  ],
);
ClassAttendanceSummary sampleClassSummary() => ClassAttendanceSummary(
  classId: fixtureClassId,
  timeZone: previewZone,
  readonly: false,
  asOf: previewNow,
  items: [
    for (final row in sampleStudents().rows)
      EnrollmentAttendance(
        enrollmentId: row.student.enrollmentId,
        student: TeachingPerson(id: row.student.studentId, displayName: row.student.name),
        counts: row.counts,
      ),
  ],
);
MentorClassReport sampleReport() => MentorClassReport(
  workspace: sampleWorkspace(),
  summary: sampleClassSummary(),
  sessions: [
    SessionAttendanceReport(
      row: sampleWorkspaceSessions().last,
      totals: const AttendanceTotals(present: 9, absent: 1, unmarked: 0, eligible: 10),
    ),
    SessionAttendanceReport(
      row: sampleWorkspaceSessions().firstWhere((r) => r.session.status == TeachingStatus.COMPLETED),
      denied: true,
    ),
  ],
);
MentorStudentDetails sampleStudentDetails() => MentorStudentDetails(
  summary: StudentAttendanceSummary(counts: sampleCounts(), timeZone: previewZone),
  history: StudentAttendanceHistory(
    timeZone: previewZone,
    items: [
      for (final (i, applicability) in [
        AttendanceApplicability.ELIGIBLE,
        AttendanceApplicability.MAKEUP_CREDITED,
        AttendanceApplicability.PAYMENT_PENDING,
      ].indexed)
        StudentAttendanceHistoryRow(
          sessionId: fixtureId(100 + i),
          enrollmentId: fixtureId(200),
          rootId: fixtureId(100 + i),
          title: 'Unit 5 · At work',
          startsAt: previewNow.subtract(Duration(days: i)),
          endsAt: previewNow.subtract(Duration(days: i)).add(const Duration(hours: 1)),
          sessionStatus: TeachingStatus.COMPLETED,
          status: i == 0 ? AttendanceStatus.PRESENT : null,
          applicability: applicability,
          excluded: i == 2,
          creditedStatus: i == 1 ? AttendanceStatus.PRESENT : null,
        ),
    ],
  ),
  progress: StudentStoredProgress(
    timeZone: previewZone,
    items: [
      StudentStoredUnit(
        enrollmentId: fixtureId(200),
        unitId: fixtureId(20),
        tracking: StoredTrackingStatus.STORED,
        status: 'IN_PROGRESS',
        percent: '45.50',
        completedAt: null,
        quality: StoredDataQuality.VALID,
      ),
    ],
  ),
  units: sampleUnits(),
);

/// Chỉ entrypoint debug/test import danh sách này; app thật dùng API providers.
List<Override> classesPreviewOverrides({bool includeClasses = true, bool includeDetail = true}) => [
  mentorClockProvider.overrideWithValue(() => previewNow),
  if (includeClasses) mentorPrimaryClassesProvider.overrideWith((ref) async => sampleClasses()),
  mentorClassOverviewProvider.overrideWith((ref, id) async => sampleOverview()),
  if (includeDetail) mentorClassDetailProvider.overrideWith((ref, id) async => sampleClassDetail()),
  mentorClassReportProvider.overrideWith((ref, id) async => sampleReport()),
  mentorStudentsProvider.overrideWith((ref, id) async => sampleStudents()),
  mentorStudentDetailsProvider.overrideWith((ref, query) async => sampleStudentDetails()),
];
