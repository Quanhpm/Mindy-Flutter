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

/// `MentorLeaveDetailScreen` / `LeaveReviewDetailScreen` của RN.
class StaffLeaveDetailScreen extends ConsumerStatefulWidget {
  const StaffLeaveDetailScreen({
    super.key,
    required this.id,
    required this.manager,
  });
  final String id;
  final bool manager;

  @override
  ConsumerState<StaffLeaveDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<StaffLeaveDetailScreen> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  late final _mutation = LeaveMutator(ref, () {
    if (mounted) setState(() {});
  });
  LeaveIntentKind? _sheet;
  int _version = 0;
  bool _invalid = false;
  LeaveRequest? _saved;
  List<SourceSession>? _replacements;

  LeaveRole get _role => widget.manager ? LeaveRole.MANAGER : LeaveRole.MENTOR;
  LeaveReadRequest get _request =>
      LeaveReadRequest(kind: LeaveKind.detail, role: _role, id: widget.id);

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sheet = _sheet;
    if (sheet == null) return;
    if (!validReason(_reason.text)) {
      setState(() => _invalid = true);
      _reasonFocus.requestFocus();
      return;
    }
    final t = ref.read(trProvider);
    final query = ref.read(leaveQueryProvider(_request));
    final controller = ref.read(leaveQueryProvider(_request).notifier);
    final result = await _mutation.submit(
      LeaveIntent(
        kind: sheet,
        role: _role,
        id: widget.id,
        reason: _reason.text.trim(),
        expectedVersion: _version,
      ),
      offline: query.offline,
    );
    if (!mounted || result == null) return;
    if (result.success && result.data?.request != null) {
      setState(() {
        _saved = result.data!.request;
        _replacements = result.data!.replacements;
        _sheet = null;
        _reason.clear();
      });
      ref
          .read(mdyToastProvider.notifier)
          .show(
            t(
              lv(switch (sheet) {
                LeaveIntentKind.withdraw => 'leave.detail.withdrawn',
                LeaveIntentKind.approve => 'leave.review.approved',
                _ => 'leave.review.rejected',
              }),
            ),
          );
    } else if (result.kind == LeaveOutcomeKind.error) {
      final data = await controller.refresh();
      if (!mounted) return;
      setState(() {
        if (data?.request != null) _version = data!.request!.version;
        if (const [
          'LEAVE_STATE_CONFLICT',
          'LEAVE_REQUEST_EXPIRED',
          'LEAVE_REQUEST_STALE',
          'LEAVE_STUDENT_CONFLICT',
          'LEAVE_STUDENT_CONFLICT_ACK_REQUIRED',
        ].contains(result.code)) {
          _sheet = null;
        }
      });
    } else if (result.kind == LeaveOutcomeKind.denied) {
      setState(() {
        _reason.clear();
        _sheet = null;
        _saved = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final manager = widget.manager;
    final prefix = manager ? 'leave-review' : 'leave-detail';
    final query = ref.watch(leaveQueryProvider(_request));
    final controller = ref.read(leaveQueryProvider(_request).notifier);
    final classRequest = LeaveReadRequest(
      kind: LeaveKind.classes,
      role: _role,
      pageSize: 100,
    );
    final classes = ref.watch(leaveQueryProvider(classRequest));
    drainLeaveOptions(
      classes,
      ref.read(leaveQueryProvider(classRequest).notifier),
    );
    final fresh = query.data?.request;
    if (fresh != null && _saved != null && fresh.version >= _saved!.version) {
      _saved = null;
    }
    final denied = _mutation.result?.kind == LeaveOutcomeKind.denied;
    final request = denied ? null : (_saved ?? fresh);
    final mentorRequest = LeaveReadRequest(
      kind: LeaveKind.mentors,
      role: LeaveRole.MANAGER,
      id: request?.mentorId,
    );
    final mentors = manager && request != null
        ? ref.watch(leaveQueryProvider(mentorRequest))
        : null;
    final mentorName =
        mentors?.data?.options
            ?.where((o) => o.id == request?.mentorId)
            .firstOrNull
            ?.name ??
        t(lv('mentorMissing'));
    String? className(String id) =>
        classes.data?.options?.where((o) => o.id == id).firstOrNull?.name;
    final canAct = request?.status == LeaveStatus.PENDING;
    final safe =
        !query.offline &&
        query.result?.success == true &&
        !_mutation.busy &&
        !_mutation.uncertain;
    final approve =
        canAct && request!.sourcesCurrent && request.studentConflictCount == 0;
    void open(LeaveIntentKind kind) {
      if (request == null) return;
      _mutation.clear();
      setState(() {
        _version = request.version;
        _invalid = false;
        _sheet = kind;
      });
    }

    Widget line(String text, {Key? key, bool secondary = false}) => Text(
      text,
      key: key,
      style: MdyType.size(13).copyWith(color: secondary ? c.secondary : c.ink),
    );
    void session(String id) => context.push(
      manager ? Routes.managerSession(id) : Routes.mentorSession(id),
    );
    final sheet = _sheet;
    final locked = _mutation.busy || _mutation.uncertain;
    return LeavePage(
      prefix: prefix,
      title: t(lv('leave.detail.title')),
      onBack: () => staffBack(context, manager: manager),
      refresh: () async {
        await controller.refresh();
      },
      busy: _mutation.busy,
      dirty: _reason.text.isNotEmpty,
      uncertain: _mutation.uncertain,
      footer: canAct
          ? [
              if (query.offline) line(t(lv('leave.needOnline'))),
              Row(
                spacing: MdySpace.s12,
                children: [
                  if (manager) ...[
                    Expanded(
                      child: MdyButton(
                        key: const Key('leave-review-reject'),
                        variant: MdyButtonVariant.secondary,
                        label: t(lv('leave.review.reject')),
                        disabled: !safe,
                        onPressed: () => open(LeaveIntentKind.reject),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        hint: approve ? null : t(lv('leave.changed')),
                        child: MdyButton(
                          key: const Key('leave-review-approve'),
                          label: t(lv('leave.review.approve')),
                          disabled: !safe || !approve,
                          onPressed: () => open(LeaveIntentKind.approve),
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: MdyButton(
                        key: const Key('leave-detail-withdraw'),
                        variant: MdyButtonVariant.danger,
                        label: t(lv('leave.detail.withdraw')),
                        disabled: !safe,
                        onPressed: () => open(LeaveIntentKind.withdraw),
                      ),
                    ),
                ],
              ),
            ]
          : null,
      onOverlayBack: () => setState(() => _sheet = null),
      overlays: [
        if (sheet != null && request != null)
          MdyInlineSheet(
            key: Key('$prefix-${sheet.name}-sheet'),
            title: t(
              lv(
                sheet == LeaveIntentKind.withdraw
                    ? 'leave.detail.withdrawTitle'
                    : 'leave.review.${sheet.name}Title',
              ),
            ),
            busy: locked,
            onClose: () => setState(() => _sheet = null),
            children: [
              if (sheet == LeaveIntentKind.approve) ...[
                line(
                  '$mentorName · ${rangeLabel(request.fromDate, request.toDate)}',
                ),
                LeaveNotice(
                  [
                    t(lv('leave.review.approveAfter')),
                    t(lv('leave.review.approveCancel'), {
                      'count': request.itemCount,
                    }),
                    t(lv('leave.review.approveCreate'), {
                      'count': request.itemCount,
                      'mentor': mentorName,
                    }),
                    t(lv('leave.review.approveExtend')),
                    t(lv('leave.review.noUndo')),
                  ].join('\n'),
                  warning: true,
                ),
              ] else
                line(
                  t(
                    lv(
                      sheet == LeaveIntentKind.withdraw
                          ? 'leave.detail.withdrawBody'
                          : 'leave.review.rejectBody',
                    ),
                    {'range': rangeLabel(request.fromDate, request.toDate)},
                  ),
                ),
              LeaveField(
                id: '$prefix-${sheet.name}-reason',
                label: t(lv('leave.reason')),
                controller: _reason,
                focusNode: _reasonFocus,
                disabled: locked,
                max: 1000,
                onChanged: (_) => setState(() {}),
                error: _invalid
                    ? t(
                        lv(
                          _reason.text.trim().length > 1000
                              ? 'reasonLong'
                              : 'leave.reasonRequired',
                        ),
                      )
                    : null,
              ),
              LeaveOutcomeError(
                result: _mutation.result,
                prefix: prefix,
                retry: _send,
              ),
              if (!_mutation.uncertain)
                MdyButton(
                  key: Key('$prefix-${sheet.name}-send'),
                  variant: sheet == LeaveIntentKind.approve
                      ? MdyButtonVariant.primary
                      : MdyButtonVariant.danger,
                  label: t(
                    lv(
                      sheet == LeaveIntentKind.withdraw
                          ? 'leave.detail.withdraw'
                          : 'leave.review.${sheet.name}',
                    ),
                  ),
                  busy: _mutation.busy,
                  disabled: query.offline,
                  onPressed: _send,
                ),
              MdyButton(
                key: sheet == LeaveIntentKind.withdraw
                    ? const Key('leave-detail-withdraw-keep')
                    : null,
                variant: MdyButtonVariant.text,
                label: t(
                  lv(
                    sheet == LeaveIntentKind.withdraw
                        ? 'leave.detail.keep'
                        : 'back',
                  ),
                ),
                disabled: locked,
                onPressed: () => setState(() => _sheet = null),
              ),
            ],
          ),
      ],
      children: [
        if (denied) LeaveNotice(t(lv('denied')), key: Key('$prefix-denied')),
        LeaveQueryBlock(
          query: query,
          controller: controller,
          prefix: prefix,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s16,
            children: [
              if (request != null) ...[
                MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s16),
                  gap: MdySpace.s10,
                  children: [
                    if (manager)
                      Text(
                        mentorName,
                        key: const Key('leave-review-mentor'),
                        style: MdyType.size(
                          14,
                          MdyType.w600,
                        ).copyWith(color: c.ink),
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
                                rangeLabel(request.fromDate, request.toDate),
                                key: Key('$prefix-range'),
                                style: MdyType.size(
                                  16,
                                  MdyType.w600,
                                ).copyWith(color: c.ink),
                              ),
                              line(
                                t(lv(request.period.name)),
                                key: Key('$prefix-period'),
                                secondary: true,
                              ),
                            ],
                          ),
                        ),
                        LeaveStatusChip(
                          key: Key('$prefix-status'),
                          status: request.status.name,
                        ),
                      ],
                    ),
                    line(
                      t(lv('leave.sentAt'), {
                        'time': instantLabel(request.submittedAt),
                      }),
                      secondary: true,
                    ),
                    if (canAct)
                      LeaveDueLine(
                        key: Key('$prefix-due'),
                        time: instantLabel(request.expiresAt),
                      ),
                    const LeaveDivider(),
                    Text(
                      t(lv('leave.reason')),
                      style: MdyType.size(
                        13,
                        MdyType.w600,
                      ).copyWith(color: c.ink),
                    ),
                    line(request.reason, key: Key('$prefix-reason')),
                  ],
                ),
                if (!canAct)
                  MdyCard(
                    key: Key('$prefix-${manager ? 'result' : 'review'}'),
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s16),
                    gap: MdySpace.s8,
                    children: [
                      Text(
                        '${t(lv(request.status.name))} · ${instantLabel(request.status == LeaveStatus.EXPIRED ? request.expiresAt : request.review?.reviewedAt ?? request.submittedAt)}',
                        style: MdyType.size(
                          14,
                          MdyType.w600,
                        ).copyWith(color: c.ink),
                      ),
                      if (request.status == LeaveStatus.EXPIRED)
                        line(t(lv('leave.reviewExpired')), secondary: true)
                      else ...[
                        line(
                          t(
                            lv(
                              request.status == LeaveStatus.WITHDRAWN
                                  ? 'leave.reviewWithdrawReason'
                                  : 'leave.reviewManagerReason',
                            ),
                          ),
                        ),
                        line(
                          request.review?.reason ?? '',
                          key: Key('$prefix-review-reason'),
                        ),
                      ],
                    ],
                  ),
                if (canAct && manager && !request.sourcesCurrent)
                  LeaveNotice(
                    t(lv('leave.review.staleBlock')),
                    key: const Key('leave-review-stale-block'),
                    danger: true,
                  ),
                if (canAct && (request.studentConflictCount ?? 0) > 0)
                  LeaveNotice(
                    t(
                      lv(
                        manager
                            ? 'leave.review.conflictBlock'
                            : 'leave.detail.conflictWarn',
                      ),
                      {'count': request.studentConflictCount!},
                    ),
                    key: Key(
                      manager
                          ? 'leave-review-conflict-block'
                          : 'leave-detail-conflict-warning',
                    ),
                    danger: true,
                  ),
                if (canAct && !manager)
                  LeaveNotice(
                    t(lv('leave.detail.notHeld')),
                    key: const Key('leave-detail-not-held'),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    t(lv('leave.detail.sessions'), {
                      'count': request.itemCount,
                    }),
                    style: MdyType.size(
                      14,
                      MdyType.w600,
                    ).copyWith(color: c.ink),
                  ),
                ),
                for (final item in request.items)
                  MdyCard(
                    key: Key('$prefix-session-${item.sourceSessionId}'),
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s16),
                    gap: MdySpace.s8,
                    children: [
                      if (className(item.classId) case final name?) line(name),
                      Row(
                        spacing: MdySpace.s8,
                        children: [
                          MdyIcon(
                            MdyIcons.schedule,
                            size: 16,
                            color: c.secondary,
                          ),
                          Expanded(
                            child: line(
                              '${t(lv('leave.sourceTime'))} · ${slotLabel(Slot(startsAt: item.sourceStartsAt, endsAt: item.sourceEndsAt))}',
                              secondary: true,
                            ),
                          ),
                          if (request.status == LeaveStatus.APPROVED)
                            MdyChip(
                              t(lv('leave.detail.cancelled')),
                              variant: MdyChipVariant.neutral,
                            ),
                        ],
                      ),
                      Semantics(
                        button:
                            request.status == LeaveStatus.APPROVED &&
                            item.replacementSessionId != null,
                        child: MdyPressed(
                          key: Key(
                            '$prefix-session-open-${item.sourceSessionId}',
                          ),
                          enabled:
                              request.status == LeaveStatus.APPROVED &&
                              item.replacementSessionId != null,
                          onTap: () => session(item.replacementSessionId!),
                          builder: (context, pressed) => Opacity(
                            opacity: pressed ? .8 : 1,
                            child: Row(
                              spacing: MdySpace.s8,
                              children: [
                                MdyIcon(
                                  MdyIcons.eventRepeat,
                                  size: 16,
                                  color:
                                      canAct ||
                                          item.replacementSessionId != null
                                      ? c.link
                                      : c.tertiary,
                                ),
                                Expanded(
                                  child: line(
                                    '${t(lv(request.status == LeaveStatus.APPROVED
                                        ? 'leave.detail.replacement'
                                        : canAct
                                        ? 'leave.targetTime'
                                        : 'leave.detail.proposed'))} · ${slotLabel(item)}',
                                  ),
                                ),
                                if (request.status == LeaveStatus.APPROVED &&
                                    item.replacementSessionId != null)
                                  MdyIcon(
                                    MdyIcons.chevronRight,
                                    size: 20,
                                    color: c.tertiary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (canAct &&
                          manager &&
                          request.studentConflicts.any(
                            (c) => c.sourceSessionId == item.sourceSessionId,
                          ))
                        Text(
                          t(lv('leave.review.rowConflict'), {
                            'count': request.studentConflicts
                                .where(
                                  (c) =>
                                      c.sourceSessionId == item.sourceSessionId,
                                )
                                .length,
                          }),
                          key: Key(
                            '$prefix-session-conflict-${item.sourceSessionId}',
                          ),
                          style: MdyType.size(13).copyWith(color: c.danger),
                        ),
                    ],
                  ),
                LeaveMore(query: query, controller: controller, prefix: prefix),
                if (manager || request.status == LeaveStatus.APPROVED)
                  for (final e in request.classExtensions)
                    line(
                      '${t(lv('leave.review.classEnd'))}${className(e.classId) == null ? '' : ' · ${className(e.classId)}'}: ${dateLabel(e.endDate)}',
                      key: Key('$prefix-class-end-${e.classId}'),
                      secondary: true,
                    ),
                if (request.status == LeaveStatus.APPROVED)
                  line(t(lv('leave.detail.currentNote')), secondary: true),
                if (manager && _replacements != null) ...[
                  Semantics(
                    header: true,
                    child: line(t(lv('leave.review.check'))),
                  ),
                  for (final s in _replacements!)
                    MdyButton(
                      key: Key('leave-review-replacement-${s.id}'),
                      variant: MdyButtonVariant.secondary,
                      label: '${s.title} · ${slotLabel(s)}',
                      onPressed: () => session(s.id),
                    ),
                ],
              ],
            ],
          ),
        ),
        if (sheet == null)
          LeaveOutcomeError(result: _mutation.result, prefix: prefix),
      ],
    );
  }
}
