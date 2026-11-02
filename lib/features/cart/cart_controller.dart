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
    'CART_ITEM_ALREADY_EXISTS',
    'CART_LIMIT_EXCEEDED',
    'CLASS_FULL',
    'CLASS_NOT_OPEN',
    'CLASS_NOT_FOUND',
    'CLASS_ALREADY_ENROLLED',
    'CART_EMPTY',
  };
  final code = e is ApiError ? e.code : '';
  return known.contains(code) ? 'cart.errors.$code' : 'cart.errors.generic';
}

/// Giao dịch chưa rõ kết quả giữ trong RAM cả khi đóng/mở lại giỏ.
/// Chỉ xoá sau khi đọc đối soát hoặc đổi phiên, không gửi checkout lần hai.
final checkoutPendingProvider = NotifierProvider<CheckoutPending, List<String>?>(CheckoutPending.new);

class CheckoutPending extends Notifier<List<String>?> {
  @override
  List<String>? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  void set(List<String>? ids) => state = ids == null ? null : List.unmodifiable(ids);
}

class CartController extends AsyncNotifier<Cart> {
  int get _epoch => ref.read(sessionEpochProvider);
  void _check(int epoch) {
    if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) {
      throw ApiError(status: 401, code: 'SESSION_CHANGED');
    }
  }

  CartApi get _api => ref.read(cartApiProvider);

  @override
  Future<Cart> build() {
    ref.watch(sessionEpochProvider);
    return ref.watch(cartApiProvider).get();
  }

  /// Đọc lại giỏ thật từ server.
  Future<Cart> refresh() async {
    final epoch = _epoch;
    final cart = await _api.get();
    _check(epoch);
    state = AsyncData(cart);
    return cart;
  }

  Future<void> add(String classId) async {
    final epoch = _epoch;
    final cart = await _api.add(classId);
    _check(epoch);
    state = AsyncData(cart);
  }

  Future<void> remove(String classId) => _api.remove(classId);

  /// Chọn lớp cho 1 khoá - `useCourseSelection.run`.
  /// Thêm lớp mới THÀNH CÔNG rồi mới xoá lớp cũ cùng khoá. Lỗi thì tải lại giỏ thật.
  Future<void> putClass({required String courseId, required String classId}) async {
    final epoch = _epoch;
    final current = state.value ?? Cart.empty;
    try {
      if (!current.items.any((i) => i.classId == classId)) await add(classId);
      for (final old in current.items.where((i) => i.courseId == courseId && i.classId != classId)) {
        _check(epoch);
        await remove(old.classId);
      }
      _check(epoch);
      await refresh();
    } catch (e) {
      _check(epoch);
      await refresh().catchError((_) => Cart.empty);
      if (e is ApiError && (e.code == 'CART_ITEM_NOT_FOUND' || e.code == 'CART_ITEM_ALREADY_EXISTS')) {
        return;
      }
      rethrow;
    }
  }

  /// Checkout PAYOS. Trả về orderId.
  /// Timeout/5xx/mất mạng => ném [CheckoutUnknown]: đơn CÓ THỂ đã được tạo,
  /// UI phải cho "Kiểm tra lại" ([verifyCheckout]) chứ không checkout lần 2.
  Future<String> checkout() async {
    final epoch = _epoch;
    final pending = ref.read(checkoutPendingProvider);
    if (pending != null) throw CheckoutUnknown(pending);
    final items = state.value?.items ?? const [];
    if (items.isEmpty) throw ApiError(status: 409, code: 'CART_EMPTY');
    final classIds = items.map((i) => i.classId).toList();
    ref.read(checkoutPendingProvider.notifier).set(classIds);
    try {
      final order = await _api.checkout();
      _check(epoch);
      ref.read(checkoutPendingProvider.notifier).set(null);
      _afterCheckout();
      return order.id;
    } catch (e) {
      _check(epoch);
      final unknown = e is! ApiError || e.status == 0 || e.status >= 500 || e.status == 408;
      if (unknown) throw CheckoutUnknown(classIds);
      ref.read(checkoutPendingProvider.notifier).set(null);
      await refresh().catchError((_) => Cart.empty);
      rethrow;
    }
  }

  /// Sau khi checkout mất response: tìm đơn PENDING/PAYOS chứa đúng các lớp đó.
  /// Trả orderId nếu tìm thấy, null nếu không (giỏ đã được tải lại).
  Future<String?> verifyCheckout(List<String> classIds) async {
    final epoch = _epoch;
    final order = await ref.read(paymentApiProvider).findPendingPayosOrder(classIds);
    _check(epoch);
    if (order != null) {
      ref.read(checkoutPendingProvider.notifier).set(null);
      _afterCheckout();
      return order.id;
    }
    await refresh();
    _check(epoch);
    ref.read(checkoutPendingProvider.notifier).set(null);
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
