import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/network/api_error.dart';
import '../../core/router/routes.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/utils/format.dart';
import '../cart/cart_controller.dart';
import '../home/home_providers.dart';
import '../my_classes/my_classes_api.dart';
import '../my_classes/my_classes_providers.dart';
import '../schedule/schedule_providers.dart';
import 'payment_api.dart';
import 'payment_models.dart';
import 'payment_result_ticket.dart';
import 'payment_watcher.dart';

/// Màn thanh toán QR chuẩn RN - `modules/payment/PaymentScreen.tsx`.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    this.fromLearning = false,
  });

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
  bool _confirmingLeave = false;
  WatchToken? _token;
  bool _paidPublished = false;
  Timer? _ticker;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    Future.microtask(_start);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _order?.result != null) {
        _ticker?.cancel();
        return;
      }
      setState(() {}); // cập nhật countdown mỗi giây
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _token?.cancel();
    _ticker?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTicker();
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _token?.cancel();
      _ticker?.cancel();
    }
  }

  Future<void> _start() async {
    if (_order?.result != null) return;
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

  void _publishPaid() {
    if (_paidPublished) return;
    _paidPublished = true;
    ref.invalidate(cartProvider);
    ref.invalidate(homeNextSessionProvider);
    ref.invalidate(scheduleWeekProvider);
    ref.invalidate(myClassesProvider);
    ref.invalidate(classDetailProvider);
  }

  void _onCopy(String label, String value) {
    final t = ref.read(trProvider);
    Clipboard.setData(ClipboardData(text: value));
    setState(() {
      _toast = t('payment.copied', {'label': label});
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _leave() async {
    if (_confirmingLeave) return;
    if (_order?.result != null) {
      context.go(Routes.courses);
      return;
    }

    final t = ref.read(trProvider);
    final expiresAt = _payment?.expiresAt ?? _order?.expiresAt;
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    if (expired) {
      _token?.cancel();
      context.go(Routes.courses);
      return;
    }

    _confirmingLeave = true;

    final timeStr = expiresAt == null
        ? '—'
        : '${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}';

    final leave = await showAppSheet<bool>(
      context,
      (sheet) => SingleChildScrollView(
        controller: PrimaryScrollController.of(sheet),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                t('payment.leave.title'),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('payment.leave.message', {'time': timeStr}),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                height: 22 / 14,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            MindyButton(
              key: const Key('payment-leave-stay'),
              label: t('payment.leave.stay'),
              onPressed: () => Navigator.pop(sheet, false),
            ),
            const SizedBox(height: 12),
            MindyButton(
              key: const Key('payment-leave-confirm'),
              label: t('payment.leave.confirm'),
              variant: ButtonVariant.outline,
              onPressed: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
      initialSize: .55,
    );

    if (!mounted) return;
    _confirmingLeave = false;
    if (leave == true && _order?.result == null) {
      _token?.cancel();
      context.go(Routes.courses);
    }
  }

  String _errorKey(String code) {
    const known = {
      'PAYMENT_UNAVAILABLE',
      'PAYMENT_AMOUNT_INVALID',
      'ORDER_NOT_FOUND',
      'ORDER_ACCESS_DENIED',
      'PAYMENT_REQUIRES_REVIEW',
      'PAYMENT_CONFIRMATION_TIMEOUT',
    };
    return known.contains(code) ? 'payment.errors.$code' : 'payment.errors.generic';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final order = _order;
    final result = order?.result;
    final insets = MediaQuery.paddingOf(context);
    final fontScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    // Terminal result ticket overlay
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
    final blocked =
        review ||
        _error?.code == 'PAYMENT_ORDER_INVALID' ||
        (_error != null && [401, 403, 404].contains(_error!.status));
    final payment = blocked ? null : _payment;

    final expiresAt = payment?.expiresAt ?? order?.expiresAt;
    final remainingSeconds = expiresAt == null
        ? null
        : (expiresAt.difference(DateTime.now()).inSeconds).clamp(0, 86400 * 30);
    final expired = remainingSeconds != null && remainingSeconds <= 0 && result == null;
    final creating = !expired && (payment == null || payment.status == PaymentStatus.CREATING);

    final countdownTime = remainingSeconds == null
        ? ''
        : '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';

    final bank = Env.developmentBank ??
        (Env.isProduction
            ? null
            : (name: 'MB Bank', account: '0123 456 789', owner: 'CONG TY MINDY CODING'));

    final rows = <({String key, String value, bool copy})>[
      if (order != null)
        (
          key: 'courses',
          value: order.details.map((d) => d.courseTitle).join(', '),
          copy: false,
        ),
      if (bank != null) ...[
        (key: 'bank', value: bank.name, copy: false),
        (key: 'account', value: bank.account, copy: true),
        (key: 'owner', value: bank.owner, copy: false),
      ],
      if (order != null)
        (
          key: 'amount',
          value: formatVnd(payment?.amount ?? order.totalAmount),
          copy: false,
        ),
      if (bank != null && order != null)
        (
          key: 'note',
          value: 'MINDY ${order.orderCode}',
          copy: true,
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            // Background & Main ScrollView
            Container(
              key: const Key('payment-background'),
              color: AppColors.canvas,
              child: ListView(
                key: const Key('payment-screen'),
                padding: EdgeInsets.fromLTRB(
                  20,
                  insets.top + 16,
                  20,
                  insets.bottom + 32,
                ),
                children: [
                  // Header Row: Back button, Title, blank 40
                  Row(
                    children: [
                      Pressable(
                        onTap: _leave,
                        semanticLabel: t('payment.leave.confirm'),
                        child: Container(
                          key: const Key('payment-back'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.line),
                          ),
                          alignment: Alignment.center,
                          child: const MindyIcon(MindyIconName.back, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            t('payment.title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Label
                  Text(
                    t('payment.amountLabel'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),

                  // Amount Value
                  const SizedBox(height: 2),
                  Text(
                    order != null ? formatVnd(payment?.amount ?? order.totalAmount) : '—',
                    key: const Key('payment-amount'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.56,
                      color: AppColors.forest,
                    ),
                  ),

                  // Countdown Pill
                  if (!creating) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MindyIcon(
                              MindyIconName.clock,
                              size: 13,
                              color: AppColors.ember,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              expired
                                  ? t('payment.expired')
                                  : t('payment.expiresIn', {'time': countdownTime}),
                              key: const Key('payment-expiry'),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.ember,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Error state or QR Box
                  const SizedBox(height: 16),
                  if (errorCode != null) ...[
                    ScreenState(
                      title: t('payment.title'),
                      description: t(_errorKey(errorCode)),
                      requestId: _error?.requestId,
                      onRetry: blocked || _busy ? null : _start,
                      retryKey: const Key('payment-retry'),
                    ),
                  ] else ...[
                    // QR Box
                    Center(
                      child: Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A1D5B57), // shadow-md shadow-forest/10
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expired && (payment?.qrCode == null || payment!.qrCode!.isEmpty)) ...[
                              Container(
                                key: const Key('payment-qr-expired'),
                                constraints: const BoxConstraints(minHeight: 196),
                                alignment: Alignment.center,
                                child: Text(
                                  t('payment.qr.expired'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.headsup,
                                  ),
                                ),
                              ),
                            ] else if (creating) ...[
                              Column(
                                key: const Key('payment-qr-loading'),
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Skeleton(width: 196, height: 196),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t('payment.qr.creating'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (payment?.qrCode != null && payment!.qrCode!.isNotEmpty) ...[
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: expired ? 0.15 : 1.0,
                                    child: Semantics(
                                      image: true,
                                      label: t('payment.qr.label', {
                                        'amount': formatVnd(payment.amount),
                                      }),
                                      child: Container(
                                        key: const Key('payment-qr'),
                                        width: 196,
                                        height: 196,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: QrImageView(
                                          data: payment.qrCode!,
                                          size: 180,
                                          padding: const EdgeInsets.all(8),
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: AppColors.forest,
                                          ),
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: AppColors.forest,
                                          ),
                                          backgroundColor: AppColors.canvas,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (expired)
                                    Container(
                                      key: const Key('payment-qr-expired'),
                                      constraints: const BoxConstraints(minHeight: 196),
                                      alignment: Alignment.center,
                                      child: Text(
                                        t('payment.qr.expired'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: AppColors.headsup,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                key: const Key('payment-qr-missing'),
                                constraints: const BoxConstraints(minHeight: 196),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      t('payment.qr.missing'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    if (!expired) ...[
                                      const SizedBox(height: 12),
                                      MindyButton(
                                        key: const Key('payment-retry'),
                                        label: t('common.retry'),
                                        variant: ButtonVariant.outline,
                                        loading: _busy,
                                        onPressed: _start,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            if (!creating) ...[
                              const SizedBox(height: 8),
                              Text(
                                t('payment.qr.caption'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Go to Courses button (when expired or order not found/denied)
                  if (expired || errorCode == 'ORDER_NOT_FOUND' || errorCode == 'ORDER_ACCESS_DENIED') ...[
                    const SizedBox(height: 16),
                    MindyButton(
                      key: const Key('payment-go-courses'),
                      label: t('payment.goCourses'),
                      variant: ButtonVariant.solid,
                      radius: 14,
                      minHeight: 52,
                      onPressed: _leave,
                    ),
                  ],

                  // Bank & Transfer Info Box
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      key: const Key('payment-info'),
                      decoration: BoxDecoration(
                        color: AppColors.soft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (int i = 0; i < rows.length; i++) ...[
                            _buildInfoRow(t, rows[i], fontScale),
                            if (i < rows.length - 1)
                              const Divider(height: 1, color: AppColors.line),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Note text
                  const SizedBox(height: 10),
                  Text(
                    t('payment.note'),
                    key: const Key('payment-note'),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12.5,
                      height: 18.75 / 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // Toast overlay
            if (_toast != null && result == null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 32 + insets.bottom,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D1D5B57), // shadow-xl shadow-forest/30
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Text(
                    _toast!,
                    key: const Key('payment-toast'),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.canvas,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    Translator t,
    ({String key, String value, bool copy}) row,
    double fontScale,
  ) {
    final rowKey = Key('payment-info-row-${row.key}');
    final labelText = t('payment.info.${row.key}');

    if (fontScale > 1.3) {
      return Container(
        key: rowKey,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labelText,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              row.value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.black,
              ),
            ),
            if (row.copy) ...[
              const SizedBox(height: 6),
              _buildCopyButton(t, row),
            ],
          ],
        ),
      );
    }

    return Container(
      key: rowKey,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              labelText,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.black,
              ),
            ),
          ),
          if (row.copy) ...[
            const SizedBox(width: 10),
            _buildCopyButton(t, row),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyButton(
    Translator t,
    ({String key, String value, bool copy}) row,
  ) {
    final labelText = t('payment.info.${row.key}');
    return Pressable(
      onTap: () => _onCopy(labelText.toLowerCase(), row.value),
      semanticLabel: '${t('payment.info.copy')} $labelText',
      child: Container(
        key: Key('payment-copy-${row.key}'),
        constraints: const BoxConstraints(minHeight: 30),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.banner),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        child: Text(
          t('payment.info.copy'),
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.forest,
          ),
        ),
      ),
    );
  }
}
