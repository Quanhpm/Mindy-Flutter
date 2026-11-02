// ignore_for_file: constant_identifier_names
import '../../core/network/json.dart';

const paymentError = 'INVALID_PAYMENT_RESPONSE';

enum OrderStatus { PENDING, PAID, EXPIRED, CANCELLED }

enum PaymentType { PAYOS, CASH }

enum PaymentStatus { CREATING, PENDING, SUCCEEDED, REQUIRES_REVIEW }

/// `payment/schemas/order.schema.ts` - paymentSchema
class Payment {
  const Payment({required this.status, required this.qrCode, required this.expiresAt, required this.amount});
  final PaymentStatus status;
  final String? qrCode;
  final DateTime? expiresAt;
  final int amount;

  Payment copyWith({PaymentStatus? status, String? qrCode, bool clearQr = false}) => Payment(
        status: status ?? this.status,
        qrCode: clearQr ? null : (qrCode ?? this.qrCode),
        expiresAt: expiresAt,
        amount: amount,
      );

  factory Payment.fromJson(Json j) {
    final qr = j.strOrNull('qrCode');
    if (qr != null && qr.isEmpty) j.fail();
    return Payment(
      status: j.enumOf('status', PaymentStatus.values),
      qrCode: qr,
      expiresAt: j.dateTimeOrNull('expiresAt'),
      amount: j.amount('amount'),
    );
  }
}

/// orderSchema (+ payment khi đọc `me/orders/:id`)
class Order {
  const Order({
    required this.id,
    required this.orderCode,
    required this.paymentType,
    required this.status,
    required this.totalAmount,
    required this.expiresAt,
    required this.details,
    this.payment,
  });

  final String id;
  final String orderCode;
  final PaymentType paymentType;
  final OrderStatus status;
  final int totalAmount;
  final DateTime expiresAt;
  final List<({String classId, String courseTitle})> details;
  final Payment? payment;

  Order withPayment(Payment? p) => Order(
        id: id,
        orderCode: orderCode,
        paymentType: paymentType,
        status: status,
        totalAmount: totalAmount,
        expiresAt: expiresAt,
        details: details,
        payment: p,
      );

  bool get inReview => status != OrderStatus.PAID && payment?.status == PaymentStatus.REQUIRES_REVIEW;

  /// Hết theo dõi: đã có kết quả hoặc đang đối soát.
  bool get isTerminal => status != OrderStatus.PENDING || payment?.status == PaymentStatus.REQUIRES_REVIEW;

  /// `canPayOrder` (paymentResult.ts)
  bool canPay(DateTime now) =>
      status == OrderStatus.PENDING &&
      paymentType == PaymentType.PAYOS &&
      payment?.status != PaymentStatus.REQUIRES_REVIEW &&
      payment?.status != PaymentStatus.SUCCEEDED &&
      expiresAt.isAfter(now);

  /// Ticket kết quả: chỉ PAID / CANCELLED / EXPIRED. Pending/review => null (hiện inline).
  OrderStatus? get result {
    if (inReview) return null;
    if (status == OrderStatus.PENDING) return null;
    return status;
  }

  factory Order.fromJson(Json j) => Order(
        id: j.uuid('id'),
        orderCode: j.nonEmpty('orderCode'),
        paymentType: j.enumOf('paymentType', PaymentType.values),
        status: j.enumOf('status', OrderStatus.values),
        totalAmount: j.amount('totalAmount'),
        expiresAt: j.dateTime('expiresAt'),
        details: j.list('details', (d) => (classId: d.uuid('classId'), courseTitle: d.str('courseTitle'))),
        payment: j.has('payment') ? Payment.fromJson(j.obj('payment')) : null,
      );
}
