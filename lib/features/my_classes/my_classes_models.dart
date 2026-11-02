// ignore_for_file: constant_identifier_names
import '../../core/network/json.dart';
import '../courses/courses_models.dart';
import '../payment/payment_models.dart';

const learningError = 'INVALID_LEARNING_RESPONSE';

enum EnrollmentStatus { PENDING_PAYMENT, ACTIVE, COMPLETED, CANCELLED }

enum ClassStatus { DRAFT, OPEN, IN_PROGRESS, COMPLETED, CANCELLED }

enum SessionStatus { SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED }

enum AccessMode { FULL, CASH_PREVIEW, NONE }

enum AccessReason {
  ACTIVE_ENROLLMENT, PENDING_CASH, PENDING_PAYOS, HOLD_EXPIRED, ENROLLMENT_CANCELLED,
  ENROLLMENT_COMPLETED, CLASS_CANCELLED, STATE_MISMATCH,
}

/// Thao tác được phép với 1 dòng enrollment (`access.ts`)
enum EnrollmentAction { FULL, CASH_PREVIEW, PAYMENT, NONE }

class EnrollmentOrder {
  const EnrollmentOrder({
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.paymentType,
    required this.expiresAt,
    required this.requiresReview,
  });
  final String orderId;
  final String orderCode;
  final OrderStatus orderStatus;
  final PaymentType paymentType;
  final DateTime? expiresAt;
  final bool requiresReview;

  factory EnrollmentOrder.fromJson(Json j) {
    j.dateTimeOrNull('paidAt');
    return EnrollmentOrder(
      orderId: j.uuid('orderId'),
      orderCode: j.str('orderCode'),
      orderStatus: j.enumOf('orderStatus', OrderStatus.values),
      paymentType: j.enumOf('paymentType', PaymentType.values),
      expiresAt: j.dateTimeOrNull('expiresAt'),
      requiresReview: j.boolean('requiresReview'),
    );
  }
}

/// 1 dòng `me/classes` - `enrollmentSchema`
class Enrollment {
  const Enrollment({
    required this.enrollmentId,
    required this.enrollmentStatus,
    required this.isHoldExpired,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.courseImageUrl,
    required this.classId,
    required this.classCode,
    required this.className,
    required this.classStatus,
    required this.startDate,
    required this.endDate,
    required this.deliveryMode,
    required this.mentorName,
    required this.accessMode,
    required this.accessReason,
    required this.canViewClass,
    required this.canViewSchedule,
    required this.order,
  });

  final String enrollmentId;
  final EnrollmentStatus enrollmentStatus;
  final bool isHoldExpired;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String? courseImageUrl;
  final String classId;
  final String classCode;
  final String className;
  final ClassStatus classStatus;
  final String startDate;
  final String endDate;
  final DeliveryMode deliveryMode;
  final String? mentorName;
  final AccessMode accessMode;
  final AccessReason accessReason;
  final bool canViewClass;
  final bool canViewSchedule;
  final EnrollmentOrder? order;

  /// `enrollmentAction` - enum lạ / trạng thái lệch KHÔNG bao giờ suy thành FULL.
  EnrollmentAction get action {
    if (isHoldExpired || classStatus == ClassStatus.CANCELLED) return EnrollmentAction.NONE;
    if (canViewClass &&
        enrollmentStatus == EnrollmentStatus.ACTIVE &&
        accessMode == AccessMode.FULL &&
        accessReason == AccessReason.ACTIVE_ENROLLMENT) {
      return EnrollmentAction.FULL;
    }
    if (canViewClass &&
        enrollmentStatus == EnrollmentStatus.PENDING_PAYMENT &&
        accessMode == AccessMode.CASH_PREVIEW &&
        accessReason == AccessReason.PENDING_CASH &&
        order?.paymentType == PaymentType.CASH &&
        order?.orderStatus == OrderStatus.PENDING) {
      return EnrollmentAction.CASH_PREVIEW;
    }
    if (accessMode == AccessMode.NONE &&
        enrollmentStatus == EnrollmentStatus.PENDING_PAYMENT &&
        !canViewClass &&
        !canViewSchedule &&
        accessReason == AccessReason.PENDING_PAYOS &&
        order?.paymentType == PaymentType.PAYOS &&
        order?.orderStatus == OrderStatus.PENDING &&
        order?.requiresReview == false) {
      return EnrollmentAction.PAYMENT;
    }
    return EnrollmentAction.NONE;
  }

  factory Enrollment.fromJson(Json j) {
    j.dateTimeOrNull('enrolledAt');
    j.dateTime('createdAt');
    final mentor = j.objOrNull('mentor');
    return Enrollment(
      enrollmentId: j.uuid('enrollmentId'),
      enrollmentStatus: j.enumOf('enrollmentStatus', EnrollmentStatus.values),
      isHoldExpired: j.boolean('isHoldExpired'),
      courseId: j.uuid('courseId'),
      courseCode: j.str('courseCode'),
      courseTitle: j.str('courseTitle'),
      courseImageUrl: j.strOrNull('courseImageUrl'),
      classId: j.uuid('classId'),
      classCode: j.str('classCode'),
      className: j.str('className'),
      classStatus: j.enumOf('classStatus', ClassStatus.values),
      startDate: j.day('startDate'),
      endDate: j.day('endDate'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      mentorName: mentor?.nonEmpty('displayName'),
      accessMode: j.enumOf('accessMode', AccessMode.values),
      accessReason: j.enumOf('accessReason', AccessReason.values),
      canViewClass: j.boolean('canViewClass'),
      canViewSchedule: j.boolean('canViewSchedule'),
      order: j.has('order') ? EnrollmentOrder.fromJson(j.obj('order')) : null,
    );
  }
}

/// Nhóm theo khoá học (folder trong Lớp của tôi) - `groupEnrollments`
List<({String courseId, String title, String code, List<Enrollment> items})> groupEnrollments(List<Enrollment> rows) {
  final groups = <String, ({String courseId, String title, String code, List<Enrollment> items})>{};
  final seen = <String>{};
  for (final r in rows) {
    if (!seen.add(r.enrollmentId)) continue;
    groups.putIfAbsent(r.courseId, () => (courseId: r.courseId, title: r.courseTitle, code: r.courseCode, items: []));
    groups[r.courseId]!.items.add(r);
  }
  return groups.values.toList();
}

class ClassSession {
  const ClassSession({
    required this.id,
    required this.sessionNumber,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.roomName,
    required this.status,
    this.meetingUrl,
  });

  final String id;
  final int sessionNumber;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? roomName;
  final SessionStatus status;

  /// Chỉ có ở bản FULL. Bản preview luôn null.
  final String? meetingUrl;

  factory ClassSession.fromJson(Json j, {required bool full}) {
    final s = ClassSession(
      id: j.uuid('id'),
      sessionNumber: j.integer('sessionNumber'),
      title: j.str('title'),
      startsAt: j.dateTime('startsAt'),
      endsAt: j.dateTime('endsAt'),
      roomName: j.strOrNull('roomName'),
      status: j.enumOf('status', SessionStatus.values),
      meetingUrl: full ? j.strOrNull('meetingUrl') : null,
    );
    if (s.sessionNumber < 1 || !s.endsAt.isAfter(s.startsAt)) j.fail();
    return s;
  }
}

class ClassUnit {
  const ClassUnit({required this.id, required this.title, required this.sessions});
  final String id;
  final String title;
  final List<ClassSession> sessions;
}

/// `me/classes/:id` (FULL) hoặc `me/classes/:id/preview` (CASH_PREVIEW)
class ClassDetail {
  const ClassDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.deliveryMode,
    required this.classStatus,
    required this.mentorName,
    required this.accessMode,
    required this.units,
    this.meetingUrl,
    this.expiresAt,
  });

  final String id;
  final String code;
  final String name;
  final String startDate;
  final String endDate;
  final DeliveryMode deliveryMode;
  final ClassStatus classStatus;
  final String? mentorName;
  final AccessMode accessMode; // FULL hoặc CASH_PREVIEW
  final List<ClassUnit> units;
  final String? meetingUrl; // chỉ FULL
  final DateTime? expiresAt; // chỉ preview

  bool get isPreview => accessMode == AccessMode.CASH_PREVIEW;
  List<ClassSession> get sessions => [for (final u in units) ...u.sessions];

  factory ClassDetail.fromJson(Json j, {required bool preview}) {
    final full = !preview;
    if (j.str('accessMode') != (full ? 'FULL' : 'CASH_PREVIEW')) j.fail();
    if (j.str('enrollmentStatus') != (full ? 'ACTIVE' : 'PENDING_PAYMENT')) j.fail();
    j.uuid('courseId');
    j.uuid('enrollmentId');
    if (preview) {
      j.uuid('orderId');
      j.str('orderCode');
    }
    final units = j.list('units', (u) {
      u.integer('position');
      return ClassUnit(
        id: u.uuid('id'),
        title: u.str('title'),
        sessions: u.list('sessions', (s) => ClassSession.fromJson(s, full: full)),
      );
    });
    return ClassDetail(
      id: j.uuid('id'),
      code: j.str('code'),
      name: j.str('name'),
      startDate: j.day('startDate'),
      endDate: j.day('endDate'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      classStatus: j.enumOf('classStatus', ClassStatus.values),
      mentorName: j.objOrNull('mentor')?.nonEmpty('displayName'),
      accessMode: full ? AccessMode.FULL : AccessMode.CASH_PREVIEW,
      units: units,
      // Bỏ hẳn field ngoài dự kiến: preview KHÔNG BAO GIỜ giữ meetingUrl
      meetingUrl: full ? j.strOrNull('meetingUrl') : null,
      expiresAt: preview ? j.dateTimeOrNull('expiresAt') : null,
    );
  }
}
