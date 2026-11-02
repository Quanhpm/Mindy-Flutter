// ignore_for_file: constant_identifier_names
import '../../../core/network/json.dart';
import '../../../core/utils/format.dart';
import '../../my_classes/my_classes_models.dart' show EnrollmentStatus;
import '../../payment/payment_models.dart' show OrderStatus, PaymentType;
import '../reports/reports_models.dart';
import '../classes/classes_models.dart';

class MentorStudent {
  const MentorStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.name,
    required this.enrollmentStatus,
    required this.orderStatus,
    required this.paymentType,
  });
  final String enrollmentId, studentId, name;
  final EnrollmentStatus enrollmentStatus;
  final OrderStatus orderStatus;
  final PaymentType paymentType;
  factory MentorStudent.fromJson(Json j) {
    j.uuid('orderId');
    j.str('orderCode');
    j.amount('classAmount');
    j.amount('orderTotalAmount');
    if (j.integer('orderClassCount') < 1 || j.boolean('canConfirmCash')) {
      j.fail();
    }
    j.dateTime('expiresAt');
    j.dateTimeOrNull('paidAt');
    return MentorStudent(
      enrollmentId: j.uuid('enrollmentId'),
      studentId: j.uuid('studentId'),
      name: j.str('studentName'),
      enrollmentStatus: j.enumOf('enrollmentStatus', EnrollmentStatus.values),
      orderStatus: j.enumOf('orderStatus', OrderStatus.values),
      paymentType: j.enumOf('paymentType', PaymentType.values),
    );
  }
}

class MentorStudentRow {
  const MentorStudentRow({required this.student, required this.counts});
  final MentorStudent student;
  final MentorAttendanceCounts counts;
}

enum MentorStudentFilter { all, attention, regular }

String mentorSearchText(String text) {
  var value = text.toLowerCase().trim().replaceAll('đ', 'd').replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  const groups = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
  };
  for (final entry in groups.entries) {
    value = value.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return value;
}

List<MentorStudentRow> filterMentorStudents(List<MentorStudentRow> rows, String query, MentorStudentFilter filter) {
  final search = mentorSearchText(query);
  return List.unmodifiable(
    rows.where(
      (row) =>
          mentorSearchText(row.student.name).contains(search) &&
          switch (filter) {
            MentorStudentFilter.all => true,
            MentorStudentFilter.attention => needsAttention(row.counts.rate),
            MentorStudentFilter.regular => row.counts.rate != null && row.counts.rate! >= 80,
          },
    ),
  );
}

enum StoredTrackingStatus { STORED, UNTRACKED }

enum StoredDataQuality { VALID, INVALID_PERCENT, UNTRACKED }

class StudentStoredUnit {
  const StudentStoredUnit({
    required this.enrollmentId,
    required this.unitId,
    required this.tracking,
    required this.status,
    required this.percent,
    required this.completedAt,
    required this.quality,
  });
  final String enrollmentId, unitId;
  final StoredTrackingStatus tracking;
  final String? status, percent;
  final DateTime? completedAt;
  final StoredDataQuality quality;
  String get key => '$enrollmentId:$unitId';
  factory StudentStoredUnit.fromJson(Json j) {
    final percent = j.strOrNull('progressPercent');
    if (percent != null && (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(percent) || double.parse(percent) > 100)) {
      j.fail();
    }
    return StudentStoredUnit(
      enrollmentId: j.uuid('enrollmentId'),
      unitId: j.uuid('classUnitId'),
      tracking: j.enumOf('trackingStatus', StoredTrackingStatus.values),
      status: j.strOrNull('status'),
      percent: percent,
      completedAt: j.dateTimeOrNull('completedAt'),
      quality: j.enumOf('dataQuality', StoredDataQuality.values),
    );
  }
}

class StudentStoredProgress {
  StudentStoredProgress({required this.timeZone, required List<StudentStoredUnit> items})
    : items = List.unmodifiable(items);
  final String timeZone;
  final List<StudentStoredUnit> items;
  static String metadata(Json j) {
    if (j.str('completionPolicy') != 'UNDEFINED' || j.has('policyVersion') || !j.boolean('readonly')) {
      j.fail();
    }
    final assignment = j.obj('assignmentSummary');
    if (assignment.str('availability') != 'NOT_IMPLEMENTED' || assignment.has('counts')) {
      j.fail();
    }
    final zone = j.str('timeZone');
    if (!Dates.isValidZone(zone)) j.fail();
    j.dateTime('asOf');
    return zone;
  }
}

class MentorStudentsData {
  MentorStudentsData({required this.workspace, required List<MentorStudentRow> rows}) : rows = List.unmodifiable(rows);
  final MentorWorkspace workspace;
  final List<MentorStudentRow> rows;
}

class MentorStudentDetails {
  MentorStudentDetails({
    required this.summary,
    required this.history,
    required this.progress,
    required List<MentorUnit> units,
  }) : units = List.unmodifiable(units);
  final StudentAttendanceSummary summary;
  final StudentAttendanceHistory history;
  final StudentStoredProgress progress;
  final List<MentorUnit> units;
}
