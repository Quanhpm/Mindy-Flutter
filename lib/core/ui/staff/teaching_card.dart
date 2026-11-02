import 'package:flutter/material.dart';

import 'staff_theme.dart';
import 'staff_widgets.dart';
import 'sym.dart';

/// Thẻ buổi dùng chung lịch/dạy thay. Chỉ nhận dữ liệu trình bày, không phụ thuộc feature.
class TeachingCard extends StatelessWidget {
  const TeachingCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
    this.substituteLabel,
    this.mentorLabel,
    this.dayLabel,
    this.attendanceLabel,
    this.roomLabel,
    this.onAttendance,
    this.onRoom,
  });
  final String startTime, endTime, title, subtitle, status;
  final StatusTone tone;
  final String? substituteLabel, mentorLabel, dayLabel, attendanceLabel, roomLabel;
  final VoidCallback? onAttendance, onRoom;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dayLabel != null) ...[Text(dayLabel!, style: StaffText.link), const SizedBox(height: 12)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76 * (MediaQuery.textScalerOf(context).scale(22) / 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(startTime, style: StaffText.title.copyWith(fontSize: 22, color: StaffColors.teal700)),
                  Text(endTime, style: StaffText.caption),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(status, tone: tone),
                      if (substituteLabel != null)
                        StatusChip(substituteLabel!, tone: StatusTone.amber, icon: Sym.swapHoriz),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: StaffText.bodyStrong),
                  const SizedBox(height: 6),
                  Text(subtitle, style: StaffText.caption),
                  if (mentorLabel != null) ...[const SizedBox(height: 6), Text(mentorLabel!, style: StaffText.caption)],
                ],
              ),
            ),
          ],
        ),
        if (onAttendance != null || onRoom != null) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(15) > 18;
              final buttons = [
                if (onAttendance != null)
                  StaffButton(label: attendanceLabel!, icon: Sym.factCheck, onPressed: onAttendance),
                if (onRoom != null)
                  StaffButton(label: roomLabel!, icon: Sym.videocam, outlined: true, onPressed: onRoom),
              ];
              if (vertical) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: 8), buttons[i]],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: buttons[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}
