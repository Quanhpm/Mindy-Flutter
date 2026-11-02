import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import 'payment_models.dart';

/// Ticket kết quả mép xé - `payment/components/PaymentResultTicket.tsx`.
/// Chỉ 3 trạng thái: PAID / CANCELLED / EXPIRED.
/// TODO(UI): vẽ mép xé bằng CustomClipper + ribbon theo ảnh owner
/// (`docs/IMPLEMENT/PHASE_05_PAYMENT_RESULT/references`).
class PaymentResultTicket extends ConsumerWidget {
  const PaymentResultTicket({
    super.key,
    required this.status,
    required this.orderCode,
    required this.amount,
    required this.onHome,
    required this.onRetry,
  });

  final OrderStatus status;
  final String orderCode;
  final int amount;
  final VoidCallback onHome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final paid = status == OrderStatus.PAID;
    final key = 'payment.result.${status.name}';

    return Scaffold(
      backgroundColor: AppColors.soft,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(28)),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: paid ? AppColors.statusGreen : AppColors.ribbon,
                    ),
                    child: Center(
                      child: MindyIcon(paid ? MindyIconName.check : MindyIconName.help, size: 36, color: AppColors.canvas),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(t('$key.title'), textAlign: TextAlign.center, style: AppText.title(AppColors.black)),
                  ),
                  const SizedBox(height: 8),
                  Text(t('$key.description'), textAlign: TextAlign.center, style: AppText.body(AppColors.inkGray)),
                  const Divider(height: 40),
                  _line(t('payment.result.orderLabel'), orderCode),
                  _line(t('payment.result.totalLabel'), formatVnd(amount)),
                  if (!paid) ...[
                    const SizedBox(height: 12),
                    Text(t('payment.result.retryHint'), style: AppText.caption(AppColors.inkGray)),
                  ],
                  const SizedBox(height: 24),
                  paid
                      ? MindyButton(label: t('payment.result.actions.home'), onPressed: onHome)
                      : MindyButton(label: t('payment.result.actions.retry'), onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.caption(AppColors.inkGray))),
          Text(value, style: AppText.label(AppColors.black)),
        ]),
      );
}
