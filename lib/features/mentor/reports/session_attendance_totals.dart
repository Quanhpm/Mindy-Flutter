import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/utils/format.dart';
import 'reports_providers.dart';

/// Chi tiết lớp dùng cùng cache báo cáo, nên không đọc roster lần hai.
class MentorSessionAttendanceTotals extends ConsumerWidget {
  const MentorSessionAttendanceTotals({super.key, required this.classId, required this.sessionId});
  final String classId, sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), provider = mentorClassReportProvider(classId);
    return ref
        .watch(provider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Skeleton(height: 20),
          error: (error, _) =>
              TextButton(onPressed: () => ref.invalidate(provider), child: Text(t('mentor.reports.rowError'))),
          data: (data) {
            final row = data.sessions.where((row) => row.row.session.id == sessionId).firstOrNull;
            if (row == null) {
              return TextButton(onPressed: () => ref.invalidate(provider), child: Text(t('mentor.reports.rowError')));
            }
            if (row.denied) {
              return Text(t('mentor.classes.contextRestricted'), style: StaffText.caption);
            }
            if (row.error != null) {
              return TextButton(onPressed: () => ref.invalidate(provider), child: Text(t('common.retry')));
            }
            return Text(
              '${t('mentor.reports.sessionCounts', {'present': row.totals!.present, 'eligible': row.totals!.eligible, 'unmarked': row.totals!.unmarked})} · ${formatPercent(row.rate, t.locale.languageCode)}',
              style: StaffText.caption,
            );
          },
        );
  }
}
