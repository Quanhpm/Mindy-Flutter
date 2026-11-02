import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_dated_card.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../reports/reports_models.dart';
import 'students_models.dart';
import 'students_providers.dart';

Future<void> showMentorStudentDetails(BuildContext context, WidgetRef ref, String classId, MentorStudent student) =>
    showStaffSheet<void>(
      context,
      title: student.name,
      subtitle: ref.read(trProvider)('mentor.students.detail'),
      builder: (_) => MentorStudentDetailContent(query: (classId: classId, studentId: student.studentId)),
    );

class MentorStudentDetailContent extends ConsumerWidget {
  const MentorStudentDetailContent({super.key, required this.query});
  final MentorStudentQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), provider = mentorStudentDetailsProvider(query);
    // Không giữ dữ liệu học viên của phiên cũ trên modal sau logout/chuyển tài khoản.
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ref
          .watch(provider)
          .when(
            skipLoadingOnRefresh: false,
            loading: () => [const Skeleton(height: 220)],
            error: (error, _) => [
              StaffDataState(
                title: t('mentor.students.loadError'),
                description: t(errorKey(error)),
                error: error,
                onRetry: () => ref.invalidate(provider),
              ),
            ],
            data: (data) {
              final counts = data.summary.counts;
              final history = data.history.items.toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
              return [
                StaffStats(
                  items: [
                    (
                      label: t('mentor.reports.average'),
                      value: formatPercent(counts.rate, t.locale.languageCode),
                      tone: StatusTone.teal,
                    ),
                    (label: t('mentor.attendance.status.PRESENT'), value: '${counts.present}', tone: StatusTone.green),
                    (label: t('mentor.attendance.status.ABSENT'), value: '${counts.absent}', tone: StatusTone.amber),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t('mentor.students.historyScope'), style: StaffText.small),
                const SizedBox(height: 20),
                Text(t('mentor.students.history'), style: StaffText.section),
                const SizedBox(height: 12),
                if (history.isEmpty) Text(t('mentor.students.noHistory'), style: StaffText.caption),
                for (final row in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StaffDatedCard(
                      date: Dates.dateOnly(Dates.localDay(row.startsAt, data.history.timeZone)),
                      title: row.title,
                      subtitle:
                          '${Dates.time(row.startsAt, data.history.timeZone)} – ${Dates.time(row.endsAt, data.history.timeZone)}',
                      children: [
                        Text(t('mentor.students.applicability.${row.applicability.name}'), style: StaffText.bodyStrong),
                        if (row.status != null)
                          Text(
                            t('mentor.students.physicalStatus', {
                              'status': t('mentor.attendance.status.${row.status!.name}'),
                            }),
                            style: StaffText.caption,
                          ),
                        if (row.applicability == AttendanceApplicability.MAKEUP_CREDITED && row.creditedStatus != null)
                          Text(
                            t('mentor.students.creditStatus', {
                              'status': t('mentor.attendance.status.${row.creditedStatus!.name}'),
                            }),
                            style: StaffText.caption,
                          ),
                        if (row.excluded) Text(t('mentor.students.excluded'), style: StaffText.small),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(t('mentor.students.storedProgress'), style: StaffText.section),
                const SizedBox(height: 8),
                Text(t('mentor.students.progressNote'), style: StaffText.caption),
                const SizedBox(height: 12),
                if (data.progress.items.isEmpty) Text(t('mentor.students.noProgress'), style: StaffText.caption),
                for (final unit in data.progress.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            data.units.where((u) => u.id == unit.unitId).firstOrNull?.title ??
                                t('mentor.classes.unitUnavailable'),
                            style: StaffText.bodyStrong,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unit.tracking == StoredTrackingStatus.UNTRACKED
                                ? t('mentor.students.untracked')
                                : unit.quality == StoredDataQuality.INVALID_PERCENT
                                ? t('mentor.students.invalidProgress')
                                : t('mentor.students.storedValue', {
                                    'value': formatPercent(
                                      unit.percent == null ? null : double.parse(unit.percent!),
                                      t.locale.languageCode,
                                    ),
                                  }),
                            style: StaffText.caption,
                          ),
                          if (unit.completedAt != null)
                            Text(
                              t('mentor.students.storedDate', {
                                'date': Dates.instant(unit.completedAt!, data.progress.timeZone),
                              }),
                              style: StaffText.small,
                            ),
                        ],
                      ),
                    ),
                  ),
              ];
            },
          ),
    );
  }
}
