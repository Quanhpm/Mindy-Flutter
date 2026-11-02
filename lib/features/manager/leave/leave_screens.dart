import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/await_provider.dart';
import '../../mentor/operations/operations_models.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'leave_models.dart';
import 'leave_providers.dart';

class ManagerLeavesScreen extends ConsumerStatefulWidget {
  const ManagerLeavesScreen({super.key});
  @override
  ConsumerState<ManagerLeavesScreen> createState() => _ManagerLeavesState();
}

class _ManagerLeavesState extends ConsumerState<ManagerLeavesScreen> {
  LeaveStatus? _status = LeaveStatus.PENDING;
  String? _mentor;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        q = (status: _status, mentorId: _mentor),
        p = managerLeavesProvider((status: _status, mentorId: _mentor));
    final people = ref.watch(managerPeopleProvider((role: 'MENTOR', search: '')));
    return StaffPage(
      title: t('manager.utility.leaves'),
      onBack: () => managerBack(context),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(p),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            FilterChipsBar<LeaveStatus?>(
              items: [
                (null, t('manager.all')),
                for (final s in LeaveStatus.values) (s, t('mentor.leave.status.${s.name}')),
              ],
              selected: _status,
              onSelected: (s) => setState(() => _status = s),
            ),
            const SizedBox(height: 12),
            ManagerData(
              value: people,
              onRetry: () => ref.invalidate(managerPeopleProvider((role: 'MENTOR', search: ''))),
              data: (persons) => DropdownButton<String>(
                value: _mentor,
                isExpanded: true,
                hint: Text(t('manager.allMentors'), style: StaffText.body),
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(t('manager.allMentors'))),
                  for (final person in persons)
                    DropdownMenuItem(
                      value: person.id,
                      child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _mentor = v),
              ),
            ),
            const SizedBox(height: 12),
            ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(managerLeavesProvider(q)),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        onTap: () => context.push(Routes.managerLeave(row.request.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              people.value?.where((p) => p.id == row.mentorId).firstOrNull?.name ?? t('manager.mentor'),
                              style: StaffText.bodyStrong,
                            ),
                            StatusChip(t('mentor.leave.status.${row.request.status.name}')),
                            Text(
                              '${Dates.displayDay(row.request.from)} – ${Dates.displayDay(row.request.to)}',
                              style: StaffText.body,
                            ),
                            Text(
                              row.request.reason,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: StaffText.body,
                            ),
                            Text(t('mentor.leave.count', {'count': row.request.count}), style: StaffText.caption),
                          ],
                        ),
                      ),
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

class ManagerLeaveDetailScreen extends ConsumerStatefulWidget {
  const ManagerLeaveDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ManagerLeaveDetailScreen> createState() => _ManagerLeaveDetailState();
}

class _ManagerLeaveDetailState extends ConsumerState<ManagerLeaveDetailScreen> {
  Future<void> _decide(ManagerLeaveDetail d, bool approve) async {
    final t = ref.read(trProvider),
        result = await managerConfirm(
          context,
          title: t(approve ? 'manager.approveLeave' : 'manager.rejectLeave'),
          description: t(approve ? 'manager.leaveApproveDescription' : 'manager.leaveRejectDescription'),
          acknowledgement: approve && d.conflictCount > 0
              ? t('manager.ackConflicts', {'count': d.conflictCount})
              : null,
        );
    if (!mounted || result == null) return;
    try {
      await ref
          .read(managerLeaveCommandProvider(widget.id).notifier)
          .decide(d, approve: approve, reason: result.reason, acknowledge: result.acknowledge);
    } catch (e) {
      if (mounted) showStaffToast(context, t(managerErrorKey(e)));
    }
  }

  Future<void> _reload() async {
    ref.invalidate(managerLeaveDetailProvider(widget.id));
    try {
      await awaitWidgetProvider(ref, managerLeaveDetailProvider(widget.id).future);
      if (mounted) ref.read(managerLeaveCommandProvider(widget.id).notifier).reviewed();
    } catch (_) {
      /* vùng đọc hiển thị lỗi */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        p = managerLeaveDetailProvider(widget.id),
        command = ref.watch(managerLeaveCommandProvider(widget.id));
    return StaffPage(
      title: t('mentor.leave.detail'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (d) {
              final r = d.header.request;
              final person = ref.watch(managerPersonProvider((role: 'MENTOR', id: d.header.mentorId)));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(person.value?.name ?? t('manager.mentor'), style: StaffText.title),
                  StatusChip(t('mentor.leave.status.${r.status.name}')),
                  const SizedBox(height: 12),
                  Text(
                    '${Dates.displayDay(r.from)} – ${Dates.displayDay(r.to)} · ${t('mentor.leave.period.${r.period.name}')}\n${r.reason}',
                    style: StaffText.body,
                  ),
                  Text(t('mentor.leave.zone', {'zone': r.zone}), style: StaffText.caption),
                  Text(t('manager.leaveExpires', {'date': Dates.instant(r.expires, r.zone)}), style: StaffText.caption),
                  if (!d.sourcesCurrent) Text(t('manager.sourcesStale'), style: StaffText.bodyStrong),
                  Text(t('mentor.leave.conflicts', {'count': d.conflictCount}), style: StaffText.bodyStrong),
                  for (final c in d.conflicts)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ConflictLabel(conflict: c),
                    ),
                  if (d.conflicts.length < d.conflictCount)
                    Text(t('manager.conflictPartial'), style: StaffText.caption),
                  for (final item in d.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ClassLabel(id: item.classId),
                            Text(t('mentor.leave.source'), style: StaffText.label),
                            Text(
                              '${Dates.instant(item.sourceStart, r.zone)} – ${Dates.time(item.sourceEnd, r.zone)}',
                              style: StaffText.body,
                            ),
                            Text(t('mentor.leave.replacement'), style: StaffText.label),
                            Text(
                              '${Dates.instant(item.start, r.zone)} – ${Dates.time(item.end, r.zone)}',
                              style: StaffText.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final ext in r.extensions) _ExtensionLabel(id: ext.classId, end: ext.endDate),
                  if (r.reviewReason != null) Text(r.reviewReason!, style: StaffText.body),
                  if (command.error != null) managerFailure(t, command.error!),
                  if (command.retryPending) ...[
                    Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
                    StaffButton(
                      label: t('mentor.operations.retrySame'),
                      loading: command.busy,
                      onPressed: () => ref.read(managerLeaveCommandProvider(widget.id).notifier).retry(),
                    ),
                  ] else if (command.conflict)
                    StaffButton(label: t('mentor.operations.readLatest'), onPressed: _reload)
                  else if (r.status == LeaveStatus.PENDING) ...[
                    StaffButton(
                      label: t('manager.approveLeave'),
                      loading: command.busy,
                      onPressed: command.locked || !d.canApprove ? null : () => _decide(d, true),
                    ),
                    const SizedBox(height: 12),
                    StaffButton(
                      label: t('manager.rejectLeave'),
                      outlined: true,
                      onPressed: command.locked ? null : () => _decide(d, false),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassLabel extends ConsumerWidget {
  const _ClassLabel({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(managerClassDetailProvider(id)).value?.info.name ?? ref.watch(trProvider)('manager.class'),
    style: StaffText.bodyStrong,
  );
}

class _ConflictLabel extends ConsumerWidget {
  const _ConflictLabel({required this.conflict});
  final StudentLeaveConflict conflict;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(managerPersonProvider((role: 'STUDENT', id: conflict.studentId)));
    return Text(
      '${person.value?.name ?? ref.watch(trProvider)('manager.student')} · ${ref.watch(trProvider)('manager.studentScheduleConflict')}',
      style: StaffText.caption,
    );
  }
}

class _ExtensionLabel extends ConsumerWidget {
  const _ExtensionLabel({required this.id, required this.end});
  final String id, end;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(managerClassDetailProvider(id)).value?.info.name ?? ref.watch(trProvider)('manager.class');
    return Text(
      ref.watch(trProvider)('mentor.leave.extension', {'name': name, 'date': Dates.displayDay(end)}),
      style: StaffText.caption,
    );
  }
}
