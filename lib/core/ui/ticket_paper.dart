import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ticket có mép xé thật; không dùng ký tự răng cưa phụ thuộc font.
class TicketPaper extends StatelessWidget {
  const TicketPaper({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _TicketClipper(),
    child: Container(color: AppColors.canvas, padding: const EdgeInsets.fromLTRB(24, 32, 24, 36), child: child),
  );
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();
  @override
  Path getClip(Size size) {
    const tooth = 12.0;
    final count = (size.width / tooth).ceil();
    final step = size.width / count;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 8);
    for (var i = count; i > 0; i--) {
      path.lineTo((i - .5) * step, size.height);
      path.lineTo((i - 1) * step, size.height - 8);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => false;
}
