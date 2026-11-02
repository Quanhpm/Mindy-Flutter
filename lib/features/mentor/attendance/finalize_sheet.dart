import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import 'attendance_models.dart';

class FinalizeAttendanceContent extends ConsumerWidget {
  const FinalizeAttendanceContent({super.key, required this.totals, required this.onConfirm});
  final AttendanceTotals totals;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffStats(
          items: [
            (label: t('mentor.attendance.present'), value: '${totals.present}', tone: StatusTone.green),
            (label: t('mentor.attendance.absent'), value: '${totals.absent}', tone: StatusTone.red),
            (label: t('mentor.attendance.unmarked'), value: '${totals.unmarked}', tone: StatusTone.gray),
          ],
        ),
        const SizedBox(height: 16),
        Text(t('mentor.attendance.finalizeWarning', {'count': totals.unmarked}), style: StaffText.body),
        const SizedBox(height: 8),
        Text(t('mentor.attendance.finalizeEditable'), style: StaffText.caption),
        const SizedBox(height: 20),
        StaffButton(label: t('mentor.attendance.finalizeConfirm'), onPressed: onConfirm),
      ],
    );
  }
}
