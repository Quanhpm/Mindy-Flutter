import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import '../payment/payment_models.dart';
import 'cart_models.dart';

final cartApiProvider = Provider((ref) => CartApi(ref.watch(apiClientProvider)));

/// `modules/cart/services/cart.service.ts`. Không bao giờ gửi giá - server tự tính.
class CartApi {
  CartApi(this._api);
  final ApiClient _api;

  Future<Cart> get() async => Cart.fromJson(Json(await _api.get('me/cart'), cartError));

  Future<Cart> add(String classId) async =>
      Cart.fromJson(Json(await _api.post('me/cart/items', body: {'classId': classId}), cartError));

  Future<void> remove(String classId) => _api.delete('me/cart/items/$classId');

  /// KHÔNG tự retry: retry có thể tạo đơn thứ 2.
  Future<Order> checkout() async {
    final res = await _api.post('me/cart/checkout', body: {'paymentType': 'PAYOS'});
    final orders = Json(res, cartError).list('orders', Order.fromJson);
    if (orders.isEmpty) throw ApiError.invalidResponse(cartError);
    return orders.first;
  }
}
