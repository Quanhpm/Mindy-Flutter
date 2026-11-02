import 'package:flutter/material.dart';

import '../../utils/format.dart';
import '../pressable.dart';
import 'staff_theme.dart';

/// Dải bảy ngày; tự cuộn khi chữ lớn để giữ vùng bấm 44px và không cắt nhãn.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.labels,
    required this.selectedDay,
    required this.today,
    required this.markedDays,
    required this.onSelected,
  });
  final List<String> days, labels;
  final String selectedDay, today;
  final Set<String> markedDays;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final width = (constraints.maxWidth / 7).clamp(44.0 * scale, double.infinity);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Pressable(
                onTap: () => onSelected(days[i]),
                selected: days[i] == selectedDay,
                semanticLabel: '${labels[i]}, ${Dates.displayDay(days[i])}',
                child: Container(
                  width: width,
                  constraints: const BoxConstraints(minHeight: 76),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  decoration: BoxDecoration(
                    color: days[i] == selectedDay ? StaffColors.surface : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: StaffText.small.copyWith(
                          color: days[i] == selectedDay ? StaffColors.teal700 : StaffColors.onTealMuted,
                        ),
                      ),
                      Text(
                        '${int.parse(days[i].substring(8))}',
                        style: StaffText.title.copyWith(
                          color: days[i] == selectedDay ? StaffColors.teal700 : StaffColors.surface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markedDays.contains(days[i]) || days[i] == today
                              ? (days[i] == selectedDay ? StaffColors.teal600 : StaffColors.mint)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
