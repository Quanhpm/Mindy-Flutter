import 'package:flutter/material.dart';
import '../reports/reports_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../../manager/operations/assignment_sheet.dart';
import 'class_detail_screens.dart';
import 'classes_screens.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';
import 'teaching_widgets.dart';

/// Route báo cáo chuyên cần của lớp (Quản lý). Module reports gán lại khi port xong.
String Function(String classId, String title) managerClassReportRoute =
    (classId, title) => StaffReportRoutes.klass(true, classId, title: title);

/// Clone `ManagerClassDetailScreen.tsx`: 3 tab Tổng quan / Lịch học / Học viên (tab đã mở giữ trạng thái).
class StaffManagerClassDetailScreen extends ConsumerStatefulWidget {
  const StaffManagerClassDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<StaffManagerClassDetailScreen> createState() =>
      _StaffManagerClassDetailScreenState();
}

class _StaffManagerClassDetailScreenState
    extends ConsumerState<StaffManagerClassDetailScreen> {
  String _tab = 'overview';
  final _visited = <String>{'overview'};

  TeachingRequest get _classRequest => TeachingRequest(
    kind: TeachingKind.klass,
    role: TeachingRole.MANAGER,
    classId: widget.classId,
  );
  TeachingRequest get _sessionsRequest => TeachingRequest(
    kind: TeachingKind.sessions,
    role: TeachingRole.MANAGER,
    classId: widget.classId,
  );
  TeachingRequest get _studentsRequest => TeachingRequest(
    kind: TeachingKind.students,
    role: TeachingRole.MANAGER,
    classId: widget.classId,
  );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final query = ref.watch(teachingQueryProvider(_classRequest));
    final item = query.data?.classInfo;
    final sessions = _visited.contains('schedule')
        ? ref.watch(teachingQueryProvider(_sessionsRequest))
        : null;
    final students = _visited.contains('students')
        ? ref.watch(teachingQueryProvider(_studentsRequest))
        : null;
    final active = switch (_tab) {
      'schedule' => _sessionsRequest,
      'students' => _studentsRequest,
      _ => null,
    };
    final activeState = switch (_tab) {
      'schedule' => sessions,
      'students' => students,
      _ => null,
    };
    return TeachingPage(
      prefix: 'manager-detail',
      reserveSubtitle: true,
      title: t('mdy.teaching.managerDetailTitle'),
      subtitle: item?.name,
      subtitleLoading: item == null && !query.loaded,
      failure: fatalOf(query),
      tabs: [
        (value: 'overview', label: t('mdy.teaching.tabOverview')),
        (value: 'schedule', label: t('mdy.teaching.managerSessions')),
        (value: 'students', label: t('mdy.teaching.tabStudents')),
      ],
      tab: _tab,
      onTab: (v) => setState(() {
        _tab = v;
        _visited.add(v);
      }),
      onBack: () => staffBack(context, manager: true),
      onRefresh: () async {
        await Future.wait([
          ref.read(teachingQueryProvider(_classRequest).notifier).refresh(),
          if (sessions != null)
            ref
                .read(teachingQueryProvider(_sessionsRequest).notifier)
                .refresh(),
          if (students != null)
            ref
                .read(teachingQueryProvider(_studentsRequest).notifier)
                .refresh(),
        ]);
      },
      onEndReached: () {
        final s = activeState;
        if (active != null &&
            s != null &&
            !s.busy &&
            !s.footerError &&
            s.hasMore) {
          ref.read(teachingQueryProvider(active).notifier).more();
        }
      },
      children: [
        Offstage(
          offstage: _tab != 'overview',
          child: QueryBlock(
            query: query,
            prefix: 'manager-detail',
            onRetry: ref
                .read(teachingQueryProvider(_classRequest).notifier)
                .refresh,
            builder: (context) => item == null
                ? const SizedBox.shrink()
                : _Overview(
                    item: item,
                    classId: widget.classId,
                    onReport: () => context.push(
                      managerClassReportRoute(widget.classId, item.name),
                    ),
                  ),
          ),
        ),
        if (sessions != null)
          Offstage(
            offstage: _tab != 'schedule',
            child: _Schedule(
              query: sessions,
              onRetry: ref
                  .read(teachingQueryProvider(_sessionsRequest).notifier)
                  .refresh,
              onMore: ref
                  .read(teachingQueryProvider(_sessionsRequest).notifier)
                  .more,
            ),
          ),
        if (students != null)
          Offstage(
            offstage: _tab != 'students',
            child: _Students(
              query: students,
              onRetry: ref
                  .read(teachingQueryProvider(_studentsRequest).notifier)
                  .refresh,
              onMore: ref
                  .read(teachingQueryProvider(_studentsRequest).notifier)
                  .more,
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.avatar = false,
  });
  final String label;
  final String value;
  final MdyIcons icon;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(MdySpace.s10),
        child: Row(
          spacing: MdySpace.s12,
          children: [
            if (avatar)
              MdyAvatar(name: value, size: 40)
            else
              Container(
                width: MdySpace.s40,
                height: MdySpace.s40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.tint2,
                  shape: BoxShape.circle,
                ),
                child: MdyIcon(icon, size: 20),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s3,
                children: [
                  Text(
                    label,
                    style: MdyType.size(12).copyWith(color: c.secondary),
                  ),
                  Text(
                    value,
                    style: MdyType.size(
                      14,
                      MdyType.w500,
                    ).copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.item,
    required this.classId,
    required this.onReport,
  });
  final TeachingClass item;
  final String classId;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        if (item.status == ClassStatus.CANCELLED)
          MdyAlert(
            t('mdy.teaching.managerCancelled'),
            key: const Key('manager-detail-cancelled'),
            warning: true,
          ),
        MdyCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(
            horizontal: MdySpace.s24,
            vertical: MdySpace.s16,
          ),
          gap: MdySpace.s14,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MdySpace.s8,
              runSpacing: MdySpace.s8,
              children: [
                TeachingStatusChip(
                  group: 'classStatus',
                  value: item.status.name,
                ),
                Text(
                  item.code,
                  style: MdyType.size(12).copyWith(color: c.secondary),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - MdySpace.s8) / 2;
                return Wrap(
                  spacing: MdySpace.s8,
                  runSpacing: MdySpace.s8,
                  children: [
                    for (final s in EnrollmentStatus.values)
                      Container(
                        width: w,
                        padding: const EdgeInsets.all(MdySpace.s10),
                        decoration: BoxDecoration(
                          color: c.muted,
                          borderRadius: BorderRadius.circular(MdyRadius.r14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.enrollmentCounts[s] ?? '—'}',
                              style: MdyType.size(
                                18,
                                MdyType.w700,
                              ).copyWith(color: c.ink),
                            ),
                            Text(
                              t(switch (s) {
                                EnrollmentStatus.PENDING_PAYMENT =>
                                  'mdy.teaching.held',
                                EnrollmentStatus.COMPLETED =>
                                  'mdy.teaching.done',
                                _ => 'mdy.teaching.enrollment.${s.name}',
                              }),
                              style: MdyType.size(
                                11,
                              ).copyWith(color: c.secondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        MdyButton(
          key: const Key('manager-class-assign-primary'),
          variant: MdyButtonVariant.secondary,
          label: t('manager.assignPrimary'),
          disabled: [
            ClassStatus.COMPLETED,
            ClassStatus.CANCELLED,
          ].contains(item.status),
          onPressed: () => showManagerAssignment(
            context,
            target: (id: classId, session: false),
            label: t('manager.assignPrimary'),
          ),
        ),
        TeachingGroup(t('mdy.teaching.classInfoHead')),
        MdyCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(
            horizontal: MdySpace.s16,
            vertical: MdySpace.s8,
          ),
          gap: 0,
          children: [
            _InfoRow(
              label: t('mdy.teaching.primary'),
              value: item.mentor ?? t('mdy.teaching.nameUnavailable'),
              icon: MdyIcons.person,
              avatar: true,
            ),
            _InfoRow(
              label: t('mdy.teaching.classPeriod'),
              value:
                  '${calendarDate(item.startDate)} – ${calendarDate(item.endDate)}',
              icon: MdyIcons.eventRepeat,
            ),
            _InfoRow(
              label: t('mdy.teaching.classFormat'),
              value: item.deliveryMode == null
                  ? '—'
                  : t('mdy.teaching.delivery.${item.deliveryMode!.name}'),
              icon: item.deliveryMode == DeliveryMode.ONLINE
                  ? MdyIcons.videocam
                  : MdyIcons.meetingRoom,
            ),
            _InfoRow(
              label: t('mdy.teaching.seatsLabel'),
              value: t('mdy.teaching.seats', {
                'available': item.availableSeats,
                'max': item.maxStudents,
              }),
              icon: MdyIcons.groups,
            ),
            _InfoRow(
              label: t('mdy.teaching.courseLabel'),
              value: item.course,
              icon: MdyIcons.menuBook,
            ),
            _InfoRow(
              label: t('mdy.teaching.syllabus'),
              value: t('mdy.teaching.countClass', {
                'units': item.unitCount,
                'sessions': item.sessionCount,
              }),
              icon: MdyIcons.menuBook,
            ),
            if (item.status != ClassStatus.DRAFT)
              Semantics(
                button: true,
                child: MdyPressed(
                  key: const Key('manager-detail-report'),
                  onTap: onReport,
                  builder: (context, pressed) => Opacity(
                    opacity: pressed ? .8 : 1,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: MdySpace.s44,
                      ),
                      padding: const EdgeInsets.all(MdySpace.s10),
                      child: Row(
                        spacing: MdySpace.s12,
                        children: [
                          Container(
                            width: MdySpace.s40,
                            height: MdySpace.s40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.tint2,
                              shape: BoxShape.circle,
                            ),
                            child: const MdyIcon(MdyIcons.monitoring, size: 20),
                          ),
                          Expanded(
                            child: Text(
                              t('mdy.reports.managerLink'),
                              style: MdyType.size(
                                14,
                                MdyType.w500,
                              ).copyWith(color: c.ink),
                            ),
                          ),
                          const MdyIcon(MdyIcons.chevronRight, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule({
    required this.query,
    required this.onRetry,
    required this.onMore,
  });
  final TeachingQueryState query;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final data = query.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        TeachingGroup(t('mdy.teaching.allSessions')),
        QueryBlock(
          query: query,
          prefix: 'manager-detail-sessions',
          onRetry: onRetry,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              MdyCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: MdySpace.s16,
                  vertical: MdySpace.s8,
                ),
                gap: 0,
                children: [
                  for (final s in data?.sessions ?? const <TeachingSession>[])
                    ManagerSessionRow(
                      item: s,
                      onPress: () => context.push(Routes.managerSession(s.id)),
                    ),
                  if (data == null || data.total == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MdySpace.s16,
                      ),
                      child: Text(
                        t('mdy.teaching.noClassSessions'),
                        style: MdyType.text.copyWith(color: c.ink),
                      ),
                    ),
                ],
              ),
              TeachingFooter(
                query: query,
                prefix: 'manager-detail-sessions',
                count: data?.sessions.length ?? 0,
                onMore: onMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Students extends ConsumerWidget {
  const _Students({
    required this.query,
    required this.onRetry,
    required this.onMore,
  });
  final TeachingQueryState query;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final data = query.data;
    return QueryBlock(
      query: query,
      prefix: 'manager-detail-students',
      onRetry: onRetry,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s20,
        children: [
          Semantics(
            header: true,
            child: Text(
              data == null
                  ? t('mdy.teaching.students')
                  : t('mdy.teaching.studentsHead', {'count': data.total}),
              style: MdyType.size(
                12,
                MdyType.w600,
              ).copyWith(color: c.secondary),
            ),
          ),
          MdyCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: MdySpace.s16,
              vertical: MdySpace.s8,
            ),
            gap: 0,
            children: [
              for (final s in data?.students ?? const <TeachingStudent>[])
                TeachingStudentRow(item: s, manager: true),
              if (data == null || data.total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s16),
                  child: Text(
                    t('mdy.teaching.emptyStudents'),
                    style: MdyType.text.copyWith(color: c.ink),
                  ),
                ),
            ],
          ),
          TeachingFooter(
            query: query,
            prefix: 'manager-detail-students',
            count: data?.students.length ?? 0,
            onMore: onMore,
          ),
        ],
      ),
    );
  }
}
