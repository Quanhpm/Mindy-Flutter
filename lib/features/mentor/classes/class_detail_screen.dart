import '../operations/session_edit_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_dated_card.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../attendance/attendance_sheet.dart';
import '../reports/reports_providers.dart';
import '../reports/session_attendance_totals.dart';
import '../schedule/schedule_models.dart';
import '../schedule/schedule_providers.dart';
import '../schedule/schedule_widgets.dart';
import '../session/live_room_sheet.dart';
import '../students/students_providers.dart';
import 'class_picker.dart';
import 'classes_models.dart';
import 'classes_providers.dart';

class MentorClassDetailScreen extends ConsumerStatefulWidget {
  const MentorClassDetailScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<MentorClassDetailScreen> createState() => _MentorClassDetailScreenState();
}

class _MentorClassDetailScreenState extends ConsumerState<MentorClassDetailScreen> {
  bool _past = false;
  void _refresh() {
    ref.invalidate(mentorPrimaryWorkspaceProvider(widget.classId));
    ref.invalidate(mentorWorkspaceSessionsProvider(widget.classId));
    ref.invalidate(mentorClassUnitsProvider(widget.classId));
    ref.invalidate(mentorClassOverviewProvider(widget.classId));
    ref.invalidate(mentorClassDetailProvider(widget.classId));
    ref.invalidate(mentorClassReportProvider(widget.classId));
    ref.invalidate(mentorClassAttendanceSummaryProvider(widget.classId));
    ref.invalidate(mentorStudentsProvider(widget.classId));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), value = ref.watch(mentorClassDetailProvider(widget.classId));
    final now = ref.watch(mentorNowProvider).value ?? ref.read(mentorClockProvider)();
    return StaffPage(
      title: t('mentor.classes.detail'),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await ref.read(mentorClassDetailProvider(widget.classId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: value.when(
            skipLoadingOnRefresh: false,
            loading: () => [const Skeleton(height: 240), const SizedBox(height: 16), const Skeleton(height: 160)],
            error: (error, _) => [
              StaffDataState(
                title: t('mentor.classes.loadError'),
                description: t(errorKey(error)),
                error: error,
                onRetry: _refresh,
              ),
            ],
            data: (detail) {
              final overview = detail.overview, w = overview.workspace;
              final today = Dates.localDay(now, w.timeZone);
              final rows =
                  overview.sessions.where((row) {
                    final status = row.session.displayStatus(now);
                    final past = status != TeachingDisplayStatus.live && status != TeachingDisplayStatus.upcoming;
                    return past == _past;
                  }).toList()..sort(
                    (a, b) => _past
                        ? b.session.startsAt.compareTo(a.session.startsAt)
                        : a.session.startsAt.compareTo(b.session.startsAt),
                  );
              final roomRow = overview.roomToday(now);
              TeachingEntry entry(MentorWorkspaceSession row) =>
                  TeachingEntry(session: row.session, className: w.name, classCode: w.code);
              return [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(w.code, style: StaffText.eyebrow),
                      const SizedBox(height: 8),
                      Text(w.name, style: StaffText.title),
                      Text(w.courseTitle, style: StaffText.caption),
                      const SizedBox(height: 12),
                      Wrap(
                        children: [
                          StatusChip(t('mentor.classes.status.${w.status.name}'), tone: mentorClassTone(w.status)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('mentor.classes.structure', {'units': w.unitCount, 'sessions': w.sessionCount}),
                        style: StaffText.bodyStrong,
                      ),
                      if (w.readonly) ...[
                        const SizedBox(height: 8),
                        Text(t('mentor.classes.readonly'), style: StaffText.caption),
                      ],
                      if (w.readRoster)
                        TextButton(
                          onPressed: () => context.push(Routes.mentorStudents(w.id)),
                          child: Text(t('mentor.classes.viewStudents', {'count': overview.enrollmentCount ?? '—'})),
                        ),
                      if (roomRow != null)
                        StaffButton(
                          label: t('mentor.session.enterRoom'),
                          onPressed: () => showMentorRoom(context, ref, entry(roomRow)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilterChipsBar<bool>(
                  items: [(false, t('mentor.classes.upcoming')), (true, t('mentor.classes.past'))],
                  selected: _past,
                  onSelected: (v) => setState(() => _past = v),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  StaffDataState(
                    title: t('mentor.classes.noSessions'),
                    description: t('mentor.classes.noSessionsDescription'),
                  ),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Builder(
                      builder: (context) {
                        final s = row.session, slot = detail.slot(row.session.id), status = s.displayStatus(now);
                        final units = detail.units.where((unit) => unit.id == s.classUnitId);
                        final unit = units.isEmpty ? t('mentor.classes.unitUnavailable') : units.first.title;
                        final title = slot == null
                            ? s.title
                            : t('mentor.classes.sessionTitle', {'number': slot.number, 'unit': unit});
                        final todayAccessible =
                            Dates.localDay(s.startsAt, w.timeZone) == today &&
                            row.readContext &&
                            s.status != TeachingStatus.CANCELLED;
                        return StaffDatedCard(
                          date: Dates.dateOnly(Dates.localDay(s.startsAt, w.timeZone)),
                          title: title,
                          subtitle:
                              '${Dates.time(s.startsAt, w.timeZone)} – ${Dates.time(s.endsAt, w.timeZone)} · ${s.title}',
                          children: [
                            Wrap(
                              children: [
                                StatusChip(t('mentor.session.status.${status.name}'), tone: teachingTone(status)),
                              ],
                            ),
                            if (!row.readContext) ...[
                              const SizedBox(height: 8),
                              Text(t('mentor.classes.contextRestricted'), style: StaffText.caption),
                            ],
                            if (row.readContext && w.readReports && s.status == TeachingStatus.COMPLETED) ...[
                              const SizedBox(height: 8),
                              MentorSessionAttendanceTotals(classId: w.id, sessionId: s.id),
                            ],
                            if (row.readContext) ...[
                              const SizedBox(height: 8),
                              StaffButton(
                                label: t('mentor.operations.tools'),
                                outlined: true,
                                onPressed: () => showMentorSessionTools(context, ref, entry(row)),
                              ),
                            ],
                            if (todayAccessible && !w.readonly) ...[
                              const SizedBox(height: 12),
                              StaffButton(
                                label: t('mentor.session.attendance'),
                                outlined: true,
                                onPressed: () async {
                                  await showMentorAttendance(context, ref, entry(row));
                                  if (mounted) {
                                    _refresh();
                                  }
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
              ];
            },
          ),
        ),
      ),
    );
  }
}
