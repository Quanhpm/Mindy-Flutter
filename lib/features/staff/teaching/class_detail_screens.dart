import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import 'classes_screens.dart';
import 'teaching_format.dart';
import 'teaching_models.dart';
import 'teaching_query.dart';
import 'teaching_widgets.dart';

RemoteFailure? fatalOf(TeachingQueryState q) =>
    q.fatal && q.error!.kind != RemoteFailure.unavailable
    ? q.error!.kind
    : null;

Future<void> openMeeting(WidgetRef ref, String url, String failedKey) async {
  try {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) throw StateError('launch');
  } catch (_) {
    ref.read(mdyToastProvider.notifier).show(ref.read(trProvider)(failedKey));
  }
}

/// Clone `MentorClassDetailScreen.tsx`.
class StaffMentorClassDetailScreen extends ConsumerWidget {
  const StaffMentorClassDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final request = TeachingRequest(
      kind: TeachingKind.klass,
      role: TeachingRole.MENTOR,
      classId: classId,
    );
    final query = ref.watch(teachingQueryProvider(request));
    final item = query.data?.classInfo;
    final sessionsRequest = TeachingRequest(
      kind: TeachingKind.sessions,
      role: TeachingRole.MENTOR,
      classId: classId,
      pageSize: 100,
    );
    final sessions = item != null && item.status != ClassStatus.DRAFT
        ? ref.watch(teachingQueryProvider(sessionsRequest))
        : null;
    final list = [...?sessions?.data?.sessions];
    final now = DateTime.now();
    list.sort((a, b) {
      final p =
          (a.status == SessionStatus.IN_PROGRESS ? 0 : 1) -
          (b.status == SessionStatus.IN_PROGRESS ? 0 : 1);
      return p != 0 ? p : a.startsAt.compareTo(b.startsAt);
    });
    final next = list
        .where(
          (s) =>
              s.readSessionContext &&
              (s.status == SessionStatus.IN_PROGRESS ||
                  (s.status == SessionStatus.SCHEDULED &&
                      s.endsAt.isAfter(now))),
        )
        .firstOrNull;
    final closedStatus =
        item != null &&
        const [
          ClassStatus.COMPLETED,
          ClassStatus.CANCELLED,
        ].contains(item.status);
    final contextQuery =
        next != null &&
            item != null &&
            !closedStatus &&
            item.status != ClassStatus.DRAFT
        ? ref.watch(
            teachingQueryProvider(
              TeachingRequest(
                kind: TeachingKind.context,
                role: TeachingRole.MENTOR,
                sessionId: next.id,
              ),
            ),
          )
        : null;
    final ctx = contextQuery?.data?.session;
    final current = ctx != null && ctx.id == next?.id && ctx.classId == classId
        ? ctx
        : null;
    final link = closedStatus ? null : safeMeetingLink(current?.meetingUrl);
    final controller = ref.read(teachingQueryProvider(request).notifier);

    return TeachingPage(
      prefix: 'class-detail',
      reserveSubtitle: true,
      title: item?.name ?? t('mdy.teaching.classTitle'),
      subtitle: item?.code,
      subtitleLoading: item == null && !query.loaded,
      failure: fatalOf(query),
      deniedTitle: t('mdy.teaching.classDenied'),
      deniedBody: t('mdy.teaching.classDeniedBody'),
      onBack: () => staffBack(context),
      onRefresh: () async {
        await Future.wait([
          controller.refresh(),
          if (sessions != null)
            ref.read(teachingQueryProvider(sessionsRequest).notifier).refresh(),
        ]);
      },
      onEndReached: () {
        if (sessions != null &&
            !sessions.busy &&
            !sessions.footerError &&
            sessions.hasMore) {
          ref.read(teachingQueryProvider(sessionsRequest).notifier).more();
        }
      },
      children: [
        QueryBlock(
          query: query,
          prefix: 'class-detail',
          onRetry: controller.refresh,
          builder: (context) => item == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: MdySpace.s20,
                  children: [
                    MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdySpace.s24,
                        vertical: MdySpace.s16,
                      ),
                      gap: MdySpace.s14,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: MdySpace.s12,
                          children: [
                            Expanded(
                              child: Text(
                                item.course,
                                style: MdyType.size(
                                  17,
                                  MdyType.w600,
                                ).copyWith(color: c.ink),
                              ),
                            ),
                            TeachingStatusChip(
                              group: 'mentorClassStatus',
                              value: item.status.name,
                            ),
                          ],
                        ),
                        if (item.scope == ClassScope.SESSION)
                          const TeachingStatusChip(
                            group: 'scope',
                            value: 'SESSION',
                          ),
                        if ((current?.room ?? '').isNotEmpty)
                          _Fact(
                            icon: MdyIcons.locationOn,
                            text: current!.room!,
                          ),
                        Row(
                          spacing: MdySpace.s12,
                          children: [
                            Expanded(
                              child: _Fact(
                                icon: MdyIcons.menuBook,
                                text: t(
                                  item.scope == ClassScope.CLASS
                                      ? 'mdy.teaching.countClass'
                                      : 'mdy.teaching.countSession',
                                  {
                                    'units': item.unitCount,
                                    'sessions': item.sessionCount,
                                  },
                                ),
                              ),
                            ),
                            if (item.readClassRoster)
                              Semantics(
                                button: true,
                                child: MdyPressed(
                                  key: const Key('class-detail-students'),
                                  onTap: () => context.push(
                                    Routes.mentorStudents(classId),
                                  ),
                                  builder: (context, _) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: MdySpace.s6,
                                    children: [
                                      const MdyIcon(MdyIcons.groups, size: 16),
                                      Text(
                                        t('mdy.teaching.students'),
                                        style: MdyType.size(
                                          13,
                                          MdyType.w600,
                                        ).copyWith(color: c.link),
                                      ),
                                      const MdyIcon(
                                        MdyIcons.chevronRight,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (link != null)
                          MdyButton(
                            key: const Key('class-detail-enter'),
                            size: MdyButtonSize.sm,
                            icon: MdyIcons.videocam,
                            semanticLabel: t('mdy.teaching.linkHint'),
                            label: t('mdy.teaching.enterClass'),
                            onPressed: () => openMeeting(
                              ref,
                              link.url,
                              'mdy.teaching.linkFailed',
                            ),
                          ),
                      ],
                    ),
                    if (item.scope == ClassScope.SESSION)
                      MdyAlert(
                        t('mdy.teaching.scopeAlert'),
                        key: const Key('class-detail-scope'),
                        warning: true,
                      ),
                    if (closedStatus)
                      MdyAlert(
                        t(
                          item.status == ClassStatus.CANCELLED
                              ? 'mdy.teaching.cancelledAlert'
                              : 'mdy.teaching.completedAlert',
                        ),
                        key: const Key('class-detail-closed'),
                        warning: item.status == ClassStatus.CANCELLED,
                      ),
                    if (sessions != null)
                      _MentorSessions(
                        classInfo: item,
                        query: sessions,
                        onRetry: ref
                            .read(
                              teachingQueryProvider(sessionsRequest).notifier,
                            )
                            .refresh,
                        onMore: ref
                            .read(
                              teachingQueryProvider(sessionsRequest).notifier,
                            )
                            .more,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final MdyIcons icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: MdySpace.s6,
    children: [
      MdyIcon(icon, size: 16),
      Flexible(
        child: Text(
          text,
          style: MdyType.size(13).copyWith(color: context.mdy.secondary),
        ),
      ),
    ],
  );
}

/// Chip chọn kiểu radio (min-h 44, bo tròn) dùng ở nhiều màn.
class StaffChoiceChip extends StatelessWidget {
  const StaffChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.boldOff = true,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool boldOff;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: MdyPressed(
        onTap: onTap,
        builder: (context, _) => Container(
          constraints: const BoxConstraints(minHeight: MdySpace.s44),
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            border: selected ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(MdyRadius.r99),
          ),
          child: Text(
            label,
            style: MdyType.size(
              13,
              selected || boldOff ? MdyType.w600 : MdyType.w400,
            ).copyWith(color: selected ? c.onBrand : c.link),
          ),
        ),
      ),
    );
  }
}

class _MentorSessions extends ConsumerStatefulWidget {
  const _MentorSessions({
    required this.classInfo,
    required this.query,
    required this.onRetry,
    required this.onMore,
  });
  final TeachingClass classInfo;
  final TeachingQueryState query;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  ConsumerState<_MentorSessions> createState() => _MentorSessionsState();
}

class _MentorSessionsState extends ConsumerState<_MentorSessions> {
  late String _tab =
      const [
        ClassStatus.COMPLETED,
        ClassStatus.CANCELLED,
      ].contains(widget.classInfo.status)
      ? 'done'
      : 'upcoming';

  static bool _done(SessionStatus s) =>
      s == SessionStatus.COMPLETED || s == SessionStatus.CANCELLED;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final list = widget.query.data?.sessions ?? const <TeachingSession>[];
    final upcoming = list.where((s) => !_done(s.status)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final done = list.where((s) => _done(s.status)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final shown = _tab == 'upcoming' ? upcoming : done;
    final taught = done
        .where((s) => s.status == SessionStatus.COMPLETED)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: MdySpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t('mdy.teaching.sessionsHeading'),
                    style: MdyType.size(
                      17,
                      MdyType.w600,
                    ).copyWith(color: c.ink),
                  ),
                ),
              ),
              Text(
                t('mdy.teaching.sessionsDone', {
                  'done': taught,
                  'total': widget.classInfo.sessionCount,
                }),
                style: MdyType.size(13).copyWith(color: c.secondary),
              ),
            ],
          ),
        ),
        Row(
          spacing: MdySpace.s8,
          children: [
            StaffChoiceChip(
              key: const Key('class-detail-tab-upcoming'),
              label: t('mdy.teaching.tabUpcoming', {'count': upcoming.length}),
              selected: _tab == 'upcoming',
              onTap: () => setState(() => _tab = 'upcoming'),
            ),
            StaffChoiceChip(
              key: const Key('class-detail-tab-done'),
              label: t('mdy.teaching.tabDone', {'count': done.length}),
              selected: _tab == 'done',
              onTap: () => setState(() => _tab = 'done'),
            ),
          ],
        ),
        QueryBlock(
          query: widget.query,
          prefix: 'class-detail-sessions',
          onRetry: widget.onRetry,
          builder: (context) => MdyCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(MdySpace.s6),
            gap: 0,
            children: [
              for (final s in shown)
                MentorSessionRow(
                  item: s,
                  onPress: () => context.push(Routes.mentorSession(s.id)),
                ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s24),
                  child: Text(
                    t('mdy.teaching.noSessionsTab'),
                    textAlign: TextAlign.center,
                    style: MdyType.size(14).copyWith(color: c.tertiary),
                  ),
                ),
              TeachingFooter(
                query: widget.query,
                prefix: 'class-detail-sessions',
                count: list.length,
                label: t('mdy.teaching.moreSessions'),
                onMore: widget.onMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const orderFilters = ['', 'PAID', 'PENDING', 'EXPIRED', 'CANCELLED'];

/// Clone `MentorStudentsScreen.tsx`.
class StaffMentorStudentsScreen extends ConsumerWidget {
  const StaffMentorStudentsScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final probe = ref.watch(
      teachingQueryProvider(
        TeachingRequest(
          kind: TeachingKind.students,
          role: TeachingRole.MENTOR,
          classId: classId,
          status: '',
        ),
      ),
    );
    return TeachingPage(
      prefix: 'students',
      title: t('mdy.teaching.students'),
      failure: fatalOf(probe),
      deniedTitle: t('mdy.teaching.studentsDenied'),
      deniedBody: t('mdy.teaching.studentsDeniedBody'),
      onBack: () => staffBack(context),
      children: [StaffRoster(classId: classId, role: TeachingRole.MENTOR)],
    );
  }
}

/// `Roster`: danh sách học viên có lọc trạng thái đơn (dùng cho Mentor và chi tiết lớp Quản lý).
class StaffRoster extends ConsumerStatefulWidget {
  const StaffRoster({
    super.key,
    required this.classId,
    required this.role,
    this.className = '',
  });
  final String classId;
  final TeachingRole role;
  final String className;

  @override
  ConsumerState<StaffRoster> createState() => _StaffRosterState();
}

class _StaffRosterState extends ConsumerState<StaffRoster> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final manager = widget.role == TeachingRole.MANAGER;
    final request = TeachingRequest(
      kind: TeachingKind.students,
      role: widget.role,
      classId: widget.classId,
      status: _status.isEmpty ? null : _status,
    );
    // Trạng thái rỗng dùng chung cache với probe của màn (status: '').
    final effective = _status.isEmpty
        ? TeachingRequest(
            kind: TeachingKind.students,
            role: widget.role,
            classId: widget.classId,
            status: '',
          )
        : request;
    final query = ref.watch(teachingQueryProvider(effective));
    final controller = ref.read(teachingQueryProvider(effective).notifier);
    final prefix = manager ? 'manager-detail' : 'students';
    final data = query.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s24,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 21),
          child: data == null && !query.loaded
              ? MdySkeleton(
                  label: t('mdy.teaching.loading'),
                  child: MdyText(t('mdy.teaching.students'), maxLines: 1),
                )
              : MdyText(
                  data == null
                      ? ''
                      : '${data.classInfo?.name ?? widget.className} · ${data.total}',
                  key: Key(
                    manager
                        ? 'manager-detail-students-count'
                        : 'students-subtitle',
                  ),
                  maxLines: 1,
                ),
        ),
        TeachingFilters(
          prefix: prefix,
          values: orderFilters,
          value: _status,
          group: 'order',
          onChange: (v) => setState(() => _status = v),
        ),
        QueryBlock(
          query: query,
          prefix: manager ? 'manager-detail-students' : 'students',
          onRetry: controller.refresh,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              for (final s in data?.students ?? const <TeachingStudent>[])
                TeachingStudentRow(item: s, manager: manager),
              if (data == null || data.total == 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: MdySpace.s12,
                  children: [
                    MdyText(
                      t(
                        _status.isNotEmpty
                            ? 'mdy.teaching.emptyStudentsFilter'
                            : 'mdy.teaching.emptyStudents',
                      ),
                    ),
                    if (_status.isNotEmpty)
                      MdyButton(
                        variant: MdyButtonVariant.text,
                        label: t('mdy.teaching.showAll'),
                        onPressed: () => setState(() => _status = ''),
                      ),
                  ],
                ),
              TeachingFooter(
                query: query,
                prefix: prefix,
                count: data?.students.length ?? 0,
                onMore: controller.more,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
