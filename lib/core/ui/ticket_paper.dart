import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ticket có mép xé lượn sóng chuẩn RN `TicketPaper.tsx`
class TicketPaper extends StatelessWidget {
  const TicketPaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const TicketClipper(),
    child: Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
      child: child,
    ),
  );
}

class TicketClipper extends CustomClipper<Path> {
  const TicketClipper();

  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;
    final count = (width / 14).round().clamp(1, 1000);
    final step = width / count;

    final path = Path()
      ..moveTo(2, 0)
      ..lineTo(width - 2, 0)
      ..quadraticBezierTo(width, 0, width, 2)
      ..lineTo(width, height - 10);

    for (var index = count; index > 0; index--) {
      final x = index * step;
      final nextX = (index - 1) * step;
      path.quadraticBezierTo(
        x - step * 0.25,
        height - 10,
        x - step * 0.5,
        height - 5,
      );
      path.quadraticBezierTo(
        x - step * 0.75,
        height,
        nextX,
        height - 5,
      );
    }

    path
      ..lineTo(0, 2)
      ..quadraticBezierTo(0, 0, 2, 0)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) => false;
}
