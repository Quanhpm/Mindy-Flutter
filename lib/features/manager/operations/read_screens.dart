import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/session/session_controller.dart';
import '../../mentor/schedule/schedule_models.dart';
import '../../my_classes/my_classes_models.dart';
import '../manager_api.dart';
import '../manager_models.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'assignment_sheet.dart';
import 'operations_providers.dart';

class ManagerPeopleScreen extends ConsumerStatefulWidget {
  const ManagerPeopleScreen({super.key, required this.role});
  final String role;
  @override
  ConsumerState<ManagerPeopleScreen> createState() => _PeopleState();
}

class _PeopleState extends ConsumerState<ManagerPeopleScreen> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerPeopleProvider((role: widget.role, search: _search));
    return StaffPage(
      title: t(widget.role == 'MENTOR' ? 'manager.utility.mentors' : 'manager.utility.students'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerSearch(onSearch: (v) => setState(() => _search = v)),
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) const ManagerEmpty(),
                for (final person in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () => context.push(Routes.managerPerson(widget.role, person.id)),
                      child: Row(
                        children: [
                          InitialsAvatar(name: person.name, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(person.name, style: StaffText.bodyStrong),
                                Text(person.email, style: StaffText.caption),
                                Text(
                                  t(person.active ? 'manager.active' : 'manager.suspended'),
                                  style: StaffText.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final managerMentorScheduleProvider = FutureProvider.autoDispose
    .family<({List<TeachingSession> items, String zone}), ({String id, String day, String zone})>((ref, q) {
      ref.watch(sessionEpochProvider);
      final c = CancelToken();
      ref.onDispose(c.cancel);
      final range = Dates.weekRange(q.day, q.zone);
      return ref.watch(managerApiProvider).mentorSchedule(q.id, range.from, range.to, cancel: c);
    });

class ManagerPersonScreen extends ConsumerStatefulWidget {
  const ManagerPersonScreen({super.key, required this.id, required this.role});
  final String id, role;
  @override
  ConsumerState<ManagerPersonScreen> createState() => _PersonState();
}

class _PersonState extends ConsumerState<ManagerPersonScreen> {
  String? _day;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerPersonProvider((role: widget.role, id: widget.id));
    return StaffPage(
      title: t(widget.role == 'MENTOR' ? 'manager.mentor' : 'manager.student'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (person) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: StaffText.title),
                SelectableText(person.email, style: StaffText.body),
                if (person.phone != null) SelectableText(person.phone!, style: StaffText.body),
                Text(t(person.active ? 'manager.active' : 'manager.suspended'), style: StaffText.caption),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(t('manager.relatedClasses'), style: StaffText.section),
          if (widget.role == 'MENTOR')
            ManagerData(
              value: ref.watch(managerClassesProvider((mentorId: widget.id, search: ''))),
              onRetry: () => ref.invalidate(managerClassesProvider((mentorId: widget.id, search: ''))),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final c in rows) ManagerClassTile(info: c),
                ],
              ),
            )
          else
            ManagerData(
              value: ref.watch(managerStudentClassesProvider(widget.id)),
              onRetry: () => ref.invalidate(managerStudentClassesProvider(widget.id)),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final c in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: GlassCard(
                        onTap: () => context.push(Routes.managerClass(c.classId)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: StaffText.bodyStrong),
                            Text(t('manager.enrollment.${c.enrollment.name}'), style: StaffText.caption),
                            Text(c.payment, style: StaffText.caption),
                            TextButton(
                              onPressed: () => context.push(Routes.managerOrder(c.orderId)),
                              child: Text(t('manager.orderDetail')),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.role == 'MENTOR') ...[
            const SizedBox(height: 20),
            Text(t('manager.teachingSchedule'), style: StaffText.section),
            ManagerData(
              value: ref.watch(managerZoneProvider),
              onRetry: () => ref.invalidate(managerZoneProvider),
              data: (zone) {
                final day = _day ?? Dates.localDay(DateTime.now(), zone),
                    p = managerMentorScheduleProvider((id: widget.id, day: day, zone: zone));
                return Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: t('manager.previousWeek'),
                          onPressed: () => setState(() => _day = Dates.shiftDay(day, -7)),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${Dates.dateOnly(Dates.weekDays(day).first)} – ${Dates.dateOnly(Dates.weekDays(day).last)}',
                            textAlign: TextAlign.center,
                            style: StaffText.body,
                          ),
                        ),
                        IconButton(
                          tooltip: t('manager.nextWeek'),
                          onPressed: () => setState(() => _day = Dates.shiftDay(day, 7)),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    ManagerData(
                      value: ref.watch(p),
                      onRetry: () => ref.invalidate(p),
                      data: (data) => Column(
                        children: [
                          if (data.items.isEmpty) const ManagerEmpty(),
                          for (final s in data.items) ManagerSessionTile(session: s),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class ManagerClassesScreen extends ConsumerStatefulWidget {
  const ManagerClassesScreen({super.key});
  @override
  ConsumerState<ManagerClassesScreen> createState() => _ClassesState();
}

class _ClassesState extends ConsumerState<ManagerClassesScreen> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerClassesProvider((mentorId: null, search: _search));
    return StaffPage(
      title: t('manager.utility.classes'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerSearch(onSearch: (s) => setState(() => _search = s)),
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) const ManagerEmpty(),
                for (final c in rows) ManagerClassTile(info: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerClassTile extends ConsumerWidget {
  const ManagerClassTile({super.key, required this.info});
  final ManagedClass info;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => context.push(Routes.managerClass(info.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.name, style: StaffText.bodyStrong),
            Text(info.code, style: StaffText.caption),
            StatusChip(t('manager.classStatus.${info.status.name}')),
            Text('${Dates.displayDay(info.start)} – ${Dates.displayDay(info.end)}', style: StaffText.body),
            if (info.mentor?.displayName != null) Text(info.mentor!.displayName!, style: StaffText.caption),
          ],
        ),
      ),
    );
  }
}

class ManagerClassScreen extends ConsumerWidget {
  const ManagerClassScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider),
        p = managerClassDetailProvider(id),
        tp = managerTimetableProvider(id),
        units = managerClassUnitsProvider(id);
    return StaffPage(
      title: t('manager.classDetail'),
      onBack: () => managerBack(context),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(p);
          ref.invalidate(tp);
          ref.invalidate(units);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(p),
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(d.info.name, style: StaffText.title),
                  Text(d.course, style: StaffText.body),
                  StatusChip(t('manager.classStatus.${d.info.status.name}')),
                  if (d.room != null) Text(d.room!, style: StaffText.body),
                  Text(
                    t('manager.classCounts', {'units': d.units, 'sessions': d.sessions, 'students': d.activeStudents}),
                    style: StaffText.caption,
                  ),
                  StaffButton(
                    label: t('manager.assignPrimary'),
                    onPressed: [ClassStatus.COMPLETED, ClassStatus.CANCELLED].contains(d.info.status)
                        ? null
                        : () => showManagerAssignment(
                            context,
                            target: (id: id, session: false),
                            label: t('manager.assignPrimary'),
                          ),
                  ),
                  TextButton(
                    onPressed: () => context.push('${Routes.managerReports}?classId=$id'),
                    child: Text(t('manager.utility.reports')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ManagerData(
              value: ref.watch(units),
              onRetry: () => ref.invalidate(units),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('manager.units'), style: StaffText.section),
                  for (final u in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${u.number}. ${u.title}', style: StaffText.body),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ManagerData(
              value: ref.watch(tp),
              onRetry: () => ref.invalidate(tp),
              data: (tt) => Column(
                children: [
                  if (tt.sessions.isEmpty) const ManagerEmpty(),
                  for (final s in tt.sessions) ManagerSessionTile(session: s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerSessionTile extends ConsumerWidget {
  const ManagerSessionTile({super.key, required this.session});
  final TeachingSession session;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), s = session;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: StaffText.bodyStrong),
            Text(
              '${Dates.instant(s.startsAt, s.timeZone)} – ${Dates.time(s.endsAt, s.timeZone)}',
              style: StaffText.body,
            ),
            StatusChip(t('manager.teachingStatus.${s.displayStatus(DateTime.now()).name}')),
            if (s.effectiveMentor?.displayName != null) Text(s.effectiveMentor!.displayName!, style: StaffText.caption),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: [TeachingStatus.CANCELLED, TeachingStatus.COMPLETED].contains(s.status)
                      ? null
                      : () => showManagerAssignment(
                          context,
                          target: (id: s.id, session: true),
                          label: t('manager.assignSubstitute'),
                          canClear: s.isSubstitute,
                        ),
                  child: Text(t('manager.assignSubstitute')),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.managerAudit(s.id)),
                  child: Text(t('manager.attendanceAudit')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerIncompleteScreen extends ConsumerStatefulWidget {
  const ManagerIncompleteScreen({super.key});
  @override
  ConsumerState<ManagerIncompleteScreen> createState() => _IncompleteState();
}

class _IncompleteState extends ConsumerState<ManagerIncompleteScreen> {
  String? _issue;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerIncompleteProvider((classId: null, issue: _issue));
    return StaffPage(
      title: t('manager.utility.incomplete'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          FilterChipsBar<String?>(
            items: [
              (null, t('manager.all')),
              ('OVERDUE_NOT_STARTED', t('manager.issue.OVERDUE_NOT_STARTED')),
              ('STARTED_NOT_FINALIZED', t('manager.issue.STARTED_NOT_FINALIZED')),
            ],
            selected: _issue,
            onSelected: (v) => setState(() => _issue = v),
          ),
          const SizedBox(height: 12),
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) const ManagerEmpty(),
                for (final r in rows)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('manager.issue.${r.issue}'), style: StaffText.bodyStrong),
                      if (r.expired == true) Text(t('manager.editWindowExpired'), style: StaffText.caption),
                      ManagerSessionTile(session: r.session),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerReportScreen extends ConsumerStatefulWidget {
  const ManagerReportScreen({super.key, this.classId});
  final String? classId;
  @override
  ConsumerState<ManagerReportScreen> createState() => _ReportState();
}

class _ReportState extends ConsumerState<ManagerReportScreen> {
  late String? _classId = widget.classId;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), cp = managerClassesProvider((mentorId: null, search: ''));
    return StaffPage(
      title: t('manager.utility.reports'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: ref.watch(cp),
            onRetry: () => ref.invalidate(cp),
            data: (rows) => DropdownButton<String>(
              value: _classId,
              isExpanded: true,
              hint: Text(t('manager.chooseClass')),
              items: [
                for (final c in rows)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _classId = v),
            ),
          ),
          if (_classId != null)
            ManagerData(
              value: ref.watch(managerReportProvider(_classId!)),
              onRetry: () => ref.invalidate(managerReportProvider(_classId!)),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.student.displayName ?? t('manager.student'), style: StaffText.bodyStrong),
                            Text(
                              t('manager.attendanceCounts', {
                                'present': r.present,
                                'absent': r.absent,
                                'unmarked': r.unmarked,
                                'excluded': r.excluded,
                                'pending': r.pending,
                              }),
                              style: StaffText.body,
                            ),
                            Text(formatPercent(r.rate, t.locale.languageCode), style: StaffText.title),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ManagerAuditScreen extends ConsumerWidget {
  const ManagerAuditScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), p = managerAuditsProvider(sessionId), zone = ref.watch(managerZoneProvider);
    return StaffPage(
      title: t('manager.attendanceAudit'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: zone,
            onRetry: () => ref.invalidate(managerZoneProvider),
            data: (z) => ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(p),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.actor.displayName ?? t('manager.mentor'), style: StaffText.bodyStrong),
                            Text(Dates.instant(r.at, z), style: StaffText.caption),
                            Text(
                              '${r.oldStatus == null ? '—' : t('manager.attendanceStatus.${r.oldStatus}')} → ${t('manager.attendanceStatus.${r.newStatus}')} · ${t('manager.auditAction.${r.action}')}',
                              style: StaffText.body,
                            ),
                            if (r.reason != null) Text(r.reason!, style: StaffText.body),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
