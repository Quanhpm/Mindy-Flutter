import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/class_detail_screens.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Sheet chọn lớp có ô tìm kiếm (dùng ở nhiều màn Quản lý).
class ClassPickerSheet extends ConsumerStatefulWidget {
  const ClassPickerSheet({super.key, required this.prefix, required this.onPick, required this.onClose});
  final String prefix;
  final ValueChanged<TeachingClass> onPick;
  final VoidCallback onClose;

  @override
  ConsumerState<ClassPickerSheet> createState() => _ClassPickerSheetState();
}

class _ClassPickerSheetState extends ConsumerState<ClassPickerSheet> {
  final _search = TextEditingController();
  static const _request = AttendanceRequest(kind: AttendanceKind.classes, role: TeachingRole.MANAGER, pageSize: 100, all: true);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final classes = ref.watch(attendanceQueryProvider(_request));
    final q = _search.text.toLowerCase();
    return MdyInlineSheet(
      key: Key('${widget.prefix}-class-sheet'),
      title: t(_a('class')),
      onClose: widget.onClose,
      children: [
        AttendanceField(
          id: '${widget.prefix}-class-search',
          label: t(_a('search')),
          controller: _search,
          multiline: false,
          onChanged: (_) => setState(() {}),
        ),
        AttendanceQueryBlock(
          query: classes,
          prefix: '${widget.prefix}-classes',
          controller: ref.read(attendanceQueryProvider(_request).notifier),
          builder: (_) => ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s8,
                children: [
                  for (final item in classes.data?.classes ?? const <TeachingClass>[])
                    if (item.name.toLowerCase().contains(q))
                      MdyButton(
                        key: Key('${widget.prefix}-class-${item.id}'),
                        variant: MdyButtonVariant.secondary,
                        label: item.name,
                        onPressed: () => widget.onPick(item),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Clone `IncompleteSessionsScreen.tsx`: buổi chưa hoàn tất, lọc theo vấn đề và lớp.
class StaffIncompleteSessionsScreen extends ConsumerStatefulWidget {
  const StaffIncompleteSessionsScreen({super.key});

  @override
  ConsumerState<StaffIncompleteSessionsScreen> createState() => _IncompleteState();
}

class _IncompleteState extends ConsumerState<StaffIncompleteSessionsScreen> {
  Issue? _issue;
  String? _classId;
  bool _pick = false;

  AttendanceRequest get _request => AttendanceRequest(
    kind: AttendanceKind.incomplete,
    role: TeachingRole.MANAGER,
    issue: _issue,
    classId: _classId,
  );
  static const _classesRequest =
      AttendanceRequest(kind: AttendanceKind.classes, role: TeachingRole.MANAGER, pageSize: 100, all: true);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(attendanceQueryProvider(_request));
    final controller = ref.read(attendanceQueryProvider(_request).notifier);
    final classes = ref.watch(attendanceQueryProvider(_classesRequest));
    String? className(String id) => classes.data?.classes.where((k) => k.id == id).firstOrNull?.name;
    final filtered = _issue != null || _classId != null;
    return AttendancePage(
      prefix: 'incomplete',
      title: t(_a('incomplete.title')),
      subtitle: query.data == null ? null : t(_a('incomplete.subtitle'), {'count': query.data!.total}),
      onBack: () => staffBack(context, manager: true),
      refresh: controller.refresh,
      onEnd: () {
        final d = query.data;
        if (d != null && d.incomplete.length < d.total && !query.busy && !query.footerError && !query.offline) {
          controller.more();
        }
      },
      overlays: [
        if (_pick)
          ClassPickerSheet(
            prefix: 'incomplete',
            onClose: () => setState(() => _pick = false),
            onPick: (k) => setState(() {
              _classId = k.id;
              _pick = false;
            }),
          ),
      ],
      children: [
        Text(t(_a('incomplete.info')), style: MdyType.size(12).copyWith(color: c.secondary)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: MdySpace.s8,
            children: [
              for (final value in const <Issue?>[null, Issue.OVERDUE_NOT_STARTED, Issue.STARTED_NOT_FINALIZED])
                StaffChoiceChip(
                  key: Key('incomplete-issue-${value?.name ?? 'all'}'),
                  label: t(value == null ? _a('all') : _a('issue.${value.name}')),
                  selected: _issue == value,
                  boldOff: false,
                  onTap: () => setState(() => _issue = value),
                ),
              MdyButton(
                key: const Key('incomplete-class'),
                variant: MdyButtonVariant.secondary,
                size: MdyButtonSize.sm,
                label: (_classId == null ? null : className(_classId!)) ?? t(_a('class')),
                onPressed: () => setState(() => _pick = true),
              ),
              if (_classId != null)
                MdyButton(
                  key: const Key('incomplete-class-clear'),
                  variant: MdyButtonVariant.text,
                  label: t(_a('close')),
                  onPressed: () => setState(() => _classId = null),
                ),
            ],
          ),
        ),
        AttendanceQueryBlock(
          query: query,
          prefix: 'incomplete',
          controller: controller,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s20,
            children: [
              for (final item in query.data?.incomplete ?? const <Incomplete>[])
                _IncompleteCard(item: item, name: className(item.session.classId)),
              if (query.data?.total == 0)
                Padding(
                  key: Key(filtered ? 'incomplete-empty-filter' : 'incomplete-empty'),
                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MdySpace.s12,
                    children: [
                      MdyText(t(filtered ? _a('incomplete.emptyFilter') : _a('incomplete.empty'))),
                      if (filtered)
                        MdyButton(
                          label: t(_a('incomplete.clearFilters')),
                          onPressed: () => setState(() {
                            _issue = null;
                            _classId = null;
                          }),
                        ),
                    ],
                  ),
                ),
              AttendanceMore(
                query: query,
                controller: controller,
                count: query.data?.incomplete.length ?? 0,
                prefix: 'incomplete',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncompleteCard extends ConsumerWidget {
  const _IncompleteCard({required this.item, required this.name});
  final Incomplete item;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final s = item.session;
    DateTime day(DateTime v) => DateTime.parse('${isoDate(v).split('/').reversed.join('-')}T00:00:00Z');
    final days = day(s.asOf).difference(day(s.endsAt)).inDays;
    return Semantics(
      button: true,
      child: MdyPressed(
        key: Key('incomplete-${item.id}'),
        onTap: () => context.push(Routes.managerSession(item.id, tab: 'attendance', classTitle: name)),
        builder: (context, _) => MdyCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(MdySpace.s16),
          gap: MdySpace.s8,
          children: [
            if (name != null) Text(name!, style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink)),
            MdyText(s.title),
            Text(
              '${isoDate(s.startsAt)} · ${isoTime(s.startsAt)}–${isoTime(s.endsAt)}',
              style: MdyType.size(13).copyWith(color: c.secondary),
            ),
            MdyChip(
              t(_a('issue.${item.issue.name}')),
              variant: item.issue == Issue.OVERDUE_NOT_STARTED ? MdyChipVariant.warning : MdyChipVariant.danger,
            ),
            Text(s.effectiveMentor ?? t(_a('mentorMissing')), style: MdyType.size(12).copyWith(color: c.secondary)),
            Text(
              days == 0 ? t(_a('today')) : t(_a('daysAgo'), {'count': days}),
              style: MdyType.size(12).copyWith(color: c.ink),
            ),
            if (item.deadlineExpired != null && s.editableUntil != null)
              Text(
                t(item.deadlineExpired! ? _a('deadlineExpired') : _a('expires'), {
                  'deadline': '${isoTime(s.editableUntil!)} ${isoDate(s.editableUntil!)}',
                }),
                style: MdyType.size(12).copyWith(color: c.secondary),
              ),
          ],
        ),
      ),
    );
  }
}
