import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import 'payment_api.dart';
import 'payment_models.dart';

/// Người dùng rời màn / app vào background / logout -> dừng im lặng.
class PaymentCancelled implements Exception {}

ApiError _timeout() => ApiError(status: 0, code: 'PAYMENT_CONFIRMATION_TIMEOUT', message: 'Confirmation time limit reached');

/// Token huỷ 1 phiên theo dõi: huỷ cả HTTP đang chạy lẫn các lần chờ.
class WatchToken {
  final http = CancelToken();
  bool _cancelled = false;
  final _sleepers = <Completer<void>, Timer>{};

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!http.isCancelled) http.cancel();
    _sleepers.forEach((c, t) {
      t.cancel();
      if (!c.isCompleted) c.completeError(PaymentCancelled());
    });
    _sleepers.clear();
  }

  Future<void> sleep(Duration d) {
    if (_cancelled) return Future.error(PaymentCancelled());
    final c = Completer<void>();
    _sleepers[c] = Timer(d, () {
      _sleepers.remove(c);
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }
}

/// Một phiên xác minh tuần tự - port `payment/hooks/watchPayment.ts`.
///
/// 1. GET order trước mọi thứ. Đã PAID/CANCELLED/EXPIRED/REVIEW -> dừng.
/// 2. Còn trả được: dùng lại QR còn hạn, hoặc tạo link (CREATING -> backoff 2s,4s,8s… tối đa 30s).
/// 3. Poll lại order sau 3s -> 5s -> 10s -> 10s… Tổng tối đa 120s (tính cả thời gian request).
///    Poll KHÔNG POST tạo link ở mỗi vòng.
/// Chỉ `order.status == PAID` từ backend mới là thanh toán thành công.
class PaymentWatcher {
  PaymentWatcher({
    required this.api,
    required this.orderId,
    required this.token,
    required this.onOrder,
    required this.onPayment,
    this.verifyResume,
  });

  final PaymentApi api;
  final String orderId;
  final WatchToken token;
  final void Function(Order order) onOrder;
  final void Function(Payment payment) onPayment;

  /// Vào từ "Tiếp tục thanh toán" ở Lớp của tôi: kiểm tra enrollment trước khi tạo link.
  final Future<Order> Function()? verifyResume;

  static const limit = Duration(seconds: 120);
  static const _pollDelays = [Duration(seconds: 3), Duration(seconds: 5)];
  static const _pollDefault = Duration(seconds: 10);
  static const _linkLimit = Duration(seconds: 30);
  static const _linkBackoff = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];

  late final DateTime _started;
  bool _timedOut = false;

  Duration _remaining() {
    final r = limit - DateTime.now().difference(_started);
    return r < const Duration(milliseconds: 1) ? const Duration(milliseconds: 1) : r;
  }

  void _assertActive() {
    if (token.cancelled) throw _timedOut ? _timeout() : PaymentCancelled();
  }

  Future<Order> _read([Payment? latest]) async {
    _assertActive();
    var order = await api.order(orderId, cancel: token.http, timeout: _remaining());
    _assertActive();
    if (order.status != OrderStatus.PAID && latest?.status == PaymentStatus.REQUIRES_REVIEW) {
      order = order.withPayment(latest);
    }
    onOrder(order);
    _assertActive();
    return order;
  }

  /// `waitForPayosLink`: CREATING = PayOS đang chuẩn bị link.
  Future<Payment> _waitForLink() async {
    final started = DateTime.now();
    var waited = Duration.zero;
    Payment? last;
    Duration elapsed() {
      final real = DateTime.now().difference(started);
      return real > waited ? real : waited;
    }

    Payment missing(Payment p) => p.copyWith(status: PaymentStatus.PENDING, clearQr: true);

    for (var attempt = 0;; attempt++) {
      _assertActive();
      final rem = _linkLimit - elapsed();
      if (rem <= Duration.zero && last != null) return missing(last);
      Payment p;
      try {
        p = await api.createPayos(
          orderId,
          cancel: token.http,
          timeout: rem > const Duration(milliseconds: 1) ? rem : const Duration(milliseconds: 1),
        );
      } catch (_) {
        _assertActive();
        if (elapsed() >= _linkLimit && last != null) return missing(last);
        rethrow;
      }
      _assertActive();
      if (p.status != PaymentStatus.CREATING) return p;
      last = p;
      final delay = attempt < _linkBackoff.length ? _linkBackoff[attempt] : const Duration(seconds: 8);
      if (elapsed() + delay > _linkLimit) return missing(p);
      await token.sleep(delay);
      waited += delay;
    }
  }

  Future<void> run() async {
    _started = DateTime.now();
    final deadline = Timer(limit, () {
      _timedOut = true;
      token.cancel();
    });
    try {
      var order = await _read();
      if (order.isTerminal) return;

      if (order.canPay(DateTime.now())) {
        if (verifyResume != null) {
          try {
            order = await verifyResume!();
            _assertActive();
            onOrder(order);
          } catch (_) {
            _assertActive();
            // Đọc order trước: đơn vừa PAID không bị chặn bởi enrollment cũ
            final latest = await _read();
            if (latest.isTerminal) return;
            rethrow;
          }
        }

        final p = order.payment;
        if (p != null &&
            p.status == PaymentStatus.PENDING &&
            p.qrCode != null &&
            (p.expiresAt == null || p.expiresAt!.isAfter(DateTime.now()))) {
          onPayment(p); // QR cũ còn hạn: dùng lại
        } else {
          try {
            final payment = await _waitForLink();
            _assertActive();
            if (payment.status == PaymentStatus.REQUIRES_REVIEW) onOrder(order.withPayment(payment));
            onPayment(payment);
            if (payment.status == PaymentStatus.SUCCEEDED || payment.status == PaymentStatus.REQUIRES_REVIEW) {
              order = await _read(payment);
              if (order.isTerminal) return;
            }
          } catch (e) {
            _assertActive();
            if (e is ApiError && e.status == 409) {
              order = await _read();
              if (order.isTerminal) return;
            }
            rethrow;
          }
        }
      }

      for (var attempt = 0;; attempt++) {
        final delay = attempt < _pollDelays.length ? _pollDelays[attempt] : _pollDefault;
        final rem = _remaining();
        await token.sleep(delay < rem ? delay : rem);
        order = await _read();
        if (order.isTerminal) return;
      }
    } catch (e) {
      if (_timedOut) throw _timeout();
      if (token.cancelled) throw PaymentCancelled();
      rethrow;
    } finally {
      deadline.cancel();
    }
  }
}
