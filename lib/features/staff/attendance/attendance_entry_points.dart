import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Clone `EntryPoints.tsx` › `MentorAttendanceEntry`: số liệu buổi + Bắt đầu / Điểm danh / Ghi chú.
class MentorAttendanceEntry extends ConsumerWidget {
  const MentorAttendanceEntry({super.key, required this.item, this.studentTotal, this.roomAction});
  final TeachingSession item;
  final int? studentTotal;
  final Widget? roomAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.status == SessionStatus.CANCELLED) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final request = AttendanceRequest(kind: AttendanceKind.attendance, role: TeachingRole.MENTOR, sessionId: item.id, pageSize: 1);
    final query = ref.watch(attendanceQueryProvider(request));
    final session = query.data?.session;
    final scheduled = session?.status == SessionStatus.SCHEDULED;
    final permissions = session?.permissions;
    String value(String key) {
      if (session == null) return '—';
      if (scheduled) return key == 'students' && studentTotal != null ? '$studentTotal' : '—';
      final totals = query.data?.totals;
      if (totals == null) return '—';
      return '${key == 'students' ? totals.eligible : totals.of(key)}';
    }

    final attend = MdyButton(
      key: Key(permissions?.canEditAttendance ?? false ? 'session-attend' : 'session-attend-view'),
      size: MdyButtonSize.sm,
      label: t(
        permissions?.canEditAttendance ?? false
            ? (session?.status == SessionStatus.COMPLETED ? _a('context.edit') : _a('context.attend'))
            : _a('context.view'),
      ),
      onPressed: () => context.push(Routes.mentorAttendance(item.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s12,
      children: [
        Row(
          spacing: MdySpace.s8,
          children: [
            for (final key in const ['students', 'present', 'absent'])
              Expanded(
                child: Container(
                  key: Key('session-stat-$key'),
                  padding: const EdgeInsets.all(MdySpace.s10),
                  decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(MdyRadius.r14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s4,
                    children: [
                      Text(value(key), style: MdyType.size(18, MdyType.w700).copyWith(color: c.ink)),
                      Text(
                        t(key == 'students' ? _a('students') : _a('editor.$key')),
                        style: MdyType.size(11).copyWith(color: c.secondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (query.data == null && query.loaded) ...[
          MdyAlert(t(_a('context.totalsFailed')), key: const Key('session-totals-error'), warning: true),
          if (!query.offline)
            MdyButton(
              key: const Key('session-totals-retry'),
              variant: MdyButtonVariant.text,
              label: t(_a('retry')),
              onPressed: ref.read(attendanceQueryProvider(request).notifier).refresh,
            ),
        ],
        if (permissions != null)
          Wrap(
            spacing: MdySpace.s8,
            runSpacing: MdySpace.s8,
            children: [
              if (scheduled)
                permissions.canStart
                    ? _Flex(
                        child: MdyButton(
                          key: const Key('session-start'),
                          size: MdyButtonSize.sm,
                          label: t(_a('context.start')),
                          onPressed: () => context.push(Routes.mentorAttendance(item.id)),
                        ),
                      )
                    : MdyText(
                        t(_a('editor.startBefore'), {'date': isoDate(item.startsAt)}),
                        key: const Key('session-starts-note'),
                      )
              else
                _Flex(child: attend),
              if (roomAction != null) _Flex(child: roomAction!),
            ],
          ),
        if (permissions != null && !scheduled)
          MdyButton(
            key: const Key('session-note'),
            variant: MdyButtonVariant.secondary,
            size: MdyButtonSize.sm,
            label: t(_a('noteLink')),
            onPressed: () => context.push(Routes.mentorNotes(item.id)),
          ),
      ],
    );
  }
}

/// `flex-1 min-w-[140px] min-h-52`: nút chia đều hàng, tối thiểu 140.
class _Flex extends StatelessWidget {
  const _Flex({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: 140, maxWidth: w, minHeight: MdySpace.s52),
        child: SizedBox(width: w >= 296 ? (w - MdySpace.s8) / 2 : w, child: child),
      );
    },
  );
}

/// Clone `components/ManagerAttendancePanel.tsx`: tab Điểm danh (chỉ xem) của Quản lý.
class ManagerAttendancePanel extends ConsumerStatefulWidget {
  const ManagerAttendancePanel({super.key, required this.sessionId, required this.active});
  final String sessionId;
  final bool active;

  @override
  ConsumerState<ManagerAttendancePanel> createState() => _ManagerAttendancePanelState();
}

class _ManagerAttendancePanelState extends ConsumerState<ManagerAttendancePanel> {
  bool _visited = false;

  @override
  Widget build(BuildContext context) {
    if (widget.active) _visited = true;
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final summaryRequest = AttendanceRequest(
      kind: AttendanceKind.attendance,
      role: TeachingRole.MANAGER,
      sessionId: widget.sessionId,
      pageSize: 1,
    );
    final summary = ref.watch(attendanceQueryProvider(summaryRequest));
    final summaryController = ref.read(attendanceQueryProvider(summaryRequest).notifier);
    final session = summary.data?.session;
    final cancelledEmpty = session?.status == SessionStatus.CANCELLED && session?.actualStartedAt == null;
    final listRequest = AttendanceRequest(
      kind: session?.status == SessionStatus.SCHEDULED ? AttendanceKind.candidates : AttendanceKind.attendance,
      role: TeachingRole.MANAGER,
      sessionId: widget.sessionId,
    );
    final enabled = _visited && session != null && !cancelledEmpty;
    final list = enabled ? ref.watch(attendanceQueryProvider(listRequest)) : null;
    if (widget.active && cancelledEmpty) {
      return MdyText(t(_a('cancelledEmpty')), key: const Key('manager-att-empty'));
    }
    if (!widget.active || list == null) {
      return AttendanceQueryBlock(
        query: summary,
        prefix: 'manager-att',
        controller: summaryController,
        builder: (_) => const SizedBox.shrink(),
      );
    }
    final listController = ref.read(attendanceQueryProvider(listRequest).notifier);
    final scheduled = session!.status == SessionStatus.SCHEDULED;
    return AttendanceQueryBlock(
      query: summary,
      prefix: 'manager-att',
      controller: summaryController,
      builder: (_) => AttendanceQueryBlock(
        query: list,
        prefix: 'manager-att',
        controller: listController,
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s20,
          children: [
            if (scheduled) MdyAlert(t(_a('editor.provisional')), key: const Key('manager-att-provisional'), warning: true),
            if ((list.data?.totals?.pendingPaymentCount ?? 0) > 0)
              MdyText(t(_a('editor.pending'), {'count': list.data!.totals!.pendingPaymentCount})),
            Text(
              t(scheduled ? _a('editor.expected') : _a('editor.students'), {'count': list.data?.total ?? 0}),
              style: MdyType.size(12, MdyType.w600).copyWith(color: c.ink),
            ),
            MdyCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(MdySpace.s6),
              gap: 0,
              children: [
                for (final row in list.data?.rows ?? const <AttendanceRow>[])
                  AttendanceRowView(row: row, prefix: 'manager-att', provisional: scheduled, hideUnmarked: true),
                if (list.data?.total == 0)
                  MdyText(
                    t(scheduled ? _a('editor.previewEmpty') : _a('correction.empty')),
                    key: const Key('manager-att-empty'),
                  ),
              ],
            ),
            AttendanceMore(
              query: list,
              controller: listController,
              count: list.data?.rows.length ?? 0,
              prefix: 'manager-att',
            ),
          ],
        ),
      ),
    );
  }
}
