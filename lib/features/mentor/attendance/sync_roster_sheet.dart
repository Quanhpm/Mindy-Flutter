import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';

class SyncRosterContent extends ConsumerWidget {
  const SyncRosterContent({super.key, required this.pendingPaymentCount, required this.onConfirm});
  final int pendingPaymentCount;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('mentor.attendance.syncDescription'), style: StaffText.body),
        if (pendingPaymentCount > 0) ...[
          const SizedBox(height: 12),
          Text(t('mentor.attendance.pendingPayment', {'count': pendingPaymentCount}), style: StaffText.caption),
        ],
        const SizedBox(height: 20),
        StaffButton(label: t('mentor.attendance.sync'), icon: Sym.sync, onPressed: onConfirm),
      ],
    );
  }
}
