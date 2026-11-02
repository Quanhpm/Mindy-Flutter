import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tờ ghi chú HomeCarousel about, phần góc gấp chỉ để trang trí.
class FoldedPaper extends StatelessWidget {
  const FoldedPaper({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.canvas,
      boxShadow: [
        BoxShadow(color: AppColors.forestNight.withValues(alpha: .25), blurRadius: 12, offset: const Offset(0, 6)),
      ],
    ),
    child: Stack(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 30, 22, 48), child: child),
        const Positioned(
          right: 0,
          bottom: 0,
          width: 40,
          height: 40,
          child: ExcludeSemantics(child: CustomPaint(painter: _FoldPainter())),
        ),
      ],
    ),
  );
}

class _FoldPainter extends CustomPainter {
  const _FoldPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = AppColors.cream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = AppColors.mint,
    );
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) => false;
}
