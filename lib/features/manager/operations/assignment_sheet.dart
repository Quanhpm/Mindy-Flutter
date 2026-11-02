import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/await_provider.dart';
import '../manager_widgets.dart';
import 'operations_models.dart';
import 'operations_providers.dart';

Future<void> showManagerAssignment(
  BuildContext context, {
  required AssignmentTarget target,
  required String label,
  bool canClear = false,
}) => showStaffSheet<void>(
  context,
  title: label,
  builder: (_) => SessionSheetGuard(
    child: SessionBoundView(
      child: _Assignment(target: target, canClear: canClear),
    ),
  ),
);

class _Assignment extends ConsumerStatefulWidget {
  const _Assignment({required this.target, required this.canClear});
  final AssignmentTarget target;
  final bool canClear;
  @override
  ConsumerState<_Assignment> createState() => _AssignmentState();
}

class _AssignmentState extends ConsumerState<_Assignment> {
  String? _mentor;
  Object? _error;
  Future<void> _send(AvailableMentors data, bool clear) async {
    final t = ref.read(trProvider),
        name = clear ? t('manager.clearSubstitute') : data.items.where((p) => p.id == _mentor).first.name;
    final answer = await managerConfirm(
      context,
      title: t('manager.assignMentor'),
      description: t('manager.assignmentDescription', {'name': name, 'count': data.affected}),
    );
    if (!mounted || answer == null) return;
    try {
      final result = await ref
          .read(managerAssignmentProvider(widget.target).notifier)
          .assign(version: data.version, mentorId: clear ? null : _mentor, reason: answer.reason);
      if (mounted && result != null) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _refresh() async {
    final p = managerCandidatesProvider(widget.target);
    ref.invalidate(p);
    try {
      await awaitWidgetProvider(ref, p.future);
      if (mounted) {
        ref.read(managerAssignmentProvider(widget.target).notifier).reviewed();
        setState(() => _mentor = null);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        p = managerCandidatesProvider(widget.target),
        command = ref.watch(managerAssignmentProvider(widget.target));
    return ManagerData(
      value: ref.watch(p),
      onRetry: () => ref.invalidate(p),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('manager.candidatesDescription'), style: StaffText.caption),
          Text(t('manager.affectedSessions', {'count': data.affected}), style: StaffText.bodyStrong),
          DropdownButton<String>(
            value: data.items.any((m) => m.id == _mentor) ? _mentor : null,
            isExpanded: true,
            hint: Text(t('manager.chooseMentor')),
            items: [
              for (final person in data.items.where((m) => !m.current))
                DropdownMenuItem(
                  value: person.id,
                  child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: command.locked || command.conflict ? null : (v) => setState(() => _mentor = v),
          ),
          if (data.items.where((m) => !m.current).isEmpty)
            Text(t('manager.noMentorCandidates'), style: StaffText.caption),
          if (_error != null) managerFailure(t, _error!),
          if (command.error != null) managerFailure(t, command.error!),
          if (command.retryPending) ...[
            Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
            StaffButton(
              label: t('mentor.operations.retrySame'),
              loading: command.busy,
              onPressed: () async {
                final r = await ref.read(managerAssignmentProvider(widget.target).notifier).retry();
                if (context.mounted && r != null) Navigator.pop(context);
              },
            ),
          ] else if (command.conflict)
            StaffButton(label: t('mentor.operations.readLatest'), onPressed: _refresh)
          else ...[
            StaffButton(
              label: t('manager.assignMentor'),
              loading: command.busy,
              onPressed: command.locked || !data.items.any((m) => m.id == _mentor && !m.current)
                  ? null
                  : () => _send(data, false),
            ),
            if (widget.canClear)
              TextButton(
                onPressed: command.locked ? null : () => _send(data, true),
                child: Text(t('manager.clearSubstitute')),
              ),
          ],
        ],
      ),
    );
  }
}
