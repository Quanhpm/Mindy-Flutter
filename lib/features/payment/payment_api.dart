import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import '../../core/network/pagination.dart';
import 'payment_models.dart';

final paymentApiProvider = Provider((ref) => PaymentApi(ref.watch(apiClientProvider)));

/// `modules/payment/services/payment.service.ts`
class PaymentApi {
  PaymentApi(this._api);
  final ApiClient _api;

  Future<Order> order(String orderId, {CancelToken? cancel, Duration? timeout}) async {
    final o = Order.fromJson(
      Json(await _api.get('me/orders/$orderId', cancel: cancel, timeout: timeout), paymentError),
    );
    if (o.id != orderId) throw ApiError.invalidResponse(paymentError);
    return o;
  }

  /// Tạo hoặc dùng lại link PayOS - gọi lặp an toàn.
  Future<Payment> createPayos(String orderId, {CancelToken? cancel, Duration? timeout}) async => Payment.fromJson(
    Json(
      await _api.post('me/orders/$orderId/payments/payos', body: <String, Object>{}, cancel: cancel, timeout: timeout),
      paymentError,
    ),
  );

  /// Đối soát toàn bộ đơn đang chờ, không bỏ sót đơn ngoài trang đầu.
  Future<Order?> findPendingPayosOrder(List<String> classIds) async {
    final epoch = _api.sessionEpoch;
    final orders = await readAllPages<Order>(
      (page) async {
        if (_api.sessionEpoch != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
        return Paged.fromJson(
          Json(await _api.get('me/orders', query: {'status': 'PENDING', 'page': page, 'pageSize': 100}), paymentError),
          Order.fromJson,
        );
      },
      idOf: (order) => order.id,
      errorCode: paymentError,
    );
    String key(Iterable<String> ids) => (ids.toSet().toList()..sort()).join(',');
    final wanted = key(classIds);
    final matches = orders
        .where(
          (o) =>
              o.paymentType == PaymentType.PAYOS &&
              o.status == OrderStatus.PENDING &&
              key(o.details.map((d) => d.classId)) == wanted,
        )
        .toList();
    if (matches.length > 1) throw ApiError(status: 409, code: 'PAYMENT_ORDER_AMBIGUOUS');
    return matches.firstOrNull;
  }
}
