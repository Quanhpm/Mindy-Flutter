import '../../../core/ui/session_sheet_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_text_area.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/await_provider.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../classes/classes_providers.dart';
import '../schedule/schedule_models.dart';
import 'operations_models.dart';
import 'operations_providers.dart';
import 'operations_widgets.dart';

StatusTone _tone(LeaveStatus status) => switch (status) {
  LeaveStatus.PENDING => StatusTone.amber,
  LeaveStatus.APPROVED => StatusTone.green,
  LeaveStatus.REJECTED => StatusTone.red,
  _ => StatusTone.gray,
};

class MentorLeaveScreen extends ConsumerStatefulWidget {
  const MentorLeaveScreen({super.key});
  @override
  ConsumerState<MentorLeaveScreen> createState() => _MentorLeaveScreenState();
}

class _MentorLeaveScreenState extends ConsumerState<MentorLeaveScreen> {
  LeaveStatus? _status;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), data = ref.watch(mentorLeavesProvider(_status));
    return StaffPage(
      title: t('mentor.leave.title'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mentorLeavesProvider(_status)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
          children: [
            StaffButton(
              label: t('mentor.leave.create'),
              icon: Sym.add,
              onPressed: () => context.push(Routes.mentorLeaveCreate),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in <LeaveStatus?>[null, ...LeaveStatus.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          status == null ? t('mentor.leave.all') : t('mentor.leave.status.${status.name}'),
                          style: StaffText.label,
                        ),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...data.when(
              skipLoadingOnRefresh: false,
              loading: () => [const Skeleton(height: 160)],
              error: (e, _) => [
                StaffDataState(
                  title: t('mentor.operations.failed'),
                  description: t(operationError(e)),
                  error: e,
                  onRetry: () => ref.invalidate(mentorLeavesProvider(_status)),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [StaffDataState(title: t('mentor.leave.empty'), description: t('mentor.leave.emptyDescription'))]
                  : [
                      for (final request in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            onTap: () => context.push(Routes.mentorLeaveDetail(request.id)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusChip(
                                  t('mentor.leave.status.${request.status.name}'),
                                  tone: _tone(request.status),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${Dates.displayDay(request.from)} – ${Dates.displayDay(request.to)}',
                                  style: StaffText.bodyStrong,
                                ),
                                Text(t('mentor.leave.period.${request.period.name}'), style: StaffText.caption),
                                Text(
                                  request.reason,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: StaffText.body,
                                ),
                                Text(t('mentor.leave.count', {'count': request.count}), style: StaffText.caption),
                              ],
                            ),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class MentorLeaveCreateScreen extends ConsumerStatefulWidget {
  const MentorLeaveCreateScreen({super.key});
  @override
  ConsumerState<MentorLeaveCreateScreen> createState() => _MentorLeaveCreateScreenState();
}

class _MentorLeaveCreateScreenState extends ConsumerState<MentorLeaveCreateScreen>
    with OperationsBack<MentorLeaveCreateScreen> {
  final _reason = TextEditingController();
  String? _from, _to;
  LeavePeriod _period = LeavePeriod.FULL_DAY;
  LeavePreview? _preview;
  LeaveQuery? _previewQuery;
  DateTime _received = DateTime.now();
  final _mappings = <String, LeaveMapping>{};
  bool _reading = false;
  Object? _error;
  @override
  String get fallback => Routes.mentorPage('leave');
  @override
  bool get hasDraft =>
      _reason.text.trim().isNotEmpty || _preview != null || ref.read(mentorLeaveCommandProvider).locked;
  @override
  void initState() {
    super.initState();
    _reason.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _reason.removeListener(_changed);
    _reason.dispose();
    super.dispose();
  }

  void _clearPreview() {
    _preview = null;
    _previewQuery = null;
    _mappings.clear();
    _error = null;
  }

  Future<void> _day(bool from) async {
    final picked = await pickOperationDay(context, initial: from ? _from : _to);
    if (mounted && picked != null) {
      setState(() {
        if (from) {
          _from = picked;
          _to ??= picked;
        } else {
          _to = picked;
        }
        _clearPreview();
      });
    }
  }

  Future<void> _read() async {
    if (_reading || _from == null || _to == null) return;
    final span = DateTime.parse(_to!).difference(DateTime.parse(_from!)).inDays;
    if (span < 0 || span >= 93) {
      setState(() => _error = ApiError(status: 422, code: 'LEAVE_RANGE_INVALID'));
      return;
    }
    setState(() {
      _reading = true;
      _error = null;
      _preview = null;
      _mappings.clear();
    });
    final query = (fromDate: _from!, toDate: _to!, period: _period);
    try {
      ref.invalidate(mentorLeavePreviewProvider(query));
      final preview = await awaitWidgetProvider(ref, mentorLeavePreviewProvider(query).future);
      if (mounted) {
        setState(() {
          _preview = preview;
          _previewQuery = query;
          _received = DateTime.now();
        });
        ref.read(mentorLeaveCommandProvider.notifier).reviewed();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _submit({bool retry = false}) async {
    try {
      final controller = ref.read(mentorLeaveCommandProvider.notifier);
      final result = retry
          ? await controller.retry()
          : await controller.create(
              LeaveDraft(
                query: _previewQuery!,
                reason: _reason.text,
                preview: _preview!,
                mappings: List.unmodifiable(_mappings.values),
              ),
            );
      if (mounted && result != null) {
        context.go(Routes.mentorLeaveDetail(result.id));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    ref.watch(appNowProvider);
    final command = ref.watch(mentorLeaveCommandProvider), classes = ref.watch(mentorClassesProvider).value;
    final eligible =
        _preview?.eligible == true &&
        _preview?.deadline != null &&
        _preview!.asOf.add(DateTime.now().difference(_received)).isBefore(_preview!.deadline!);
    return protect(
      StaffPage(
        title: t('mentor.leave.create'),
        onBack: back,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
          children: [
            operationDay(
              t,
              label: t('mentor.leave.from'),
              day: _from,
              onPressed: command.locked || _reading ? null : () => _day(true),
            ),
            operationDay(
              t,
              label: t('mentor.leave.to'),
              day: _to,
              onPressed: command.locked || _reading ? null : () => _day(false),
            ),
            DropdownButtonFormField<LeavePeriod>(
              decoration: InputDecoration(labelText: t('mentor.leave.periodLabel')),
              // Flutter 3.32 chưa có initialValue.
              // ignore: deprecated_member_use
              value: _period,
              items: [
                for (final p in LeavePeriod.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(t('mentor.leave.period.${p.name}'), style: StaffText.body),
                  ),
              ],
              onChanged: command.locked || _reading
                  ? null
                  : (period) {
                      if (period != null) {
                        setState(() {
                          _period = period;
                          _clearPreview();
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            StaffTextArea(
              label: t('mentor.leave.reason'),
              controller: _reason,
              maxLength: 1000,
              enabled: !command.locked,
            ),
            StaffButton(
              label: t('mentor.leave.preview'),
              outlined: true,
              loading: _reading,
              onPressed: _from == null || _to == null || command.locked ? null : _read,
            ),
            if (_error != null) operationFailure(t, _error!),
            if (command.error != null) operationFailure(t, command.error!),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text(t('mentor.leave.zone', {'zone': _preview!.zone}), style: StaffText.caption),
              Text(t('mentor.leave.count', {'count': _preview!.sessions.length}), style: StaffText.bodyStrong),
              if (!eligible) Text(t('mentor.leave.notEligible'), style: StaffText.caption),
              for (final session in _preview!.sessions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _SlotCard(
                    key: ValueKey('${session.id}:${_preview!.asOf.toIso8601String()}'),
                    session: session,
                    title: classes?.where((c) => c.id == session.classId).firstOrNull?.name ?? session.title,
                    zone: _preview!.zone,
                    enabled: eligible && !command.locked && !command.conflict,
                    onStale: () => setState(() {
                      _clearPreview();
                      _error = ApiError(status: 409, code: 'LEAVE_SOURCE_STALE');
                    }),
                    onChanged: (mapping) => setState(() {
                      if (mapping == null) {
                        _mappings.remove(session.id);
                      } else {
                        _mappings[session.id] = mapping;
                      }
                    }),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            if (command.retryPending) ...[
              Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
              StaffButton(
                label: t('mentor.operations.retrySame'),
                loading: command.busy,
                onPressed: () => _submit(retry: true),
              ),
            ] else
              StaffButton(
                label: t('mentor.leave.submit'),
                loading: command.busy,
                onPressed:
                    _preview == null ||
                        !eligible ||
                        _mappings.length != _preview!.sessions.length ||
                        _mappings.isEmpty ||
                        command.locked ||
                        command.conflict
                    ? null
                    : _submit,
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends ConsumerStatefulWidget {
  const _SlotCard({
    super.key,
    required this.session,
    required this.title,
    required this.zone,
    required this.enabled,
    required this.onChanged,
    required this.onStale,
  });
  final TeachingSession session;
  final String title, zone;
  final bool enabled;
  final ValueChanged<LeaveMapping?> onChanged;
  final VoidCallback onStale;
  @override
  ConsumerState<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends ConsumerState<_SlotCard> {
  String? _date;
  LeavePeriod _period = LeavePeriod.MORNING;
  LeaveSlots? _slots;
  LeaveSlot? _selected;
  bool _busy = false;
  Object? _error;
  void _clear() {
    _slots = null;
    _selected = null;
    _error = null;
    widget.onChanged(null);
  }

  Future<void> _day() async {
    final day = await pickOperationDay(context, initial: _date);
    if (mounted && day != null) {
      setState(() {
        _date = day;
        _clear();
      });
    }
  }

  Future<void> _load() async {
    if (_date == null || _busy) return;
    setState(() {
      _busy = true;
      _clear();
    });
    final query = (sessionId: widget.session.id, targetDate: _date!, period: _period);
    try {
      ref.invalidate(mentorLeaveSlotsProvider(query));
      final slots = await awaitWidgetProvider(ref, mentorLeaveSlotsProvider(query).future);
      if (!mounted) return;
      if (slots.version != widget.session.version || slots.zone != widget.zone) {
        widget.onStale();
        return;
      }
      setState(() => _slots = slots);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: StaffText.bodyStrong),
          Text(widget.session.title, style: StaffText.caption),
          Text(
            '${Dates.instant(widget.session.startsAt, widget.zone)} – ${Dates.time(widget.session.endsAt, widget.zone)}',
            style: StaffText.body,
          ),
          const SizedBox(height: 12),
          operationDay(
            t,
            label: t('mentor.leave.targetDate'),
            day: _date,
            onPressed: !widget.enabled || _busy ? null : _day,
          ),
          DropdownButton<LeavePeriod>(
            value: _period,
            isExpanded: true,
            items: [
              for (final p in LeavePeriod.values.where((p) => p != LeavePeriod.FULL_DAY))
                DropdownMenuItem(
                  value: p,
                  child: Text(t('mentor.leave.period.${p.name}'), style: StaffText.body),
                ),
            ],
            onChanged: !widget.enabled || _busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _period = value;
                        _clear();
                      });
                    }
                  },
          ),
          StaffButton(
            label: t('mentor.leave.findSlots'),
            outlined: true,
            loading: _busy,
            onPressed: _date == null || !widget.enabled || _busy ? null : _load,
          ),
          if (_error != null) operationFailure(t, _error!),
          if (_slots != null && _slots!.items.isEmpty) Text(t('mentor.leave.noSlots'), style: StaffText.caption),
          if (_slots != null && _slots!.items.isNotEmpty)
            DropdownButton<LeaveSlot>(
              value: _selected,
              isExpanded: true,
              hint: Text(t('mentor.leave.chooseSlot'), style: StaffText.caption),
              items: [
                for (final slot in _slots!.items)
                  DropdownMenuItem(
                    value: slot,
                    child: Text(
                      '${Dates.time(slot.startsAt, widget.zone)} – ${Dates.time(slot.endsAt, widget.zone)}',
                      style: StaffText.body,
                    ),
                  ),
              ],
              onChanged: !widget.enabled
                  ? null
                  : (slot) {
                      if (slot != null) {
                        setState(() => _selected = slot);
                        widget.onChanged(
                          LeaveMapping(sessionId: widget.session.id, targetDate: _date!, period: _period, slot: slot),
                        );
                      }
                    },
            ),
        ],
      ),
    );
  }
}

class MentorLeaveDetailScreen extends ConsumerStatefulWidget {
  const MentorLeaveDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<MentorLeaveDetailScreen> createState() => _MentorLeaveDetailScreenState();
}

class _MentorLeaveDetailScreenState extends ConsumerState<MentorLeaveDetailScreen> {
  Future<void> _withdraw(LeaveRequest request) async {
    final t = ref.read(trProvider);
    final answer = await showStaffSheet<String>(
      context,
      title: t('mentor.leave.withdraw'),
      builder: (_) => const SessionSheetGuard(child: SessionBoundView(child: _WithdrawReason())),
    );
    if (!mounted || answer == null) return;
    try {
      final result = await ref.read(mentorLeaveCommandProvider.notifier).withdraw(request, answer);
      if (mounted && result != null) {
        showStaffToast(context, t('mentor.operations.saved'));
      }
    } catch (error) {
      if (mounted) showStaffToast(context, t(operationError(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), detail = ref.watch(mentorLeaveDetailProvider(widget.requestId));
    final command = ref.watch(mentorLeaveCommandProvider), classes = ref.watch(mentorClassesProvider).value;
    return StaffPage(
      title: t('mentor.leave.detail'),
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.mentorPage('leave')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
        children: [
          if (detail.isLoading) const Skeleton(height: 160),
          if (detail.hasError)
            StaffDataState(
              title: t('mentor.operations.failed'),
              description: t(operationError(detail.error!)),
              error: detail.error,
              onRetry: () => ref.invalidate(mentorLeaveDetailProvider(widget.requestId)),
            ),
          if (detail.asData != null) ...[
            StatusChip(
              t('mentor.leave.status.${detail.requireValue.request.status.name}'),
              tone: _tone(detail.requireValue.request.status),
            ),
            const SizedBox(height: 12),
            Text(
              '${Dates.displayDay(detail.requireValue.request.from)} – ${Dates.displayDay(detail.requireValue.request.to)}',
              style: StaffText.title,
            ),
            Text(t('mentor.leave.period.${detail.requireValue.request.period.name}'), style: StaffText.body),
            Text(detail.requireValue.request.reason, style: StaffText.body),
            Text(t('mentor.leave.zone', {'zone': detail.requireValue.request.zone}), style: StaffText.caption),
            if (detail.requireValue.request.reviewReason != null)
              Text(detail.requireValue.request.reviewReason!, style: StaffText.bodyStrong),
            if (detail.requireValue.request.conflicts != null)
              Text(
                t('mentor.leave.conflicts', {'count': detail.requireValue.request.conflicts!}),
                style: StaffText.caption,
              ),
            for (final item in detail.requireValue.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classes?.where((c) => c.id == item.classId).firstOrNull?.name ?? t('mentor.leave.session'),
                        style: StaffText.bodyStrong,
                      ),
                      Text(t('mentor.leave.source'), style: StaffText.label),
                      Text(
                        '${Dates.instant(item.sourceStart, detail.requireValue.request.zone)} – ${Dates.time(item.sourceEnd, detail.requireValue.request.zone)}',
                        style: StaffText.body,
                      ),
                      Text(t('mentor.leave.replacement'), style: StaffText.label),
                      Text(
                        '${Dates.instant(item.start, detail.requireValue.request.zone)} – ${Dates.time(item.end, detail.requireValue.request.zone)}',
                        style: StaffText.body,
                      ),
                    ],
                  ),
                ),
              ),
            for (final extension in detail.requireValue.request.extensions)
              Text(
                t('mentor.leave.extension', {
                  'name':
                      classes?.where((c) => c.id == extension.classId).firstOrNull?.name ?? t('mentor.leave.session'),
                  'date': Dates.displayDay(extension.endDate),
                }),
                style: StaffText.caption,
              ),
            if (command.error != null) operationFailure(t, command.error!),
            if (command.retryPending) ...[
              Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
              StaffButton(
                label: t('mentor.operations.retrySame'),
                loading: command.busy,
                onPressed: () async {
                  await ref.read(mentorLeaveCommandProvider.notifier).retry();
                },
              ),
            ] else if (command.conflict)
              StaffButton(
                label: t('mentor.operations.readLatest'),
                onPressed: () async {
                  ref.invalidate(mentorLeaveDetailProvider(widget.requestId));
                  try {
                    await awaitWidgetProvider(ref, mentorLeaveDetailProvider(widget.requestId).future);
                    if (mounted) {
                      ref.read(mentorLeaveCommandProvider.notifier).reviewed();
                    }
                  } catch (_) {
                    /* Vùng đọc hiển thị lỗi và đường thử lại. */
                  }
                },
              )
            else if (detail.requireValue.request.status == LeaveStatus.PENDING &&
                !(command.result?.id == widget.requestId && command.result?.status != LeaveStatus.PENDING))
              StaffButton(
                label: t('mentor.leave.withdraw'),
                outlined: true,
                loading: command.busy,
                onPressed: command.locked ? null : () => _withdraw(detail.requireValue.request),
              ),
          ],
        ],
      ),
    );
  }
}

class _WithdrawReason extends ConsumerStatefulWidget {
  const _WithdrawReason();
  @override
  ConsumerState<_WithdrawReason> createState() => _WithdrawReasonState();
}

class _WithdrawReasonState extends ConsumerState<_WithdrawReason> {
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    _reason.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _reason.removeListener(_changed);
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return Column(
      children: [
        StaffTextArea(label: t('mentor.leave.withdrawReason'), controller: _reason, maxLength: 1000),
        StaffButton(
          label: t('mentor.leave.withdraw'),
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()),
        ),
      ],
    );
  }
}
