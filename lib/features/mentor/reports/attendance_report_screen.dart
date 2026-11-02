import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_dated_card.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../classes/class_picker.dart';
import '../classes/classes_providers.dart';
import 'reports_models.dart';
import 'reports_providers.dart';

class MentorAttendanceReportScreen extends ConsumerStatefulWidget {
  const MentorAttendanceReportScreen({super.key});
  @override
  ConsumerState<MentorAttendanceReportScreen> createState() => _MentorAttendanceReportScreenState();
}

class _MentorAttendanceReportScreenState extends ConsumerState<MentorAttendanceReportScreen> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), classes = ref.watch(mentorPrimaryClassesProvider);
    final available = classes.isLoading || classes.hasError ? null : classes.value;
    final id = available == null || available.isEmpty
        ? null
        : available.any((c) => c.id == _selected)
        ? _selected
        : available.first.id;
    final value = id == null ? null : ref.watch(mentorClassReportProvider(id));
    void retry() {
      if (id != null) {
        ref.invalidate(mentorPrimaryWorkspaceProvider(id));
        ref.invalidate(mentorClassAttendanceSummaryProvider(id));
        ref.invalidate(mentorWorkspaceSessionsProvider(id));
        ref.invalidate(mentorClassReportProvider(id));
      }
    }

    return StaffPage(
      title: t('mentor.reports.title'),
      subtitle: t('mentor.reports.subtitle'),
      body: RefreshIndicator(
        onRefresh: () async {
          if (id == null) {
            ref.invalidate(mentorPrimaryClassesProvider);
            await ref.read(mentorPrimaryClassesProvider.future);
          } else {
            retry();
            await ref.read(mentorClassReportProvider(id).future);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            MentorClassPicker(value: classes, selectedId: id, onSelected: (id) => setState(() => _selected = id)),
            const SizedBox(height: 20),
            if (value != null)
              ...value.when(
                skipLoadingOnRefresh: false,
                loading: () => [const Skeleton(height: 120), const SizedBox(height: 16), const Skeleton(height: 200)],
                error: (error, _) => [
                  StaffDataState(
                    title: t('mentor.reports.loadError'),
                    description: t(errorKey(error)),
                    error: error,
                    onRetry: retry,
                  ),
                ],
                data: (data) {
                  final rate = weightedAttendance(data.summary.items.map((row) => row.counts));
                  return [
                    Text(data.workspace.name, style: StaffText.section),
                    const SizedBox(height: 16),
                    StaffStats(
                      items: [
                        (
                          label: t('mentor.reports.average'),
                          value: formatPercent(rate, t.locale.languageCode),
                          tone: StatusTone.teal,
                        ),
                        (
                          label: t('mentor.reports.completed'),
                          value: '${data.sessions.length}/${data.workspace.sessionCount}',
                          tone: StatusTone.blue,
                        ),
                        (
                          label: t('mentor.reports.absent'),
                          value: '${data.summary.items.fold(0, (total, row) => total + row.counts.absent)}',
                          tone: StatusTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(t('mentor.reports.aggregateNote'), style: StaffText.small),
                    const SizedBox(height: 24),
                    Text(t('mentor.reports.physical'), style: StaffText.section),
                    const SizedBox(height: 8),
                    Text(t('mentor.reports.physicalNote'), style: StaffText.small),
                    const SizedBox(height: 16),
                    if (data.sessions.isEmpty)
                      StaffDataState(
                        title: t('mentor.reports.empty'),
                        description: t('mentor.reports.emptyDescription'),
                      ),
                    for (final report in data.sessions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaffDatedCard(
                          date: Dates.dateOnly(Dates.localDay(report.row.session.startsAt, data.workspace.timeZone)),
                          title: report.row.session.title,
                          subtitle: Dates.instant(report.row.session.startsAt, data.workspace.timeZone),
                          children: [
                            if (report.denied)
                              Text(t('mentor.classes.contextRestricted'), style: StaffText.caption)
                            else if (report.error != null)
                              StaffDataState(
                                title: t('mentor.reports.rowError'),
                                description: t(errorKey(report.error!)),
                                error: report.error,
                                onRetry: retry,
                              )
                            else ...[
                              Text(
                                formatPercent(report.rate, t.locale.languageCode),
                                style: StaffText.title.copyWith(color: StaffColors.teal700),
                              ),
                              Text(
                                t('mentor.reports.sessionCounts', {
                                  'present': report.totals!.present,
                                  'eligible': report.totals!.eligible,
                                  'unmarked': report.totals!.unmarked,
                                }),
                                style: StaffText.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }
}
