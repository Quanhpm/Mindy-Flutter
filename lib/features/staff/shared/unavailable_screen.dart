import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../teaching/classes_screens.dart';

class StaffUnavailableScreen extends ConsumerWidget {
  const StaffUnavailableScreen({super.key, required this.manager});
  final bool manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return AttendancePage(
      prefix: 'staff-unavailable',
      title: t('mdy.teaching.notFound'),
      onBack: () => staffBack(context, manager: manager),
      children: [
        MdyCard(
          margin: EdgeInsets.zero,
          children: [MdyText(t('mdy.teaching.notFound'))],
        ),
      ],
    );
  }
}
