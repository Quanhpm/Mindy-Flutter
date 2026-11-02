import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../payment/payment_api.dart';
import 'cart_api.dart';
import 'cart_models.dart';

/// Giỏ hàng của user hiện tại. Không optimistic update (ADR-0011):
/// state chỉ đổi theo response của server.
final cartProvider = AsyncNotifierProvider<CartController, Cart>(CartController.new);

/// Số lớp trong giỏ (badge trên Home/Courses)
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).value?.items.length ?? 0);

/// Map mã lỗi -> key dịch `cart.errors.*`
String cartErrorKey(Object e) {
  const known = {
    'CART_ITEM_ALREADY_EXISTS', 'CART_LIMIT_EXCEEDED', 'CLASS_FULL', 'CLASS_NOT_OPEN',
    'CLASS_NOT_FOUND', 'CLASS_ALREADY_ENROLLED', 'CART_EMPTY',
  };
  final code = e is ApiError ? e.code : '';
  return known.contains(code) ? 'cart.errors.$code' : 'cart.errors.generic';
}

class CartController extends AsyncNotifier<Cart> {
  CartApi get _api => ref.read(cartApiProvider);

  @override
  Future<Cart> build() {
    ref.watch(sessionEpochProvider);
    return ref.watch(cartApiProvider).get();
  }

  /// Đọc lại giỏ thật từ server.
  Future<Cart> refresh() async {
    final cart = await _api.get();
    state = AsyncData(cart);
    return cart;
  }

  Future<void> add(String classId) async => state = AsyncData(await _api.add(classId));

  Future<void> remove(String classId) => _api.remove(classId);

  /// Chọn lớp cho 1 khoá - `useCourseSelection.run`.
  /// Thêm lớp mới THÀNH CÔNG rồi mới xoá lớp cũ cùng khoá. Lỗi thì tải lại giỏ thật.
  Future<void> putClass({required String courseId, required String classId}) async {
    final current = state.value ?? Cart.empty;
    try {
      if (!current.items.any((i) => i.classId == classId)) await add(classId);
      for (final old in current.items.where((i) => i.courseId == courseId && i.classId != classId)) {
        await remove(old.classId);
      }
      await refresh();
    } catch (e) {
      await refresh().catchError((_) => Cart.empty);
      if (e is ApiError && (e.code == 'CART_ITEM_NOT_FOUND' || e.code == 'CART_ITEM_ALREADY_EXISTS')) return;
      rethrow;
    }
  }

  /// Checkout PAYOS. Trả về orderId.
  /// Timeout/5xx/mất mạng => ném [CheckoutUnknown]: đơn CÓ THỂ đã được tạo,
  /// UI phải cho "Kiểm tra lại" ([verifyCheckout]) chứ không checkout lần 2.
  Future<String> checkout() async {
    final items = state.value?.items ?? const [];
    if (items.isEmpty) throw ApiError(status: 409, code: 'CART_EMPTY');
    final classIds = items.map((i) => i.classId).toList();
    try {
      final order = await _api.checkout();
      _afterCheckout();
      return order.id;
    } catch (e) {
      final unknown = e is! ApiError || e.status == 0 || e.status >= 500;
      if (unknown) throw CheckoutUnknown(classIds);
      await refresh().catchError((_) => Cart.empty);
      rethrow;
    }
  }

  /// Sau khi checkout mất response: tìm đơn PENDING/PAYOS chứa đúng các lớp đó.
  /// Trả orderId nếu tìm thấy, null nếu không (giỏ đã được tải lại).
  Future<String?> verifyCheckout(List<String> classIds) async {
    final order = await ref.read(paymentApiProvider).findPendingPayosOrder(classIds);
    if (order != null) {
      _afterCheckout();
      return order.id;
    }
    await refresh();
    return null;
  }

  void _afterCheckout() {
    ref.invalidateSelf();
    // TODO: invalidate thêm learning/home schedule khi các provider đó cần tươi ngay
  }
}

class CheckoutUnknown implements Exception {
  CheckoutUnknown(this.classIds);
  final List<String> classIds;
}
