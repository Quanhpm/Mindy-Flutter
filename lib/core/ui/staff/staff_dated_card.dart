import 'package:flutter/material.dart';
import 'staff_theme.dart';
import 'staff_widgets.dart';

/// Hàng lịch sử dùng chung: ngày bên trái, nội dung co giãn và action xuống dòng.
class StaffDatedCard extends StatelessWidget {
  const StaffDatedCard({
    super.key,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String date, title, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: StaffColors.tealSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(date, style: StaffText.bodyStrong.copyWith(color: StaffColors.teal700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: StaffText.bodyStrong),
                  const SizedBox(height: 4),
                  Text(subtitle, style: StaffText.caption),
                ],
              ),
            ),
          ],
        ),
        if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
      ],
    ),
  );
}
