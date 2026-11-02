import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/await_provider.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'operations_models.dart';
import 'operations_providers.dart';

class ManagerMakeupScreen extends ConsumerStatefulWidget {
  const ManagerMakeupScreen({super.key});
  @override
  ConsumerState<ManagerMakeupScreen> createState() => _MakeupState();
}

class _MakeupState extends ConsumerState<ManagerMakeupScreen> {
  MakeupConflictStatus? _status = MakeupConflictStatus.OPEN;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerConflictsProvider(_status);
    return StaffPage(
      title: t('manager.utility.makeup'),
      onBack: () => managerBack(context),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(p),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            FilterChipsBar<MakeupConflictStatus?>(
              items: [
                (null, t('manager.all')),
                for (final s in MakeupConflictStatus.values) (s, t('manager.conflictStatus.${s.name}')),
              ],
              selected: _status,
              onSelected: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 12),
            ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(p),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final c in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        onTap: () => context.push(Routes.managerMakeupDetail(c.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.student.displayName ?? t('manager.student'), style: StaffText.bodyStrong),
                            Text(c.source.title, style: StaffText.body),
                            Text(Dates.instant(c.source.startsAt, c.source.timeZone), style: StaffText.body),
                            StatusChip(t('manager.conflictStatus.${c.status.name}')),
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

class ManagerMakeupDetailScreen extends ConsumerStatefulWidget {
  const ManagerMakeupDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ManagerMakeupDetailScreen> createState() => _MakeupDetailState();
}

class _MakeupDetailState extends ConsumerState<ManagerMakeupDetailScreen> {
  Object? _error;
  Future<void> _place(MakeupConflict source, MakeupCandidate target) async {
    final t = ref.read(trProvider),
        reason = await managerConfirm(
          context,
          title: t('manager.placeMakeup'),
          description:
              '${source.student.displayName ?? t('manager.student')}\n${source.source.title}\n→ ${target.session.title}\n${Dates.instant(target.session.startsAt, target.session.timeZone)}',
          acknowledgement: t('manager.confirmContentMatch'),
        );
    if (!mounted || reason == null) return;
    try {
      await ref.read(managerMakeupCommandProvider(widget.id).notifier).place(source, target, reason.reason);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cancel(MakeupConflict source) async {
    final t = ref.read(trProvider),
        reason = await managerConfirm(
          context,
          title: t('manager.cancelMakeup'),
          description: t('manager.cancelMakeupDescription', {
            'name': source.student.displayName ?? t('manager.student'),
            'title': source.source.title,
          }),
        );
    if (!mounted || reason == null) return;
    try {
      await ref.read(managerMakeupCommandProvider(widget.id).notifier).cancel(source, reason.reason);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _reload() async {
    ref.invalidate(managerConflictsProvider);
    ref.invalidate(managerConflictProvider(widget.id));
    ref.invalidate(managerMakeupCandidatesProvider(widget.id));
    try {
      await awaitWidgetProvider(ref, managerConflictProvider(widget.id).future);
      if (mounted) ref.read(managerMakeupCommandProvider(widget.id).notifier).reviewed();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        p = managerConflictProvider(widget.id),
        command = ref.watch(managerMakeupCommandProvider(widget.id));
    return StaffPage(
      title: t('manager.utility.makeup'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          if (_error != null) managerFailure(t, _error!),
          if (command.error != null) managerFailure(t, command.error!),
          if (command.retryPending) ...[
            Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
            StaffButton(
              label: t('mentor.operations.retrySame'),
              loading: command.busy,
              onPressed: () => ref.read(managerMakeupCommandProvider(widget.id).notifier).retry(),
            ),
          ] else if (command.conflict)
            StaffButton(label: t('mentor.operations.readLatest'), onPressed: _reload),
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (source) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(source.student.displayName ?? t('manager.student'), style: StaffText.title),
                Text(
                  ref.watch(managerClassDetailProvider(source.source.classId)).value?.info.name ?? t('manager.class'),
                  style: StaffText.bodyStrong,
                ),
                Text(source.source.title, style: StaffText.body),
                Text(
                  '${Dates.instant(source.source.startsAt, source.source.timeZone)} – ${Dates.time(source.source.endsAt, source.source.timeZone)}',
                  style: StaffText.body,
                ),
                StatusChip(t('manager.conflictStatus.${source.status.name}')),
                for (final interval in source.intervals)
                  Text(
                    '${Dates.instant(interval.start, source.source.timeZone)} – ${Dates.time(interval.end, source.source.timeZone)}',
                    style: StaffText.caption,
                  ),
                if (source.status == MakeupConflictStatus.MAKEUP_ASSIGNED &&
                    source.placementId != null &&
                    source.placementVersion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: StaffButton(
                      label: t('manager.cancelMakeup'),
                      outlined: true,
                      loading: command.busy,
                      onPressed: command.locked || command.conflict ? null : () => _cancel(source),
                    ),
                  ),
                if (source.status == MakeupConflictStatus.OPEN) ...[
                  const SizedBox(height: 16),
                  Text(t('manager.makeupCandidates'), style: StaffText.section),
                  ManagerData(
                    value: ref.watch(managerMakeupCandidatesProvider(widget.id)),
                    onRetry: () => ref.invalidate(managerMakeupCandidatesProvider(widget.id)),
                    data: (rows) => Column(
                      children: [
                        if (rows.isEmpty) const ManagerEmpty(),
                        for (final candidate in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    ref.watch(managerClassDetailProvider(candidate.session.classId)).value?.info.name ??
                                        t('manager.class'),
                                    style: StaffText.bodyStrong,
                                  ),
                                  Text(candidate.session.title, style: StaffText.body),
                                  Text(
                                    '${Dates.instant(candidate.session.startsAt, candidate.session.timeZone)} – ${Dates.time(candidate.session.endsAt, candidate.session.timeZone)}',
                                    style: StaffText.body,
                                  ),
                                  Text(
                                    t('manager.remainingCapacity', {'count': candidate.capacity}),
                                    style: StaffText.caption,
                                  ),
                                  StaffButton(
                                    label: t('manager.placeMakeup'),
                                    loading: command.busy,
                                    onPressed: command.locked || command.conflict || candidate.capacity < 1
                                        ? null
                                        : () => _place(source, candidate),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
