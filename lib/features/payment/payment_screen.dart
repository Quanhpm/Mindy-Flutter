import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../../core/ui/ui.dart';
import '../cart/cart_controller.dart';
import '../home/home_providers.dart';
import '../my_classes/my_classes_api.dart';
import '../my_classes/my_classes_providers.dart';
import '../schedule/schedule_providers.dart';
import 'payment_api.dart';
import 'payment_models.dart';
import 'payment_result_ticket.dart';
import 'payment_watcher.dart';

/// Màn thanh toán QR - `payment/PaymentRoute.tsx` + `PaymentScreen.tsx` + `usePaymentQuery.ts`.
///
/// - Theo dõi đơn bằng [PaymentWatcher]; dừng khi rời màn / app background / đổi phiên,
///   quay lại foreground thì xác minh mới.
/// - PAID -> ticket thành công -> "Về trang chủ" (reset stack).
///   CANCELLED/EXPIRED -> ticket -> "Thử lại" về Khoá học. Pending/timeout/lỗi: hiện inline.
/// - Không vuốt back (PopScope).
/// TODO(UI): port bố cục QR card, thông tin chuyển khoản (chỉ ngoài production), sheet "Rời trang?".
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.orderId, this.fromLearning = false});
  final String orderId;
  final bool fromLearning;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> with WidgetsBindingObserver {
  Order? _order;
  Payment? _payment;
  ApiError? _error;
  bool _busy = true;
  WatchToken? _token;
  bool _paidPublished = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _payment?.expiresAt != null) setState(() {}); // cập nhật countdown
    });
    Future.microtask(_start);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _token?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _token?.cancel();
    }
  }

  Future<void> _start() async {
    if (_order?.result != null) return; // đã có kết quả cuối
    _token?.cancel();
    final token = _token = WatchToken();
    final epoch = ref.read(sessionEpochProvider);
    bool valid() => !token.cancelled && mounted && ref.read(sessionEpochProvider) == epoch;

    setState(() {
      _busy = true;
      _error = null;
    });
    final watcher = PaymentWatcher(
      api: ref.read(paymentApiProvider),
      orderId: widget.orderId,
      token: token,
      verifyResume: widget.fromLearning
          ? () => ref.read(myClassesApiProvider).verifiedResumeOrder(widget.orderId)
          : null,
      onOrder: (o) {
        if (!valid()) return;
        // Response cũ không được ghi đè PAID
        if (_order?.status == OrderStatus.PAID) return;
        setState(() => _order = o);
        if (o.status == OrderStatus.PAID) _publishPaid();
      },
      onPayment: (p) {
        if (!valid()) return;
        setState(() {
          _payment = (p.status == PaymentStatus.PENDING || p.status == PaymentStatus.CREATING) ? p : null;
          _busy = false;
        });
      },
    );
    try {
      await watcher.run();
    } on PaymentCancelled {
      return;
    } on ApiError catch (e) {
      if (valid()) setState(() => _error = e);
    } catch (_) {
      if (valid()) setState(() => _error = ApiError.network());
    } finally {
      if (valid()) setState(() => _busy = false);
    }
  }

  /// PAID: làm mới dữ liệu riêng tư liên quan (lỗi refetch không xoá kết quả PAID).
  void _publishPaid() {
    if (_paidPublished) return;
    _paidPublished = true;
    ref.invalidate(cartProvider);
    ref.invalidate(homeNextSessionProvider);
    ref.invalidate(scheduleWeekProvider);
    ref.invalidate(myClassesProvider);
    ref.invalidate(classDetailProvider);
  }

  String _errorKey(String code) {
    const known = {
      'PAYMENT_UNAVAILABLE', 'PAYMENT_AMOUNT_INVALID', 'ORDER_NOT_FOUND', 'ORDER_ACCESS_DENIED',
      'PAYMENT_REQUIRES_REVIEW', 'PAYMENT_CONFIRMATION_TIMEOUT',
    };
    return known.contains(code) ? 'payment.errors.$code' : 'payment.errors.generic';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final order = _order;
    final result = order?.result;

    if (order != null && result != null) {
      return PopScope(
        canPop: false,
        child: PaymentResultTicket(
          status: result,
          orderCode: order.orderCode,
          amount: order.totalAmount,
          onHome: () => context.go(Routes.home),
          onRetry: () => context.go(Routes.courses),
        ),
      );
    }

    final review = order?.inReview ?? false;
    final errorCode = review
        ? 'PAYMENT_REQUIRES_REVIEW'
        : (_error?.code ?? (order?.paymentType == PaymentType.CASH ? 'PAYMENT_ORDER_INVALID' : null));
    final blocked = review ||
        _error?.code == 'PAYMENT_ORDER_INVALID' ||
        (_error != null && [401, 403, 404].contains(_error!.status));
    final payment = blocked ? null : _payment;
    final remaining = payment?.expiresAt?.difference(DateTime.now());

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('payment.title')),
          leading: IconButton(
            tooltip: t('payment.goCourses'),
            icon: const MindyIcon(MindyIconName.back),
            onPressed: () => context.go(Routes.courses),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (order == null && _error == null) const Skeleton(height: 320),
            if (order != null) ...[
              Text(t('payment.amountLabel'), style: AppText.caption(AppColors.muted)),
              Text(formatVnd(order.totalAmount), style: AppText.sectionTitle(AppColors.forest)),
              const SizedBox(height: 4),
              Text(order.details.map((d) => d.courseTitle).join(', '), style: AppText.body(AppColors.forest)),
              const SizedBox(height: 20),
            ],
            if (payment != null) _qr(t, payment, remaining),
            if (payment == null && order != null && errorCode == null && _busy)
              Text(t('payment.qr.creating'), textAlign: TextAlign.center),
            if (errorCode != null) ...[
              const SizedBox(height: 16),
              ScreenState(
                title: t('payment.title'),
                description: t(_errorKey(errorCode)),
                requestId: _error?.requestId,
                onRetry: blocked || _busy ? null : _start,
              ),
            ],
            const SizedBox(height: 24),
            MindyButton(
              label: t('payment.goCourses'),
              variant: ButtonVariant.outline,
              onPressed: () => context.go(Routes.courses),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qr(Translator t, Payment p, Duration? remaining) {
    final expired = remaining != null && remaining <= Duration.zero;
    String mmss(Duration d) =>
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      children: [
        if (p.qrCode == null)
          Text(t(p.status == PaymentStatus.CREATING ? 'payment.qr.creating' : 'payment.qr.missing'))
        else
          Semantics(
            label: t('payment.qr.label', {'amount': formatVnd(p.amount)}),
            child: Opacity(
              opacity: expired ? 0.3 : 1,
              // Encode NGUYÊN payload backend trả về
              child: QrImageView(data: p.qrCode!, size: 240, backgroundColor: AppColors.canvas),
            ),
          ),
        const SizedBox(height: 8),
        Text(t('payment.qr.caption'), style: AppText.caption(AppColors.muted)),
        if (remaining != null)
          Text(
            // Hết giờ trên client KHÔNG tự biến đơn thành EXPIRED - chờ backend xác nhận
            expired ? t('payment.expired') : t('payment.expiresIn', {'time': mmss(remaining)}),
            style: AppText.label(expired ? AppColors.headsup : AppColors.forest),
          ),
      ],
    );
  }
}
