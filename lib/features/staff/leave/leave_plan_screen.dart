import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import 'leave_query.dart';
import 'leave_service.dart';
import 'leave_widgets.dart';

typedef _Range = ({String from, String to, Period period});

/// `LeavePlanEditorScreen.tsx`: chọn phạm vi, xem buổi bị ảnh hưởng, xếp bù rồi gửi.
class StaffLeavePlanScreen extends ConsumerStatefulWidget {
  const StaffLeavePlanScreen({super.key});

  @override
  ConsumerState<StaffLeavePlanScreen> createState() => _PlanState();
}

class _PlanState extends ConsumerState<StaffLeavePlanScreen> {
  _Range _range = (from: '', to: '', period: Period.FULL_DAY);
  _Range? _editRange;
  Preview? _preview;
  Map<String, Mapping> _mappings = {};
  SourceSession? _picked;
  LeaveOutcome? _result;
  LeaveIntent? _prepared;
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  bool _reading = false,
      _changed = false,
      _confirm = false,
      _tooLarge = false,
      _invalid = false,
      _allowLeave = false;
  int _epoch = 0;
  late final _mutation = LeaveMutator(ref, () {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _epoch++;
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _applyRange(_Range value) => setState(() {
    _epoch++;
    _range = value;
    _preview = null;
    _mappings = {};
    _changed = false;
    _result = null;
    _editRange = null;
  });

  void _changeRange(_Range value) {
    if (_mappings.isNotEmpty) {
      setState(() => _editRange = value);
    } else {
      _applyRange(value);
    }
  }

  Future<({Preview preview, Map<String, Mapping> mappings, bool differs})?>
  _readPreview([bool checking = false]) async {
    if (ref.read(staffOfflineProvider) ||
        _reading ||
        _range.from.isEmpty ||
        _range.to.isEmpty ||
        dateRangeError(_range.from, _range.to) != null) {
      return null;
    }
    final ticket = ++_epoch;
    setState(() {
      _reading = true;
      _tooLarge = false;
    });
    final result = await ref
        .read(leaveServiceProvider)
        .read(
          LeaveReadRequest(
            kind: LeaveKind.preview,
            role: LeaveRole.MENTOR,
            fromDate: _range.from,
            toDate: _range.to,
            period: _range.period,
          ),
        );
    if (!mounted || ticket != _epoch) return null;
    setState(() {
      _reading = false;
      _result = result;
    });
    if (result.kind == LeaveOutcomeKind.denied) {
      setState(() {
        _preview = null;
        _mappings = {};
        _reason.clear();
        _range = (from: '', to: '', period: _range.period);
      });
      return null;
    }
    final value = result.data?.preview;
    if (!result.success || value == null) return null;
    final next = Preview(
      sources: [...value.sources]
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
      sourceVersions: value.sourceVersions,
      noticeEligible: value.noticeEligible,
      noticeDeadline: value.noticeDeadline,
      asOf: value.asOf,
    );
    final maps = reconcileMappings(_mappings, next);
    List<({String sessionId, int version})> sorted(Preview p) =>
        [...p.sourceVersions]
          ..sort((a, b) => a.sessionId.compareTo(b.sessionId));
    final differs =
        _preview != null && !listEquals(sorted(_preview!), sorted(next));
    setState(() {
      _preview = next;
      _mappings = maps;
      _changed = checking && differs;
    });
    return (preview: next, mappings: maps, differs: differs);
  }

  Future<void> _prepare() async {
    if (!validReason(_reason.text)) {
      setState(() => _invalid = true);
      _reasonFocus.requestFocus();
      return;
    }
    final fresh = await _readPreview(true);
    if (!mounted ||
        fresh == null ||
        fresh.differs ||
        !fresh.preview.noticeEligible ||
        fresh.preview.sources.isEmpty ||
        fresh.preview.sources.any((s) => !fresh.mappings.containsKey(s.id))) {
      return;
    }
    final intent = LeaveIntent(
      kind: LeaveIntentKind.create,
      role: LeaveRole.MENTOR,
      fromDate: _range.from,
      toDate: _range.to,
      period: _range.period,
      reason: _reason.text.trim(),
      sourceVersions: fresh.preview.sourceVersions,
      sessionMappings: [
        for (final s in fresh.preview.sources)
          (
            sourceSessionId: s.id,
            targetDate:
                fresh.mappings[s.id]!.targetDate ??
                vietnamDay(fresh.mappings[s.id]!.startsAt),
            targetPeriod: fresh.mappings[s.id]!.targetPeriod ?? Period.EVENING,
            startsAt: fresh.mappings[s.id]!.startsAt,
            endsAt: fresh.mappings[s.id]!.endsAt,
          ),
      ],
    );
    if (leaveRequestBytes(intent.body()) > 64 * 1024) {
      setState(() => _tooLarge = true);
      return;
    }
    setState(() {
      _prepared = intent;
      _confirm = true;
    });
  }

  Future<void> _send() async {
    final intent = _prepared;
    if (intent == null) return;
    final t = ref.read(trProvider);
    final result = await _mutation.submit(intent);
    if (!mounted || result == null) return;
    if (result.success && result.data?.request != null) {
      setState(() {
        _allowLeave = true;
        _confirm = false;
      });
      ref.read(mdyToastProvider.notifier).show(t(lv('sent')));
      // Đợi PopScope nhận allowLeave trước khi replace route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pushReplacement(
            Routes.mentorLeaveDetail(result.data!.request!.id),
          );
        }
      });
    } else if (result.kind == LeaveOutcomeKind.denied) {
      setState(() {
        _confirm = false;
        _preview = null;
        _mappings = {};
        _reason.clear();
        _range = (from: '', to: '', period: _range.period);
        _result = result;
      });
    } else if (result.kind != LeaveOutcomeKind.uncertain) {
      setState(() => _confirm = false);
      if (result.kind == LeaveOutcomeKind.error &&
          const [
            'LEAVE_REQUEST_STALE',
            'LEAVE_NOTICE_TOO_SHORT',
          ].contains(result.code)) {
        await _readPreview(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final offline = ref.watch(staffOfflineProvider);
    final editable = !_reading && !_mutation.busy && !_mutation.uncertain;
    final preview = _preview;
    final valid =
        preview != null && preview.noticeEligible && preview.sources.isNotEmpty;
    final done =
        preview?.sources.where((s) => _mappings.containsKey(s.id)).length ?? 0;
    final rangeError = _range.from.isNotEmpty && _range.to.isNotEmpty
        ? dateRangeError(_range.from, _range.to)
        : null;
    Widget text(
      String value, {
      Key? key,
      bool heading = false,
      bool secondary = false,
    }) => Semantics(
      header: heading,
      child: Text(
        value,
        key: key,
        style: MdyType.size(
          heading ? 14 : 13,
          heading ? MdyType.w600 : MdyType.w400,
        ).copyWith(color: secondary ? c.secondary : c.ink),
      ),
    );
    return LeavePage(
      prefix: 'leave-plan',
      title: t(lv('leave.plan.title')),
      onBack: () => staffBack(context, manager: false),
      dirty:
          _range.from.isNotEmpty ||
          _range.to.isNotEmpty ||
          _reason.text.isNotEmpty,
      busy: _reading || _mutation.busy,
      uncertain: _mutation.uncertain,
      allowLeave: _allowLeave,
      footer: valid
          ? [
              Row(
                spacing: MdySpace.s12,
                children: [
                  Expanded(
                    child: text(
                      t(lv('leave.plan.progress'), {
                        'done': done,
                        'total': preview.sources.length,
                      }),
                      key: const Key('leave-plan-progress'),
                    ),
                  ),
                  MdyButton(
                    key: const Key('leave-plan-submit'),
                    label: t(lv('leave.plan.submit')),
                    disabled:
                        offline || !editable || done != preview.sources.length,
                    busy: _reading || _mutation.busy,
                    onPressed: _prepare,
                  ),
                ],
              ),
            ]
          : null,
      onOverlayBack: () => setState(() {
        _picked = null;
        _editRange = null;
        _confirm = false;
      }),
      overlays: [
        if (_picked case final picked?)
          LeaveSlotPicker(
            key: ValueKey(picked.id),
            source: picked,
            range: (
              fromDate: _range.from,
              toDate: _range.to,
              period: _range.period,
            ),
            others: [
              for (final e in _mappings.entries)
                if (e.key != picked.id) e.value,
            ],
            onClose: () => setState(() => _picked = null),
            onChanged: () async {
              setState(() => _picked = null);
              await _readPreview(true);
            },
            onPick: (slot) => setState(() {
              _mappings = {
                ..._mappings,
                picked.id: Mapping(
                  startsAt: slot.startsAt,
                  endsAt: slot.endsAt,
                  version: picked.version,
                  targetDate: slot.targetDate,
                  targetPeriod: slot.targetPeriod,
                ),
              };
              _picked = null;
            }),
          ),
        if (_editRange case final range?)
          MdyInlineDialog(
            key: const Key('leave-plan-range-dialog'),
            title: t(lv('leaveTitle')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _editRange = null),
            children: [
              text(t(lv('changeRange'), {'count': _mappings.length})),
              MdyButton(
                key: const Key('leave-plan-keep-range'),
                label: t(lv('keepRange')),
                onPressed: () => setState(() => _editRange = null),
              ),
              MdyButton(
                key: const Key('leave-plan-clear-range'),
                variant: MdyButtonVariant.danger,
                label: t(lv('clearRange')),
                onPressed: () => _applyRange(range),
              ),
            ],
          ),
        if (_confirm && preview != null)
          MdyInlineDialog(
            key: const Key('leave-plan-confirm'),
            title: t(lv('leave.plan.confirmTitle')),
            icon: MdyIcons.eventNote,
            busy: _mutation.busy || _mutation.uncertain,
            onClose: () => setState(() => _confirm = false),
            children: [
              text(
                t(lv('leave.plan.confirmBody'), {
                  'count': preview.sources.length,
                  'expires': instantLabel(preview.sources.first.startsAt),
                }),
              ),
              LeaveOutcomeError(
                result: _mutation.result,
                prefix: 'leave-plan',
                retry: _send,
              ),
              if (!_mutation.uncertain)
                MdyButton(
                  key: const Key('leave-plan-confirm-send'),
                  label: t(lv('leave.plan.submit')),
                  busy: _mutation.busy,
                  disabled: offline,
                  onPressed: _send,
                ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(lv('leave.plan.confirmBack')),
                disabled: _mutation.busy || _mutation.uncertain,
                onPressed: () => setState(() => _confirm = false),
              ),
            ],
          ),
      ],
      children: [
        text('1. ${t(lv('leave.plan.sectionRange'))}', heading: true),
        Row(
          spacing: MdySpace.s12,
          children: [
            Expanded(
              child: LeaveDateField(
                id: 'leave-plan-from',
                label: t(lv('leave.plan.from')),
                value: _range.from,
                disabled: !editable,
                onChange: (v) => _changeRange((
                  from: v,
                  to: _range.to.isEmpty ? v : _range.to,
                  period: _range.period,
                )),
              ),
            ),
            Expanded(
              child: LeaveDateField(
                id: 'leave-plan-to',
                label: t(lv('leave.plan.to')),
                value: _range.to,
                disabled: !editable,
                onChange: (v) => _changeRange((
                  from: _range.from,
                  to: v,
                  period: _range.period,
                )),
              ),
            ),
          ],
        ),
        text(t(lv('leave.plan.period'))),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: MdySpace.s8,
            runSpacing: MdySpace.s8,
            children: [
              for (final p in periods)
                SizedBox(
                  width: (box.maxWidth - MdySpace.s8) / 2,
                  child: LeaveChoice(
                    id: 'leave-plan-period-${p.name.toLowerCase()}',
                    label: t(lv(p.name)),
                    selected: _range.period == p,
                    disabled: !editable,
                    onPressed: () => _changeRange((
                      from: _range.from,
                      to: _range.to,
                      period: p,
                    )),
                  ),
                ),
            ],
          ),
        ),
        text(t(lv('leave.plan.periodHint')), secondary: true),
        if (rangeError != null)
          Text(
            t(
              lv(
                rangeError == 'before'
                    ? 'leave.plan.toBeforeFrom'
                    : rangeError == 'max'
                    ? 'leave.plan.rangeMax'
                    : 'invalidDate',
              ),
            ),
            key: const Key('leave-plan-range-error'),
            style: MdyType.size(13).copyWith(color: c.danger),
          ),
        MdyButton(
          key: const Key('leave-plan-preview'),
          variant: MdyButtonVariant.secondary,
          label: t(lv('leave.plan.preview')),
          busy: _reading,
          disabled:
              _range.from.isEmpty ||
              _range.to.isEmpty ||
              rangeError != null ||
              offline ||
              !editable,
          onPressed: _readPreview,
        ),
        if (offline)
          LeaveNotice(
            t(lv('leave.needOnline')),
            key: const Key('leave-plan-offline'),
            warning: true,
          ),
        if (_result?.kind == LeaveOutcomeKind.denied)
          LeaveNotice(t(lv('denied')), key: const Key('leave-plan-denied')),
        if (_result?.kind == LeaveOutcomeKind.error) ...[
          LeaveOutcomeError(result: _result, prefix: 'leave-plan'),
          if (!offline)
            MdyButton(
              key: const Key('leave-plan-retry'),
              label: t(lv('retry')),
              onPressed: _readPreview,
            ),
        ],
        if (_reading) const LeaveLoading(),
        if (preview != null && !_reading) ...[
          if (preview.sources.isEmpty)
            LeaveNotice(
              t(lv('leave.plan.noSessions')),
              key: const Key('leave-plan-no-sessions'),
            )
          else ...[
            if (!preview.noticeEligible)
              LeaveNotice(
                t(lv('leave.plan.noticeLate'), {
                  'session': instantLabel(preview.sources.first.startsAt),
                  'deadline': preview.noticeDeadline == null
                      ? '—'
                      : instantLabel(preview.noticeDeadline!),
                }),
                key: const Key('leave-plan-notice-late'),
                danger: true,
              )
            else ...[
              text(
                '2. ${t(lv('leave.plan.sectionMakeup'), {'done': done, 'total': preview.sources.length})}',
                heading: true,
              ),
              LeaveNotice(
                t(lv('leave.plan.noticeOk'), {
                  'deadline': preview.noticeDeadline == null
                      ? '—'
                      : instantLabel(preview.noticeDeadline!),
                }),
                key: const Key('leave-plan-notice-ok'),
              ),
            ],
            if (_changed)
              LeaveNotice(
                t(lv('changed')),
                key: const Key('leave-plan-changed'),
                warning: true,
              ),
            for (final s in preview.sources)
              MdyCard(
                key: Key('leave-plan-session-${s.id}'),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(MdySpace.s16),
                gap: MdySpace.s12,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s12,
                    children: [
                      LeaveDayTile(value: s.startsAt),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: MdySpace.s2,
                          children: [
                            if (s.className case final name?)
                              text(name, secondary: true),
                            text(s.title, heading: true),
                            text(
                              '${timeLabel(s.startsAt)}–${timeLabel(s.endsAt)}',
                            ),
                            if (s.assignment.name == 'SUBSTITUTE')
                              const LeaveStatusChip(
                                status: 'leave.plan.substitute',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_mappings[s.id] case final mapping?)
                    Row(
                      spacing: MdySpace.s8,
                      children: [
                        MdyIcon(MdyIcons.eventRepeat, size: 16, color: c.link),
                        Expanded(
                          child: Text(
                            '${t(lv('leave.targetTime'))} · ${slotLabel(mapping)}',
                            key: Key('leave-plan-session-target-${s.id}'),
                            style: MdyType.size(13).copyWith(color: c.link),
                          ),
                        ),
                        if (preview.noticeEligible)
                          MdyButton(
                            key: Key('leave-plan-pick-${s.id}'),
                            size: MdyButtonSize.sm,
                            variant: MdyButtonVariant.secondary,
                            label: t(lv('leave.plan.change')),
                            disabled: offline || !editable,
                            onPressed: () => setState(() => _picked = s),
                          ),
                      ],
                    )
                  else if (preview.noticeEligible)
                    MdyButton(
                      key: Key('leave-plan-pick-${s.id}'),
                      size: MdyButtonSize.sm,
                      variant: MdyButtonVariant.secondary,
                      label: t(lv('leave.plan.pick')),
                      disabled: offline || !editable,
                      onPressed: () => setState(() => _picked = s),
                    ),
                ],
              ),
            if (valid) ...[
              text('3. ${t(lv('leave.plan.sectionReason'))}', heading: true),
              LeaveField(
                id: 'leave-plan-reason',
                hideLabel: true,
                label: t(lv('leave.reason')),
                controller: _reason,
                focusNode: _reasonFocus,
                max: 1000,
                disabled: !editable,
                error: _invalid
                    ? t(
                        lv(
                          _reason.text.trim().length > 1000
                              ? 'reasonLong'
                              : 'leave.reasonRequired',
                        ),
                      )
                    : null,
                onChanged: (_) => setState(() => _invalid = false),
              ),
              text(t(lv('leave.plan.pendingNote')), secondary: true),
              text(t(lv('leave.plan.memoryNote')), secondary: true),
            ],
          ],
        ],
        if (_tooLarge)
          LeaveNotice(
            t(lv('bodyTooLarge')),
            key: const Key('leave-plan-too-large'),
            danger: true,
          ),
        if (!_confirm)
          LeaveOutcomeError(
            result: _mutation.result,
            prefix: 'leave-plan',
            retry: _send,
          ),
      ],
    );
  }
}

typedef PickedSlot = ({
  DateTime startsAt,
  DateTime endsAt,
  String targetDate,
  Period targetPeriod,
});

class LeaveSlotPicker extends ConsumerStatefulWidget {
  const LeaveSlotPicker({
    super.key,
    required this.source,
    required this.range,
    required this.others,
    required this.onPick,
    required this.onClose,
    required this.onChanged,
  });
  final SourceSession source;
  final ({String fromDate, String toDate, Period period}) range;
  final List<Slot> others;
  final ValueChanged<PickedSlot> onPick;
  final VoidCallback onClose, onChanged;

  @override
  ConsumerState<LeaveSlotPicker> createState() => _SlotState();
}

class _SlotState extends ConsumerState<LeaveSlotPicker> {
  String _date = '';
  late Period _period =
      int.parse(timeLabel(widget.source.startsAt).substring(0, 2)) < 12
      ? Period.MORNING
      : int.parse(timeLabel(widget.source.startsAt).substring(0, 2)) < 18
      ? Period.AFTERNOON
      : Period.EVENING;
  Slot? _selected;
  final _closestKey = GlobalKey();
  String? _scrolledTo;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final request = LeaveReadRequest(
      kind: LeaveKind.slots,
      role: LeaveRole.MENTOR,
      id: widget.source.id,
      targetDate: _date,
      targetPeriod: _period,
    );
    final query = _date.isEmpty ? null : ref.watch(leaveQueryProvider(request));
    final controller = _date.isEmpty
        ? null
        : ref.read(leaveQueryProvider(request).notifier);
    final offline =
        ref.watch(staffOfflineProvider) || (query?.offline ?? false);
    if (query?.data?.sessionVersion case final version?) {
      if (version != widget.source.version) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged();
        });
      }
    }
    final slots =
        query?.data?.slots
            ?.where((s) => slotAllowed(s, widget.range, widget.others))
            .toList() ??
        <Slot>[];
    int clock(DateTime d) => int.parse(timeLabel(d).replaceAll(':', ''));
    final original = clock(widget.source.startsAt);
    final closest =
        ([...slots]..sort(
              (a, b) => (clock(a.startsAt) - original).abs().compareTo(
                (clock(b.startsAt) - original).abs(),
              ),
            ))
            .firstOrNull;
    if (closest != null &&
        query?.busy == false &&
        _scrolledTo != closest.startsAt.toIso8601String()) {
      _scrolledTo = closest.startsAt.toIso8601String();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_closestKey.currentContext case final target?) {
          Scrollable.ensureVisible(target, alignment: .2);
        }
      });
    }
    return MdyInlineSheet(
      key: const Key('leave-plan-slot-sheet'),
      title: t(lv('leave.plan.pickTitle')),
      onClose: widget.onClose,
      children: [
        Text(
          widget.source.title,
          style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink),
        ),
        MdyText(
          '${slotLabel(widget.source)} · ${t(lv('leave.plan.duration'), {'minutes': widget.source.endsAt.difference(widget.source.startsAt).inMinutes})}',
        ),
        LeaveDateField(
          id: 'leave-plan-target-date',
          label: t(lv('leave.plan.targetDate')),
          value: _date,
          disabled: offline,
          onChange: (v) => setState(() {
            _date = v;
            _selected = null;
            _scrolledTo = null;
          }),
        ),
        Wrap(
          spacing: MdySpace.s8,
          runSpacing: MdySpace.s8,
          children: [
            for (final p in periods.where((p) => p != Period.FULL_DAY))
              MdyButton(
                key: Key('leave-plan-target-period-${p.name.toLowerCase()}'),
                size: MdyButtonSize.sm,
                variant: _period == p
                    ? MdyButtonVariant.primary
                    : MdyButtonVariant.secondary,
                label: t(lv(p.name)),
                disabled: offline,
                onPressed: () => setState(() {
                  _period = p;
                  _selected = null;
                  _scrolledTo = null;
                }),
              ),
          ],
        ),
        if (_date.isEmpty)
          MdyText(t(lv('leave.plan.pickDateFirst')))
        else if (query!.busy)
          const LeaveLoading()
        else if (query.fatal || offline)
          LeaveNotice(
            t(
              lv(
                query.result!.kind == LeaveOutcomeKind.denied
                    ? 'denied'
                    : offline
                    ? 'leave.offlineEmpty'
                    : 'notFound',
              ),
            ),
            warning: offline,
          )
        else if (query.result?.kind == LeaveOutcomeKind.error) ...[
          MdyText(t(lv('error'))),
          MdyButton(
            key: const Key('leave-plan-slot-retry'),
            label: t(lv('retry')),
            onPressed: controller!.retry,
          ),
        ] else if (slots.isEmpty)
          MdyText(
            t(lv('leave.plan.noSlots')),
            key: const Key('leave-plan-slot-empty'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, box) => Wrap(
                  spacing: MdySpace.s8,
                  runSpacing: MdySpace.s8,
                  children: [
                    for (final slot in slots)
                      SizedBox(
                        key: identical(slot, closest) ? _closestKey : null,
                        width: (box.maxWidth - MdySpace.s8) / 2,
                        child: LeaveChoice(
                          id: 'leave-plan-slot-${timeLabel(slot.startsAt)}',
                          label:
                              '${timeLabel(slot.startsAt)}–${timeLabel(slot.endsAt)}',
                          selected: _selected?.startsAt == slot.startsAt,
                          onPressed: () => setState(() => _selected = slot),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        MdyButton(
          key: const Key('leave-plan-use-slot'),
          label: t(lv('leave.plan.useSlot')),
          disabled:
              _selected == null || offline || query?.result?.success != true,
          onPressed: () {
            final slot = _selected;
            if (slot != null) {
              widget.onPick((
                startsAt: slot.startsAt,
                endsAt: slot.endsAt,
                targetDate: _date,
                targetPeriod: _period,
              ));
            }
          },
        ),
        MdyButton(
          key: const Key('leave-plan-slot-close'),
          variant: MdyButtonVariant.text,
          label: t(lv('close')),
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}
