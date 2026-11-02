import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/classes_screens.dart';
import 'leave_query.dart';
import 'leave_service.dart';
import 'leave_widgets.dart';

/// Clone `leave/screens/ListScreens.tsx`.

/// Route chi tiết xếp học bù (kèm `classId` như params RN).
String makeupPlacementRoute(String conflictId, String classId) => Uri(
  path: Routes.managerMakeupDetail(conflictId),
  queryParameters: {'classId': classId},
).toString();

class LeaveCard extends ConsumerWidget {
  const LeaveCard({
    super.key,
    required this.item,
    required this.prefix,
    this.mentorName,
    this.onTap,
  });
  final LeaveRequest item;
  final String prefix;
  final String? mentorName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final period = t(lv(item.period.name));
    final meta =
        '${t(lv('leave.sessionCount'), {'count': item.itemCount})} · ${t(lv('leave.sentAt'), {'time': instantLabel(item.submittedAt)})}';
    final due = item.status == LeaveStatus.PENDING
        ? instantLabel(item.expiresAt)
        : null;
    final content = MdyCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MdySpace.s16),
      gap: MdySpace.s8,
      children: [
        if (mentorName != null)
          Row(
            spacing: MdySpace.s8,
            children: [
              MdyAvatar(name: mentorName!, size: 36),
              Flexible(
                child: Text(
                  mentorName!,
                  key: Key('$prefix-row-mentor-${item.id}'),
                  style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink),
                ),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MdySpace.s8,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s2,
                children: [
                  Text(
                    rangeLabel(item.fromDate, item.toDate),
                    style: MdyType.size(
                      15,
                      MdyType.w600,
                    ).copyWith(color: c.ink),
                  ),
                  Text(
                    period,
                    style: MdyType.size(13).copyWith(color: c.secondary),
                  ),
                ],
              ),
            ),
            LeaveStatusChip(
              key: Key('$prefix-row-status-${item.id}'),
              status: item.status.name,
            ),
          ],
        ),
        Text(
          item.reason,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MdyType.size(13).copyWith(color: c.ink),
        ),
        const LeaveDivider(),
        Text(meta, style: MdyType.size(12).copyWith(color: c.secondary)),
        if (due != null)
          LeaveDueLine(key: Key('$prefix-row-due-${item.id}'), time: due),
      ],
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: [
        ?mentorName,
        rangeLabel(item.fromDate, item.toDate),
        period,
        t(lv(item.status.name)),
        item.reason,
        meta,
        if (due != null) t(lv('leave.dueAt'), {'time': due}),
      ].join(', '),
      excludeSemantics: true,
      child: MdyPressed(
        key: Key('$prefix-row-${item.id}'),
        onTap: onTap,
        builder: (context, pressed) =>
            Opacity(opacity: pressed ? 0.8 : 1, child: content),
      ),
    );
  }
}

class ConflictCard extends ConsumerWidget {
  const ConflictCard({
    super.key,
    required this.item,
    required this.prefix,
    this.className,
    this.onTap,
  });
  final Conflict item;
  final String prefix;
  final String? className;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final mode = conflictMode(item);
    final sorted = [...item.intervals]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final name = item.studentName ?? t(lv('mentorMissing'));
    final content = MdyCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MdySpace.s16),
      gap: MdySpace.s8,
      children: [
        Row(
          spacing: MdySpace.s8,
          children: [
            MdyAvatar(name: name, size: 36),
            Expanded(
              child: Text(
                name,
                style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink),
              ),
            ),
            LeaveStatusChip(
              key: Key('$prefix-row-status-${item.id}'),
              status: mode,
            ),
          ],
        ),
        if (className != null)
          Text(
            className!,
            key: Key('$prefix-row-class-${item.id}'),
            style: MdyType.size(13).copyWith(color: c.secondary),
          ),
        Text(
          item.source.title,
          style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink),
        ),
        Text(
          slotLabel(item.source),
          style: MdyType.size(13).copyWith(color: c.secondary),
        ),
        if (sorted.isNotEmpty)
          Text(
            '${t(lv('makeup.conflicts.overlap'), {'time': slotLabel(sorted.first)})}'
            '${sorted.length > 1 ? ' · ${t(lv('makeup.conflicts.overlapMore'), {'count': sorted.length - 1})}' : ''}',
            key: Key('$prefix-row-overlap-${item.id}'),
            style: MdyType.size(13).copyWith(color: c.warning),
          ),
        if (mode == 'NEEDS_REASSIGNMENT')
          Text(
            t(lv('makeup.conflicts.reassignNote')),
            style: MdyType.size(13).copyWith(color: c.danger),
          ),
        if (mode == 'MAKEUP_ASSIGNED')
          Text(
            t(lv('makeup.conflicts.assignedNote')),
            style: MdyType.size(13).copyWith(color: c.secondary),
          ),
      ],
    );
    if (onTap == null || mode == 'RESOLVED') {
      return KeyedSubtree(key: Key('$prefix-row-${item.id}'), child: content);
    }
    return Semantics(
      button: true,
      child: MdyPressed(
        key: Key('$prefix-row-${item.id}'),
        onTap: onTap,
        builder: (context, pressed) =>
            Opacity(opacity: pressed ? 0.8 : 1, child: content),
      ),
    );
  }
}

/// `MentorLeaveListScreen` (manager: false) / `LeaveReviewQueueScreen` (manager: true).
class StaffLeaveListScreen extends ConsumerStatefulWidget {
  const StaffLeaveListScreen({super.key, required this.manager});
  final bool manager;

  @override
  ConsumerState<StaffLeaveListScreen> createState() => _LeaveListState();
}

class _LeaveListState extends ConsumerState<StaffLeaveListScreen> {
  late String _status = widget.manager ? 'PENDING' : 'ALL';
  String? _mentorId;
  bool _picker = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final manager = widget.manager;
    final prefix = manager ? 'leave-queue' : 'leave-list';
    final request = LeaveReadRequest(
      kind: LeaveKind.list,
      role: manager ? LeaveRole.MANAGER : LeaveRole.MENTOR,
      status: _status == 'ALL' ? null : _status,
      mentorId: _mentorId,
    );
    final query = ref.watch(leaveQueryProvider(request));
    final controller = ref.read(leaveQueryProvider(request).notifier);
    const mentorsRequest = LeaveReadRequest(
      kind: LeaveKind.mentors,
      role: LeaveRole.MANAGER,
      pageSize: 100,
    );
    final mentors = manager
        ? ref.watch(leaveQueryProvider(mentorsRequest))
        : null;
    final mentorsController = manager
        ? ref.read(leaveQueryProvider(mentorsRequest).notifier)
        : null;
    if (mentors != null && mentorsController != null) {
      drainLeaveOptions(mentors, mentorsController);
    }
    final filtered = manager
        ? _status != 'PENDING' || _mentorId != null
        : _status != 'ALL';
    void clear() => setState(() {
      _status = manager ? 'PENDING' : 'ALL';
      _mentorId = null;
    });
    final empty = query.data?.total == 0;
    String? mentorName(String id) =>
        mentors?.data?.options?.where((o) => o.id == id).firstOrNull?.name;
    Widget create() => MdyButton(
      key: const Key('leave-list-create'),
      icon: MdyIcons.add,
      label: t(lv('leave.list.create')),
      onPressed: () => context.push(Routes.mentorLeaveCreate),
    );

    return LeavePage(
      prefix: prefix,
      title: t(lv('leave.list.title')),
      subtitle: manager && query.data != null
          ? t(lv('leave.queue.subtitle'), {'count': query.data!.total})
          : null,
      onBack: () => staffBack(context, manager: manager),
      refresh: () async {
        await controller.refresh();
      },
      onEnd: () {
        if (!query.footerError) controller.more();
      },
      footer: !manager && !empty ? [create()] : null,
      onOverlayBack: () => setState(() => _picker = false),
      overlays: [
        if (_picker && mentors != null)
          LeavePickerSheet(
            prefix: prefix,
            mentor: true,
            options: mentors.data?.options,
            onPick: (id) => setState(() => _mentorId = id),
            onClose: () => setState(() => _picker = false),
            error: mentors.result?.kind == LeaveOutcomeKind.error,
            retry: mentorsController!.retry,
          ),
      ],
      children: [
        LeaveFilters(
          prefix: prefix,
          value: _status,
          options: [
            for (final v in [
              if (!manager) 'ALL',
              ...leaveStatuses.map((s) => s.name),
            ])
              (value: v, label: t(lv(v == 'ALL' ? 'all' : v))),
          ],
          onChange: (v) => setState(() => _status = v),
          trailing: [
            if (manager) ...[
              MdyButton(
                key: Key('$prefix-mentor-filter'),
                variant: MdyButtonVariant.secondary,
                label:
                    (_mentorId == null ? null : mentorName(_mentorId!)) ??
                    t(lv('leave.queue.mentor')),
                onPressed: () => setState(() => _picker = true),
              ),
              if (_mentorId != null)
                MdyButton(
                  key: Key('$prefix-mentor-clear'),
                  variant: MdyButtonVariant.text,
                  label: t(lv('close')),
                  onPressed: () => setState(() => _mentorId = null),
                ),
            ],
          ],
        ),
        LeaveQueryBlock(
          query: query,
          controller: controller,
          prefix: prefix,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s16,
            children: [
              for (final item in query.data?.requests ?? const <LeaveRequest>[])
                LeaveCard(
                  key: ValueKey(item.id),
                  item: item,
                  prefix: prefix,
                  mentorName: manager
                      ? (mentorName(item.mentorId) ?? t(lv('mentorMissing')))
                      : null,
                  onTap: () => context.push(
                    manager
                        ? Routes.managerLeave(item.id)
                        : Routes.mentorLeaveDetail(item.id),
                  ),
                ),
              if (empty)
                MdyCard(
                  key: Key('$prefix-${filtered ? 'empty-filter' : 'empty'}'),
                  margin: EdgeInsets.zero,
                  center: true,
                  children: [
                    if (!filtered) const MdyCircleIcon(MdyIcons.eventNote),
                    MdyText(
                      t(
                        lv(
                          filtered
                              ? (manager
                                    ? 'leave.queue.emptyFilter'
                                    : 'leave.list.emptyFilter')
                              : (manager
                                    ? 'leave.queue.emptyPending'
                                    : 'leave.list.empty'),
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (filtered)
                      MdyButton(
                        key: Key(
                          manager
                              ? 'leave-queue-clear-filters'
                              : 'leave-list-show-all',
                        ),
                        variant: MdyButtonVariant.text,
                        label: t(
                          lv(
                            manager
                                ? 'leave.queue.clear'
                                : 'leave.list.showAll',
                          ),
                        ),
                        onPressed: clear,
                      )
                    else if (!manager)
                      create(),
                  ],
                ),
              LeaveMore(query: query, controller: controller, prefix: prefix),
            ],
          ),
        ),
      ],
    );
  }
}

/// `MakeupConflictsScreen`: xung đột lịch học viên do mentor nghỉ.
class StaffMakeupConflictsScreen extends ConsumerStatefulWidget {
  const StaffMakeupConflictsScreen({super.key});

  @override
  ConsumerState<StaffMakeupConflictsScreen> createState() => _ConflictsState();
}

class _ConflictsState extends ConsumerState<StaffMakeupConflictsScreen> {
  static const _prefix = 'makeup-conflicts';
  static const _keys = {
    'ACTIVE': 'filterActive',
    'OPEN': 'filterOpen',
    'MAKEUP_ASSIGNED': 'filterAssigned',
    'RESOLVED': 'filterResolved',
  };
  String _status = 'ACTIVE';
  String? _classId;
  bool _picker = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final request = LeaveReadRequest(
      kind: LeaveKind.conflicts,
      role: LeaveRole.MANAGER,
      status: _status == 'ACTIVE' ? null : _status,
      classId: _classId,
    );
    final query = ref.watch(leaveQueryProvider(request));
    final controller = ref.read(leaveQueryProvider(request).notifier);
    const classesRequest = LeaveReadRequest(
      kind: LeaveKind.classes,
      role: LeaveRole.MANAGER,
      pageSize: 100,
    );
    final classes = ref.watch(leaveQueryProvider(classesRequest));
    final classesController = ref.read(
      leaveQueryProvider(classesRequest).notifier,
    );
    drainLeaveOptions(classes, classesController);
    String? className(String id) =>
        classes.data?.options?.where((o) => o.id == id).firstOrNull?.name;
    final filtered = _status != 'ACTIVE' || _classId != null;

    return LeavePage(
      prefix: _prefix,
      title: t(lv('makeup.conflicts.title')),
      subtitle: query.data == null
          ? null
          : t(lv('makeup.conflicts.subtitle'), {'count': query.data!.total}),
      onBack: () => staffBack(context, manager: true),
      refresh: () async {
        await controller.refresh();
      },
      onEnd: () {
        if (!query.footerError) controller.more();
      },
      onOverlayBack: () => setState(() => _picker = false),
      overlays: [
        if (_picker)
          LeavePickerSheet(
            prefix: _prefix,
            mentor: false,
            options: classes.data?.options,
            onPick: (id) => setState(() => _classId = id),
            onClose: () => setState(() => _picker = false),
            error: classes.result?.kind == LeaveOutcomeKind.error,
            retry: classesController.retry,
          ),
      ],
      children: [
        LeaveNotice(
          t(lv('makeup.conflicts.info')),
          key: const Key('$_prefix-info'),
        ),
        LeaveFilters(
          prefix: _prefix,
          value: _status,
          options: [
            for (final e in _keys.entries)
              (value: e.key, label: t(lv('makeup.conflicts.${e.value}'))),
          ],
          onChange: (v) => setState(() => _status = v),
          trailing: [
            MdyButton(
              key: const Key('$_prefix-class-filter'),
              variant: MdyButtonVariant.secondary,
              label:
                  (_classId == null ? null : className(_classId!)) ??
                  t(lv('makeup.conflicts.class')),
              onPressed: () => setState(() => _picker = true),
            ),
            if (_classId != null)
              MdyButton(
                key: const Key('$_prefix-class-clear'),
                variant: MdyButtonVariant.text,
                label: t(lv('close')),
                onPressed: () => setState(() => _classId = null),
              ),
          ],
        ),
        LeaveQueryBlock(
          query: query,
          controller: controller,
          prefix: _prefix,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s16,
            children: [
              for (final item in query.data?.conflicts ?? const <Conflict>[])
                ConflictCard(
                  key: ValueKey(item.id),
                  item: item,
                  prefix: _prefix,
                  className: className(item.source.classId),
                  onTap: () => context.push(
                    makeupPlacementRoute(item.id, item.source.classId),
                  ),
                ),
              if (query.data?.total == 0)
                MdyCard(
                  key: Key('$_prefix-${filtered ? 'empty-filter' : 'empty'}'),
                  margin: EdgeInsets.zero,
                  center: true,
                  children: [
                    MdyText(
                      t(
                        lv(
                          filtered
                              ? 'makeup.conflicts.emptyFilter'
                              : 'makeup.conflicts.empty',
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (filtered)
                      MdyButton(
                        key: const Key('$_prefix-clear-filters'),
                        variant: MdyButtonVariant.text,
                        label: t(lv('makeup.conflicts.clear')),
                        onPressed: () => setState(() {
                          _status = 'ACTIVE';
                          _classId = null;
                        }),
                      ),
                  ],
                ),
              LeaveMore(query: query, controller: controller, prefix: _prefix),
            ],
          ),
        ),
      ],
    );
  }
}
