import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import 'payment_models.dart';

final paymentApiProvider = Provider((ref) => PaymentApi(ref.watch(apiClientProvider)));

/// `modules/payment/services/payment.service.ts`
class PaymentApi {
  PaymentApi(this._api);
  final ApiClient _api;

  Future<Order> order(String orderId, {CancelToken? cancel, Duration? timeout}) async {
    final o = Order.fromJson(Json(await _api.get('me/orders/$orderId', cancel: cancel, timeout: timeout), paymentError));
    if (o.id != orderId) throw ApiError.invalidResponse(paymentError);
    return o;
  }

  /// Tạo hoặc dùng lại link PayOS - gọi lặp an toàn.
  Future<Payment> createPayos(String orderId, {CancelToken? cancel, Duration? timeout}) async => Payment.fromJson(
      Json(await _api.post('me/orders/$orderId/payments/payos', body: <String, Object>{}, cancel: cancel, timeout: timeout),
          paymentError));

  /// Chỉ dùng khi checkout mất response: tìm đơn PAYOS/PENDING có ĐÚNG các lớp này
  /// trong 5 đơn PENDING mới nhất (giới hạn giống bản RN).
  Future<Order?> findPendingPayosOrder(List<String> classIds) async {
    final res = await _api.get('me/orders', query: {'status': 'PENDING', 'page': 1, 'pageSize': 5});
    final page = Paged.fromJson(Json(res, paymentError), Order.fromJson);
    String key(Iterable<String> ids) => (ids.toSet().toList()..sort()).join(',');
    final wanted = key(classIds);
    for (final o in page.items) {
      if (o.paymentType == PaymentType.PAYOS &&
          o.status == OrderStatus.PENDING &&
          key(o.details.map((d) => d.classId)) == wanted) {
        return o;
      }
    }
    return null;
  }
}
