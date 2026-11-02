import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ticket_paper.dart';
import '../../core/utils/format.dart';
import 'payment_models.dart';

/// Ticket kết quả mép xé - `payment/components/PaymentResultTicket.tsx`.
/// Chỉ 3 trạng thái: PAID / CANCELLED / EXPIRED.
class PaymentResultTicket extends ConsumerWidget {
  const PaymentResultTicket({
    super.key,
    required this.status,
    this.orderCode,
    this.amount,
    required this.onHome,
    required this.onRetry,
  });

  final OrderStatus status;
  final String? orderCode;
  final int? amount;
  final VoidCallback onHome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final paid = status == OrderStatus.PAID;
    final key = 'payment.result.${status.name}';

    return Scaffold(
      backgroundColor: const Color(0x99000000), // bg-black/60
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              key: const Key('payment-result-surface'),
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ticket Paper
                  TicketPaper(
                    key: const Key('payment-result-ticket'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon 56x56
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CustomPaint(
                            size: const Size(56, 56),
                            painter: _ResultIconPainter(
                              status: status,
                              color: paid ? AppColors.forest : AppColors.headsup,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Semantics(
                          header: true,
                          child: Text(
                            t('$key.title'),
                            key: const Key('payment-result-title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 28 / 22,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          t('$key.description'),
                          key: const Key('payment-result-description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            height: 21 / 14,
                            color: AppColors.muted,
                          ),
                        ),

                        // Order Info
                        if (orderCode != null || amount != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            key: const Key('payment-result-order'),
                            padding: const EdgeInsets.only(top: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Dashed divider
                                const _DashedDivider(),
                                if (orderCode != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    t('payment.result.orderLabel'),
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 13,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    orderCode!,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 19 / 13,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ],
                                if (amount != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: AppColors.line)),
                                    ),
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('payment.result.totalLabel'),
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 13,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formatVnd(amount!),
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 28,
                                            height: 34 / 28,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Retry hint
                        if (!paid) ...[
                          const SizedBox(height: 16),
                          Text(
                            t('payment.result.retryHint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              height: 19 / 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action Button
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      key: Key(paid ? 'payment-result-home' : 'payment-result-retry'),
                      onPressed: paid ? onHome : onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.canvas,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2), // rounded-[2px]
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        t(paid ? 'payment.result.actions.home' : 'payment.result.actions.retry'),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.canvas,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final count = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.line),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ResultIconPainter extends CustomPainter {
  const _ResultIconPainter({required this.status, required this.color});

  final OrderStatus status;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0;
    final strokeWidth = 3.0 * scale;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Circle at cx=24, cy=24, r=19
    canvas.drawCircle(Offset(24 * scale, 24 * scale), 19 * scale, paint);

    final path = Path();
    if (status == OrderStatus.PAID) {
      // M14 24l7 7 14-16
      path.moveTo(14 * scale, 24 * scale);
      path.lineTo(21 * scale, 31 * scale);
      path.lineTo(35 * scale, 15 * scale);
    } else if (status == OrderStatus.CANCELLED) {
      // M17 17l14 14M31 17 17 31
      path.moveTo(17 * scale, 17 * scale);
      path.lineTo(31 * scale, 31 * scale);
      path.moveTo(31 * scale, 17 * scale);
      path.lineTo(17 * scale, 31 * scale);
    } else {
      // EXPIRED: M24 13v12l8 5
      path.moveTo(24 * scale, 13 * scale);
      path.lineTo(24 * scale, 25 * scale);
      path.lineTo(32 * scale, 30 * scale);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ResultIconPainter oldDelegate) =>
      oldDelegate.status != status || oldDelegate.color != color;
}
