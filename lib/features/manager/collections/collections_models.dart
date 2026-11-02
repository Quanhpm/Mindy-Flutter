import '../../../core/network/json.dart';
import '../../payment/payment_models.dart';
import '../manager_models.dart';

class CollectionOrder {
  const CollectionOrder({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.type,
    required this.status,
    required this.expires,
    required this.paidAt,
    required this.collector,
    required this.review,
    required this.details,
  });
  final String id, code, studentId, studentName;
  final int amount;
  final PaymentType type;
  final OrderStatus status;
  final DateTime expires;
  final DateTime? paidAt;
  final String? collector, review;
  final List<({String classId, String className, String courseTitle, int amount})> details;
  bool get canConfirm => type == PaymentType.CASH && status == OrderStatus.PENDING && review == null;
  factory CollectionOrder.fromJson(Json j) {
    final payment = j.objOrNull('payment'), who = payment?.objOrNull('confirmedBy');
    final pstatus = payment?.enumOf('status', PaymentStatus.values);
    final review = payment?.objOrNull('review');
    if (review != null && review.str('outcome') != 'REQUIRES_REVIEW') j.fail();
    if (who != null && !['MANAGER', 'LEGACY_MENTOR'].contains(who.str('source'))) j.fail();
    final student = j.obj('student');
    final details = j.has('details')
        ? j.list(
            'details',
            (d) => (
              classId: d.uuid('classId'),
              className: d.str('className'),
              courseTitle: d.str('courseTitle'),
              amount: managerMoney(d, 'totalAmount'),
            ),
          )
        : <({String classId, String className, String courseTitle, int amount})>[];
    return CollectionOrder(
      id: j.uuid('id'),
      code: j.nonEmpty('orderCode'),
      studentId: student.uuid('id'),
      studentName: student.strOrNull('displayName') ?? '',
      amount: managerMoney(j, 'totalAmount'),
      type: j.enumOf('paymentType', PaymentType.values),
      status: j.enumOf('status', OrderStatus.values),
      expires: j.dateTime('expiresAt'),
      paidAt: j.dateTimeOrNull('paidAt'),
      collector: who?.strOrNull('displayName'),
      review: pstatus == PaymentStatus.REQUIRES_REVIEW ? (review?.strOrNull('reason') ?? '') : null,
      details: List.unmodifiable(details),
    );
  }
}

typedef CollectionFilter = ({OrderStatus? status, String code, String? classId});
