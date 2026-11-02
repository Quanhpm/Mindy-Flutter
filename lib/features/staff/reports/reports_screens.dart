import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../chat/chat_entry_points.dart';
import '../shared/connectivity.dart';
import '../shared/remote.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';
import '../teaching/teaching_widgets.dart';
import 'reports_models.dart';
import 'reports_query.dart';
import 'reports_widgets.dart';

abstract final class StaffReportRoutes {
  static const mentorPath = '/mentor/reports/:classId';
  static const managerPath = '/manager/reports/class/:classId';
  static const studentPath = '/mentor/reports/:classId/student/:studentId';
  static String klass(bool manager, String id, {String? title}) => Uri(
    path: '/${manager ? 'manager/reports/class' : 'mentor/reports'}/$id',
    queryParameters: {'title': ?title},
  ).toString();
  static String student(
    String classId,
    String studentId, {
    String? title,
    String? name,
    String? tab,
    ReportRange? range,
  }) => Uri(
    path: '/mentor/reports/$classId/student/$studentId',
    queryParameters: {
      'title': ?title,
      'name': ?name,
      'tab': ?tab,
      'from': ?range?.from,
      'to': ?range?.to,
    },
  ).toString();
}

class StaffReportClassesScreen extends ConsumerStatefulWidget {
  const StaffReportClassesScreen({super.key});
  @override
  ConsumerState<StaffReportClassesScreen> createState() => _ClassesState();
}

class _ClassesState extends ConsumerState<StaffReportClassesScreen> {
  String _status = 'IN_PROGRESS';
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        r = TeachingRequest(
          kind: TeachingKind.classes,
          role: TeachingRole.MENTOR,
          status: _status,
        ),
        q = ref.watch(teachingQueryProvider(r)),
        controller = ref.read(teachingQueryProvider(r).notifier);
    return AttendancePage(
      prefix: 'report-classes',
      title: t(rp('mentor.title')),
      subtitle: t(rp('chooseClass')),
      onBack: () => staffBack(context),
      children: [
        TeachingFilters(
          prefix: 'report-classes',
          values: const ['IN_PROGRESS', 'OPEN', 'COMPLETED', 'CANCELLED'],
          value: _status,
          onChange: (v) => setState(() => _status = v),
        ),
        QueryBlock(
          query: q,
          prefix: 'report-classes',
          onRetry: controller.refresh,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s16,
            children: [
              for (final item in q.data?.classes ?? const <TeachingClass>[])
                if (item.scope == ClassScope.CLASS)
                  KeyedSubtree(
                    key: Key('report-class-${item.id}'),
                    child: MentorClassCard(
                      item: item,
                      onPress: () => context.push(
                        StaffReportRoutes.klass(
                          false,
                          item.id,
                          title: item.name,
                        ),
                      ),
                    ),
                  ),
              if (!(q.data?.classes.any((c) => c.scope == ClassScope.CLASS) ??
                      false) &&
                  !q.hasMore)
                MdyText(
                  t(rp('noClasses')),
                  key: const Key('report-classes-empty'),
                ),
              TeachingFooter(
                query: q,
                prefix: 'report-classes',
                count: q.data?.classes.length ?? 0,
                onMore: controller.more,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StaffReportScreen extends ConsumerStatefulWidget {
  const StaffReportScreen({
    super.key,
    required this.classId,
    this.manager = false,
    this.classTitle,
    this.studentId,
    this.studentName,
    this.initialTab,
    this.range,
  });
  final String classId;
  final bool manager;
  final String? classTitle, studentId, studentName, initialTab;
  final ReportRange? range;
  @override
  ConsumerState<StaffReportScreen> createState() => _ReportState();
}

class _ReportState extends ConsumerState<StaffReportScreen> {
  late String _tab =
      widget.initialTab ??
      (widget.studentId == null ? 'attendance' : 'history');
  late ReportRange? _range = widget.range;
  bool _rangeOpen = false, _meaning = false;
  String _from = '', _to = '', _editing = 'from';
  String? _rangeProblem;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        student = widget.studentId != null,
        progress = _tab == 'progress',
        prefix = widget.manager
            ? 'manager-report'
            : student
            ? 'student-report'
            : 'mentor-report';
    final kind = progress
        ? (student ? ReportKind.units : ReportKind.progress)
        : student
        ? ReportKind.history
        : ReportKind.attendance;
    final request = (
          kind: kind,
          manager: widget.manager,
          classId: widget.classId,
          studentId: widget.studentId,
          range: progress ? null : _range,
        ),
        q = ref.watch(reportQueryProvider(request)),
        controller = ref.read(reportQueryProvider(request).notifier);
    final summaryRequest = (
          kind: ReportKind.studentSummary,
          manager: false,
          classId: widget.classId,
          studentId: widget.studentId,
          range: _range,
        ),
        summary = student && !progress
            ? ref.watch(reportQueryProvider(summaryRequest))
            : null;
    final names = student && progress
        ? ref.watch(reportUnitNamesProvider(widget.classId)).value
        : null;
    final data = q.data,
        blocked =
            [
              RemoteFailure.denied,
              RemoteFailure.notFound,
            ].contains(q.error?.kind) ||
            [
              RemoteFailure.denied,
              RemoteFailure.notFound,
            ].contains(summary?.error?.kind);
    void openStudent(String id, String? name) => context.push(
      StaffReportRoutes.student(
        widget.classId,
        id,
        title: widget.classTitle,
        name: name,
        tab: progress ? 'progress' : null,
        range: progress ? null : _range,
      ),
    );
    Widget asOf(ReportData d) => MdyText(
      t(rp('asOf'), {'time': reportInstant(d.asOf, d.timeZone)}),
      key: Key('$prefix-as-of'),
    );
    return AttendancePage(
      prefix: prefix,
      title: widget.manager
          ? t(rp('manager.title'))
          : student
          ? widget.studentName ?? t(rp('mentor.student'))
          : t(rp('mentor.title')),
      subtitle: widget.classTitle,
      onBack: () => staffBack(context, manager: widget.manager),
      refresh: () async {
        await Future.wait([
          controller.refresh(),
          if (summary != null)
            ref.read(reportQueryProvider(summaryRequest).notifier).refresh(),
        ]);
      },
      tabs: widget.manager
          ? null
          : [
              (
                value: student ? 'history' : 'attendance',
                label: t(
                  rp(student ? 'mentor.tabHistory' : 'mentor.tabAttendance'),
                ),
              ),
              (value: 'progress', label: t(rp('mentor.tabProgress'))),
            ],
      tab: _tab,
      onTab: (v) => setState(() => _tab = v),
      overlays: [
        if (_meaning)
          MdyInlineSheet(
            key: Key('$prefix-meaning-sheet'),
            title: t(rp('meaning')),
            onClose: () => setState(() => _meaning = false),
            children: [
              for (final name in [
                'rate',
                'pending',
                'unmarked',
                'excluded',
                'makeup',
                'source',
              ]) ...[
                MdyText(t(rp('meaningItems.${name}Title'))),
                MdyText(t(rp('meaningItems.$name'))),
              ],
            ],
          ),
        if (_rangeOpen)
          MdyInlineSheet(
            key: Key('$prefix-range-sheet'),
            title: t(rp('pickRange')),
            onClose: () => setState(() => _rangeOpen = false),
            children: [
              Row(
                spacing: MdySpace.s12,
                children: [
                  for (final field in ['from', 'to'])
                    Expanded(
                      child: MdyButton(
                        key: Key('$prefix-range-$field'),
                        variant: _editing == field
                            ? MdyButtonVariant.primary
                            : MdyButtonVariant.secondary,
                        label:
                            '${t(rp(field))}: ${field == 'from' ? _from : _to}',
                        onPressed: () => setState(() => _editing = field),
                      ),
                    ),
                ],
              ),
              CalendarDatePicker(
                key: ValueKey(_editing),
                initialDate:
                    DateTime.tryParse(_editing == 'from' ? _from : _to) ??
                    DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(9999),
                onDateChanged: (d) => setState(() {
                  _rangeProblem = null;
                  if (_editing == 'from') {
                    _from = d.toIso8601String().substring(0, 10);
                    _editing = 'to';
                  } else {
                    _to = d.toIso8601String().substring(0, 10);
                  }
                }),
              ),
              MdyText(t(rp('rangeHint'))),
              if (_rangeProblem != null)
                MdyAlert(
                  t(rp(_rangeProblem == 'order' ? 'rangeOrder' : 'rangeMax')),
                  key: Key('$prefix-range-error'),
                ),
              MdyButton(
                key: Key('$prefix-range-apply'),
                label: t(rp('apply')),
                disabled: _from.isEmpty || _to.isEmpty,
                onPressed: () => setState(() {
                  final range = (from: _from, to: _to);
                  _rangeProblem = reportRangeProblem(range);
                  if (_rangeProblem == null) {
                    _range = range;
                    _rangeOpen = false;
                  }
                }),
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(rp('allTime')),
                onPressed: () => setState(() {
                  _range = null;
                  _rangeOpen = false;
                }),
              ),
            ],
          ),
      ],
      children: [
        if (student && !progress && !blocked)
          StaffMessageStudentButton(
            studentId: widget.studentId!,
            studentName: widget.studentName,
          ),
        if (!blocked && !progress)
          Wrap(
            spacing: MdySpace.s8,
            children: [
              MdyButton(
                key: Key('$prefix-range'),
                variant: MdyButtonVariant.secondary,
                label: _range == null
                    ? t(rp('allTime'))
                    : '${_range!.from.split('-').reversed.join('/')} – ${_range!.to.split('-').reversed.join('/')}',
                onPressed: () => setState(() {
                  _from = _range?.from ?? '';
                  _to = _range?.to ?? '';
                  _editing = 'from';
                  _rangeProblem = null;
                  _rangeOpen = true;
                }),
              ),
              if (_range != null)
                MdyButton(
                  key: Key('$prefix-range-clear'),
                  variant: MdyButtonVariant.text,
                  label: t(rp('allTime')),
                  onPressed: () => setState(() => _range = null),
                ),
              MdyButton(
                key: Key('$prefix-meaning'),
                variant: MdyButtonVariant.text,
                icon: MdyIcons.info,
                label: t(rp('meaning')),
                onPressed: () => setState(() => _meaning = true),
              ),
            ],
          ),
        if (blocked)
          MdyAlert(
            t(
              rp(
                (q.error ?? summary?.error)?.kind == RemoteFailure.denied
                    ? 'denied'
                    : 'notFound',
              ),
            ),
            key: Key(
              '$prefix-${(q.error ?? summary?.error)?.kind == RemoteFailure.denied ? 'denied' : 'not-found'}',
            ),
          )
        else ...[
          if (q.busy && data == null) const SkeletonList(count: 2),
          if (summary?.data?.summary case final counts?)
            MdyCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(MdySpace.s16),
              children: [
                ReportCountLines(counts: counts, prefix: prefix, large: true),
                asOf(summary!.data!),
              ],
            ),
          if (student && !progress)
            MdyText(t(rp('mentor.historyScope')), key: Key('$prefix-scope')),
          if (progress)
            MdyText(
              t(rp('mentor.progressNote')),
              key: Key('$prefix-progress-note'),
            ),
          if (data != null) ...[
            MdyText(
              t(
                rp(
                  progress && student
                      ? 'mentor.units'
                      : student
                      ? 'mentor.sessions'
                      : 'enrollments',
                ),
                {'count': data.total},
              ),
              key: Key('$prefix-count'),
            ),
            asOf(data),
            if (data.readonly || summary?.data?.readonly == true)
              MdyText(t(rp('mentor.readonly')), key: Key('$prefix-readonly')),
            if (data.total == 0) ...[
              MdyText(
                t(
                  rp(
                    progress && student
                        ? 'mentor.noUnits'
                        : student
                        ? _range == null
                              ? 'mentor.noSessionsAll'
                              : 'mentor.noSessions'
                        : 'empty',
                  ),
                ),
                key: Key('$prefix-empty'),
              ),
              if (student && _range != null && !progress)
                MdyButton(
                  key: Key('$prefix-view-all'),
                  variant: MdyButtonVariant.text,
                  label: t(rp('mentor.viewAll')),
                  onPressed: () => setState(() => _range = null),
                ),
            ],
            for (final row in data.enrollments)
              ReportSummaryRow(
                item: row,
                prefix: prefix,
                onTap: widget.manager
                    ? null
                    : () => openStudent(row.studentId, row.name),
              ),
            for (final row in data.progress)
              MdyPressed(
                key: Key('$prefix-progress-${row.id}'),
                onTap: () => openStudent(row.studentId, row.name),
                builder: (context, pressed) => MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s14),
                  children: [
                    Row(
                      spacing: MdySpace.s12,
                      children: [
                        MdyAvatar(name: row.name, size: 36),
                        Expanded(child: MdyText(row.name)),
                        const MdyIcon(MdyIcons.chevronRight),
                      ],
                    ),
                    MdyText(
                      [
                        if (row.stored > 0)
                          t(rp('mentor.stored'), {'count': row.stored}),
                        if (row.untracked > 0)
                          t(rp('mentor.untracked'), {'count': row.untracked}),
                      ].join(' · '),
                    ),
                    if (row.invalid > 0)
                      MdyAlert(
                        t(rp('mentor.invalidCount'), {'count': row.invalid}),
                        warning: true,
                      ),
                  ],
                ),
              ),
            for (final row in data.history)
              MdyPressed(
                key: Key('student-report-session-${row.sessionId}'),
                onTap: () => context.push(
                  Routes.mentorSession(
                    row.sessionId,
                    classTitle: widget.classTitle,
                  ),
                ),
                builder: (context, pressed) => MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s14),
                  gap: MdySpace.s6,
                  children: [
                    MdyText(row.title),
                    Row(
                      spacing: MdySpace.s8,
                      children: [
                        Expanded(
                          child: MdyText(
                            reportInstant(row.startsAt, data.timeZone),
                          ),
                        ),
                        TeachingStatusChip(
                          group: 'mentorSessionStatus',
                          value: row.status,
                        ),
                      ],
                    ),
                    if (row.attendance != null ||
                        row.applicability == 'ELIGIBLE')
                      MdyText(
                        t(rp('mentor.attendanceLine'), {
                          'status': t(rp('status.${row.attendance ?? 'none'}')),
                        }),
                        key: Key(
                          'student-report-session-${row.sessionId}-attendance',
                        ),
                      ),
                    if (row.credited != null)
                      MdyText(
                        t(rp('mentor.creditLine'), {
                          'status': t(rp('status.${row.credited}')),
                        }),
                        key: Key(
                          'student-report-session-${row.sessionId}-credit',
                        ),
                      ),
                    Wrap(
                      spacing: MdySpace.s8,
                      children: [
                        if (row.applicability != 'ELIGIBLE')
                          MdyChip(
                            t(rp('status.${row.applicability}')),
                            key: Key(
                              'student-report-session-${row.sessionId}-applicability',
                            ),
                            variant: row.applicability == 'MAKEUP_CREDITED'
                                ? MdyChipVariant.success
                                : [
                                    'MAKEUP_PENDING',
                                    'PAYMENT_PENDING',
                                  ].contains(row.applicability)
                                ? MdyChipVariant.warning
                                : MdyChipVariant.neutral,
                          ),
                        if (row.assignment == 'SUBSTITUTE')
                          MdyChip(
                            t(rp('mentor.substitute')),
                            variant: MdyChipVariant.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            for (final (index, row) in data.units.indexed)
              MdyCard(
                key: Key('student-report-unit-${row.unitId}'),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(MdySpace.s14),
                gap: MdySpace.s6,
                children: [
                  MdyText(
                    names?[row.unitId] ??
                        t(rp('mentor.unitFallback'), {'index': index + 1}),
                  ),
                  if (row.tracking == 'UNTRACKED')
                    MdyText(
                      t(rp('mentor.unitUntracked')),
                      key: Key('student-report-unit-${row.unitId}-percent'),
                    )
                  else ...[
                    if (row.status != null)
                      MdyChip(
                        t(rp('progressStatus.${row.status}')),
                        key: Key('student-report-unit-${row.unitId}-status'),
                        variant: row.status == 'COMPLETED'
                            ? MdyChipVariant.success
                            : row.status == 'IN_PROGRESS'
                            ? MdyChipVariant.info
                            : MdyChipVariant.neutral,
                      ),
                    if (row.quality == 'INVALID_PERCENT')
                      MdyAlert(t(rp('mentor.unitInvalid')), warning: true)
                    else
                      MdyText(
                        row.quality == 'VALID' && row.percent != null
                            ? '${t.locale.languageCode == 'vi' ? row.percent!.replaceAll('.', ',') : row.percent}%'
                            : t(rp('mentor.noPercent')),
                        key: Key('student-report-unit-${row.unitId}-percent'),
                      ),
                  ],
                  if (row.completedAt != null)
                    MdyText(
                      t(rp('mentor.completedAt'), {
                        'date': reportInstant(
                          row.completedAt!,
                          data.timeZone,
                        ).split(' ').last,
                      }),
                    ),
                ],
              ),
            if (data.count < data.total)
              MdyButton(
                key: Key('$prefix-more'),
                variant: MdyButtonVariant.text,
                label: t(rp('more')),
                busy: q.busy,
                disabled: q.busy || ref.watch(staffOfflineProvider),
                onPressed: controller.more,
              ),
          ],
          if (q.error != null) ...[
            MdyAlert(
              t(
                rp(
                  q.error!.offline
                      ? data == null
                            ? 'offlineEmpty'
                            : 'stale'
                      : 'error',
                ),
              ),
              warning: data != null,
              key: Key('$prefix-${q.error!.offline ? 'offline' : 'error'}'),
            ),
            if (!q.error!.offline)
              MdyButton(
                key: Key('$prefix-retry'),
                label: t(rp('retry')),
                onPressed: controller.refresh,
              ),
          ],
          if (summary?.error != null)
            MdyAlert(
              t(rp(summary!.error!.offline ? 'offlineEmpty' : 'error')),
              key: Key('$prefix-summary-error'),
            ),
        ],
      ],
    );
  }
}
