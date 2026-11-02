import 'package:flutter/material.dart';
import 'staff_theme.dart';

class StaffStats extends StatelessWidget {
  const StaffStats({super.key, required this.items});
  final List<({String label, String value, StatusTone tone})> items;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(color: StaffColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[i].value, style: StaffText.title.copyWith(fontSize: 22, color: items[i].tone.fg)),
                const SizedBox(height: 4),
                Text(items[i].label, style: StaffText.small),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}
