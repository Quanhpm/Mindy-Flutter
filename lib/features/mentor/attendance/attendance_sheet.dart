import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/ui/pressable.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import '../schedule/schedule_models.dart';
import '../schedule/schedule_providers.dart';
import 'attendance_controller.dart';
import 'attendance_models.dart';
import 'finalize_sheet.dart';
import 'sync_roster_sheet.dart';

Future<void> showMentorAttendance(
  BuildContext context,
  WidgetRef ref,
  TeachingEntry entry, {
  bool openSync = false,
}) async {
  final t = ref.read(trProvider);
  await showStaffSheet<void>(
    context,
    title: t('mentor.attendance.title'),
    subtitle: '${entry.className} · ${entry.session.title}',
    builder: (_) => AttendanceSheetContent(sessionId: entry.session.id, openSync: openSync),
  );
}

class AttendanceSheetContent extends ConsumerStatefulWidget {
  const AttendanceSheetContent({super.key, required this.sessionId, this.openSync = false});
  final String sessionId;
  final bool openSync;
  @override
  ConsumerState<AttendanceSheetContent> createState() => _AttendanceSheetContentState();
}

class _AttendanceSheetContentState extends ConsumerState<AttendanceSheetContent> {
  bool _allowPop = false, _confirmingLeave = false, _openedSync = false;
  AttendanceController get _controller => ref.read(attendanceEditorProvider(widget.sessionId).notifier);

  Future<void> _action(Future<bool> Function() command, String messageKey, {bool sync = false}) async {
    final t = ref.read(trProvider);
    final success = await command();
    if (!mounted || !success) return;
    final count = ref.read(attendanceEditorProvider(widget.sessionId)).value?.changedCount ?? 0;
    showStaffToast(context, t(messageKey, sync ? {'count': count} : const {}));
  }

  Future<void> _sync(AttendanceEditorState editor) async {
    final t = ref.read(trProvider);
    final confirmed = await showStaffSheet<bool>(
      context,
      title: t('mentor.attendance.sync'),
      builder: (context) => SyncRosterContent(
        pendingPaymentCount: editor.roster.pendingPaymentCount,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _action(_controller.sync, 'mentor.attendance.synced', sync: true);
  }

  Future<void> _finalize(AttendanceEditorState editor) async {
    final t = ref.read(trProvider);
    final confirmed = await showStaffSheet<bool>(
      context,
      title: t('mentor.attendance.finalize'),
      builder: (context) => FinalizeAttendanceContent(
        totals: editor.roster.header.totals,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _action(_controller.finalize, 'mentor.attendance.finalized');
  }

  Future<void> _bulk(AttendanceEditorState editor) async {
    final t = ref.read(trProvider);
    final confirmed = await showStaffSheet<bool>(
      context,
      title: t('mentor.attendance.bulk'),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('mentor.attendance.bulkDescription', {'count': editor.roster.header.totals.eligible}),
            style: StaffText.body,
          ),
          const SizedBox(height: 20),
          StaffButton(label: t('mentor.attendance.bulkConfirm'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _action(_controller.bulkPresent, 'mentor.attendance.saved');
  }

  Future<void> _leave(AttendanceEditorState? editor) async {
    if (_confirmingLeave || editor == null) return;
    final t = ref.read(trProvider);
    if (editor.busy) {
      showStaffToast(context, t('mentor.attendance.wait'));
      return;
    }
    _confirmingLeave = true;
    final confirmed = await showStaffSheet<bool>(
      context,
      title: t('mentor.attendance.leaveTitle'),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t(editor.retryPending ? 'mentor.attendance.leavePending' : 'mentor.attendance.leaveDraft'),
            style: StaffText.body,
          ),
          const SizedBox(height: 20),
          StaffButton(label: t('mentor.attendance.stay'), onPressed: () => Navigator.of(context).pop(false)),
          const SizedBox(height: 8),
          StaffButton(
            label: t(editor.retryPending ? 'mentor.attendance.leaveLater' : 'mentor.attendance.discardLeave'),
            outlined: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirmingLeave = false;
    if (confirmed != true) return;
    if (!editor.retryPending) _controller.discardDraft();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final provider = attendanceEditorProvider(widget.sessionId);
    final value = ref.watch(provider);
    final editor = value.isLoading || value.hasError ? null : value.value;
    ref.listen(provider, (_, next) {
      if (next.isLoading) return;
      final error = next.error ?? next.value?.error;
      if (error is ApiError &&
          (error.status == 403 || (error.status == 404 && error.code == 'CLASS_SESSION_NOT_FOUND'))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.invalidate(mentorScheduleProvider);
          showStaffToast(context, t(attendanceErrorKey(error)));
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        });
      }
    });
    if (widget.openSync && !_openedSync && editor != null) {
      _openedSync = true;
      if (editor.roster.header.permissions.canSync && !editor.dirty && !editor.locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sync(editor);
        });
      }
    }
    return PopScope(
      canPop: _allowPop || (editor?.busy != true && editor?.dirty != true && editor?.retryPending != true),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(editor);
      },
      child: value.when(
        skipLoadingOnRefresh: false,
        loading: () => const Skeleton(height: 320),
        error: (error, _) => StaffDataState(
          title: t('mentor.attendance.loadError'),
          description: t(attendanceErrorKey(error)),
          error: error,
          onRetry: () => ref.invalidate(provider),
        ),
        data: (editor) => _body(t, editor),
      ),
    );
  }

  Widget _body(Translator t, AttendanceEditorState editor) {
    final now = ref.watch(mentorNowProvider).value ?? ref.watch(mentorClockProvider)();
    final records = editor.roster.records;
    final editable = editor.editableAt(now);
    final canEdit = editable && !editor.locked;
    final header = editor.roster.header;
    final present = records.where((row) => editor.statusOf(row) == AttendanceStatus.PRESENT).length;
    final absent = records.where((row) => editor.statusOf(row) == AttendanceStatus.ABSENT).length;
    final unmarked = records.length - present - absent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StaffStats(
          items: [
            (label: t('mentor.attendance.present'), value: '$present', tone: StatusTone.green),
            (label: t('mentor.attendance.absent'), value: '$absent', tone: StatusTone.red),
            (label: t('mentor.attendance.unmarked'), value: '$unmarked', tone: StatusTone.gray),
          ],
        ),
        const SizedBox(height: 12),
        if (header.session.editableUntil != null)
          Text(
            t(editable ? 'mentor.attendance.editableUntil' : 'mentor.attendance.readonly', {
              'time': Dates.instant(header.session.editableUntil!, header.session.timeZone),
            }),
            style: StaffText.caption,
          ),
        if (editor.dirty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t('mentor.attendance.unsaved', {'count': editor.draft.length}), style: StaffText.link),
          ),
        if (editor.error != null) ...[
          const SizedBox(height: 12),
          StaffDataState(
            title: t('mentor.attendance.actionError'),
            description: t(attendanceErrorKey(editor.error!)),
            error: editor.error,
            onRetry: editor.retryPending || editor.reloadRequired ? () => _controller.retry() : null,
          ),
        ],
        if (editor.conflict) ...[
          const SizedBox(height: 12),
          StaffButton(
            label: t('mentor.attendance.reviewDraft'),
            onPressed: editor.locked ? null : _controller.reviewDraft,
          ),
          const SizedBox(height: 8),
          StaffButton(
            label: t('mentor.attendance.serverData'),
            outlined: true,
            onPressed: editor.locked ? null : _controller.discardDraft,
          ),
        ],
        if (editor.busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: StaffColors.teal600),
          const SizedBox(height: 6),
          Text(
            t('mentor.attendance.progress', {'done': editor.sentBatches, 'total': editor.totalBatches}),
            style: StaffText.small,
          ),
        ],
        const SizedBox(height: 16),
        if (header.permissions.canStart)
          StaffButton(
            label: t('mentor.attendance.start'),
            icon: Sym.playArrow,
            loading: editor.busy,
            onPressed: editor.locked || !editor.startableAt(now)
                ? null
                : () => _action(_controller.start, 'mentor.attendance.started'),
          ),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t(
                header.session.actualStartedAt == null
                    ? (header.permissions.canStart
                          ? 'mentor.attendance.beforeStart'
                          : 'mentor.attendance.startUnavailable')
                    : 'mentor.attendance.empty',
              ),
              style: StaffText.caption,
            ),
          ),
        if (records.isNotEmpty) ...[
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .36,
            child: GridView.builder(
              itemCount: records.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 150 * (MediaQuery.textScalerOf(context).scale(13) / 13),
              ),
              itemBuilder: (context, index) {
                final row = records[index], status = editor.statusOf(records[index]);
                return _AttendanceTile(
                  record: row,
                  status: status,
                  onTap: canEdit
                      ? () => _controller.setStatus(
                          row,
                          status == AttendanceStatus.PRESENT ? AttendanceStatus.ABSENT : AttendanceStatus.PRESENT,
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (editable)
            StaffButton(
              label: t('mentor.attendance.bulk'),
              outlined: true,
              icon: Sym.checkCircle,
              onPressed: !canEdit || editor.dirty || editor.conflict ? null : () => _bulk(editor),
            ),
        ],
        if (header.permissions.canSync) ...[
          const SizedBox(height: 8),
          StaffButton(
            label: t('mentor.attendance.sync'),
            outlined: true,
            icon: Sym.sync,
            onPressed: !canEdit || editor.dirty || editor.conflict ? null : () => _sync(editor),
          ),
        ],
        if (editable) ...[
          const SizedBox(height: 16),
          StaffButton(
            label: t('mentor.attendance.save'),
            icon: Sym.factCheck,
            loading: editor.busy,
            onPressed: !canEdit || !editor.dirty || editor.conflict
                ? null
                : () => _action(_controller.save, 'mentor.attendance.saved'),
          ),
        ],
        if (header.permissions.canFinalize) ...[
          const SizedBox(height: 8),
          StaffButton(
            label: t('mentor.attendance.finalize'),
            outlined: true,
            onPressed: !canEdit || editor.dirty || editor.conflict ? null : () => _finalize(editor),
          ),
          if (editor.dirty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t('mentor.attendance.saveFirst'), style: StaffText.small),
            ),
        ],
      ],
    );
  }
}

class _AttendanceTile extends ConsumerWidget {
  const _AttendanceTile({required this.record, required this.status, required this.onTap});
  final AttendanceRecord record;
  final AttendanceStatus status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final tone = switch (status) {
      AttendanceStatus.PRESENT => StatusTone.green,
      AttendanceStatus.ABSENT => StatusTone.red,
      _ => StatusTone.gray,
    };
    final name = record.student.displayName ?? t('mentor.attendance.unnamedStudent');
    final label = t('mentor.attendance.status.${status.name}');
    return Pressable(
      onTap: onTap,
      semanticLabel: '$name, $label',
      selected: status == AttendanceStatus.PRESENT,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InitialsAvatar(name: name, size: 40),
            const SizedBox(height: 6),
            Tooltip(
              message: name,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: StaffText.label,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: StaffText.small.copyWith(color: tone.fg),
              textAlign: TextAlign.center,
            ),
            if (record.type == AttendanceEntryType.MAKEUP) Text(t('mentor.attendance.makeup'), style: StaffText.small),
          ],
        ),
      ),
    );
  }
}
