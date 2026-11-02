import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import 'leave_list_screens.dart';
import 'leave_query.dart';
import 'leave_service.dart';
import 'leave_widgets.dart';

/// `MakeupPlacementScreen.tsx`: tìm conflict qua các trang; xác nhận nội dung trước khi xếp.
class StaffMakeupPlacementScreen extends ConsumerStatefulWidget {
  const StaffMakeupPlacementScreen({
    super.key,
    required this.conflictId,
    required this.classId,
  });
  final String conflictId, classId;

  @override
  ConsumerState<StaffMakeupPlacementScreen> createState() => _PlacementState();
}

class _PlacementState extends ConsumerState<StaffMakeupPlacementScreen> {
  static const _prefix = 'makeup-placement';
  Conflict? _conflict;
  LeaveOutcome? _result;
  bool _finding = true, _cancel = false, _checked = false;
  Candidate? _picked;
  SourceSession? _placed;
  int _epoch = 0, _captured = 0;
  final _reason = TextEditingController();
  late final _mutation = LeaveMutator(ref, () {
    if (mounted) setState(() {});
  });
  late final AppLifecycleListener _life;
  LeaveReadRequest get _candidates => LeaveReadRequest(
    kind: LeaveKind.candidates,
    role: LeaveRole.MANAGER,
    id: widget.conflictId,
  );

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => unawaited(_find()));
    Future.microtask(_find);
  }

  @override
  void dispose() {
    _epoch++;
    _life.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (!mounted) return;
    final ticket = ++_epoch;
    final service = ref.read(leaveServiceProvider);
    setState(() => _finding = true);
    if (ref.read(staffOfflineProvider)) {
      setState(() {
        _finding = false;
        _result = const LeaveOutcome(LeaveOutcomeKind.offline);
      });
      return;
    }
    LeaveOutcome result = const LeaveOutcome(LeaveOutcomeKind.notFound);
    Conflict? found;
    var page = 1, loaded = 0;
    while (true) {
      result = await service.read(
        LeaveReadRequest(
          kind: LeaveKind.conflicts,
          role: LeaveRole.MANAGER,
          classId: widget.classId,
          pageSize: 100,
          page: page,
        ),
      );
      if (!mounted || ticket != _epoch) return;
      if (!result.success) break;
      final rows = result.data?.conflicts ?? const <Conflict>[];
      found = rows.where((c) => c.id == widget.conflictId).firstOrNull;
      loaded += rows.length;
      if (found != null || loaded >= result.data!.total || rows.isEmpty) break;
      page++;
    }
    if (!mounted || ticket != _epoch) return;
    if (found == null && result.success) {
      result = const LeaveOutcome(LeaveOutcomeKind.notFound);
    }
    setState(() {
      _result = result;
      _finding = false;
      if (found != null) {
        _conflict = found;
      } else if (result.kind == LeaveOutcomeKind.denied ||
          result.kind == LeaveOutcomeKind.notFound) {
        _conflict = null;
        _reason.clear();
        _picked = null;
        _cancel = false;
      }
    });
  }

  Future<void> _send() async {
    final conflict = _conflict, picked = _picked;
    if (conflict == null ||
        !validReason(_reason.text) ||
        (!_cancel && (picked == null || !_checked))) {
      return;
    }
    if (_cancel &&
        (conflict.placementId == null || conflict.placementVersion == null)) {
      await _find();
      return;
    }
    final cancelling = _cancel;
    final t = ref.read(trProvider);
    final controller = cancelling
        ? null
        : ref.read(leaveQueryProvider(_candidates).notifier);
    final result = await _mutation.submit(
      LeaveIntent(
        kind: cancelling ? LeaveIntentKind.cancel : LeaveIntentKind.place,
        role: LeaveRole.MANAGER,
        id: cancelling ? conflict.placementId : conflict.id,
        reason: _reason.text.trim(),
        expectedVersion: _captured,
        targetSessionId: cancelling ? null : picked!.session.id,
        expectedTargetVersion: cancelling ? null : picked!.session.version,
      ),
      offline: _result?.kind == LeaveOutcomeKind.offline,
    );
    if (!mounted || result == null) return;
    if (result.success) {
      setState(() {
        _placed = result.data?.placedSession;
        _picked = null;
        _cancel = false;
        _checked = false;
        _reason.clear();
      });
      ref
          .read(mdyToastProvider.notifier)
          .show(
            t(
              lv(cancelling ? 'makeup.place.cancelled' : 'makeup.place.placed'),
            ),
          );
      await _find();
    } else if (result.kind == LeaveOutcomeKind.error) {
      setState(() => _checked = false);
      await _find();
      if (!mounted) return;
      await controller?.refresh();
      if (!mounted) return;
      if (const [
        'MAKEUP_ALREADY_ASSIGNED',
        'MAKEUP_STATE_CONFLICT',
        'MAKEUP_NOT_ELIGIBLE',
      ].contains(result.code)) {
        setState(() {
          _picked = null;
          _cancel = false;
        });
      }
    } else if (result.kind == LeaveOutcomeKind.denied) {
      setState(() {
        _conflict = null;
        _reason.clear();
        _picked = null;
        _cancel = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), c = context.mdy;
    ref.listen(leaveRevisionProvider, (_, _) {
      unawaited(_find());
    });
    ref.listen(staffOfflineProvider, (_, _) {
      unawaited(_find());
    });
    final conflict = _conflict;
    final mode = conflict == null ? null : conflictMode(conflict);
    final candidates =
        conflict != null &&
            mode == 'NEEDS_PLACEMENT' &&
            _result?.success == true
        ? ref.watch(leaveQueryProvider(_candidates))
        : null;
    final controller = candidates == null
        ? null
        : ref.read(leaveQueryProvider(_candidates).notifier);
    const classRequest = LeaveReadRequest(
      kind: LeaveKind.classes,
      role: LeaveRole.MANAGER,
      pageSize: 100,
    );
    final classes = ref.watch(leaveQueryProvider(classRequest));
    drainLeaveOptions(
      classes,
      ref.read(leaveQueryProvider(classRequest).notifier),
    );
    String? name(String id) =>
        classes.data?.options?.where((c) => c.id == id).firstOrNull?.name;
    final offline =
        ref.watch(staffOfflineProvider) ||
        _result?.kind == LeaveOutcomeKind.offline;
    final safe = !offline && !_finding && _result?.success == true;
    final locked = _mutation.busy || _mutation.uncertain;
    final picked = _picked;
    void close() => setState(() {
      _picked = null;
      _cancel = false;
    });
    Widget text(String value, {Key? key, bool heading = false, Color? color}) =>
        Text(
          value,
          key: key,
          style: MdyType.size(
            heading ? 14 : 13,
            heading ? MdyType.w600 : MdyType.w400,
          ).copyWith(color: color ?? c.ink),
        );
    return LeavePage(
      prefix: _prefix,
      title: t(lv('makeup.place.title')),
      onBack: () => staffBack(context, manager: true),
      dirty: _reason.text.isNotEmpty,
      busy: _mutation.busy,
      uncertain: _mutation.uncertain,
      refresh: () async {
        await _find();
        if (mounted) await controller?.refresh();
      },
      onEnd: () {
        if (mode == 'NEEDS_PLACEMENT' && candidates?.footerError == false) {
          controller?.more();
        }
      },
      onOverlayBack: close,
      overlays: [
        if (picked != null || _cancel)
          MdyInlineSheet(
            key: Key('$_prefix-${_cancel ? 'cancel' : 'confirm'}-sheet'),
            title: t(
              lv(
                _cancel
                    ? 'makeup.place.cancelTitle'
                    : 'makeup.place.confirmTitle',
              ),
            ),
            busy: locked,
            onClose: close,
            children: [
              if (_cancel)
                text(t(lv('makeup.place.cancelBody')))
              else if (picked != null) ...[
                text(
                  t(lv('makeup.place.willJoin'), {
                    'student': conflict?.studentName ?? t(lv('mentorMissing')),
                  }),
                ),
                text(picked.session.title, heading: true),
                text(slotLabel(picked.session)),
                Semantics(
                  checked: _checked,
                  enabled: !locked,
                  label: t(lv('makeup.place.contentCheck')),
                  excludeSemantics: true,
                  child: MdyPressed(
                    key: const Key('$_prefix-content-check'),
                    enabled: !locked,
                    onTap: () => setState(() => _checked = !_checked),
                    builder: (context, pressed) => Opacity(
                      opacity: pressed ? .8 : 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: MdySpace.s44,
                        ),
                        child: Row(
                          spacing: MdySpace.s10,
                          children: [
                            Text(
                              _checked ? '☑' : '☐',
                              style: MdyType.size(18).copyWith(color: c.link),
                            ),
                            Expanded(
                              child: text(t(lv('makeup.place.contentCheck'))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              LeaveField(
                id: '$_prefix-${_cancel ? 'cancel-reason' : 'reason'}',
                label: t(lv('leave.reason')),
                controller: _reason,
                max: 1000,
                disabled: locked,
                onChanged: (_) => setState(() {}),
              ),
              if (!_cancel)
                text(t(lv('makeup.place.scopeNote')), color: c.secondary),
              if (!safe) text(t(lv('leave.needOnline'))),
              LeaveOutcomeError(
                result: _mutation.result,
                prefix: _prefix,
                retry: _send,
              ),
              if (!_mutation.uncertain)
                MdyButton(
                  key: Key('$_prefix-${_cancel ? 'cancel-send' : 'submit'}'),
                  variant: _cancel
                      ? MdyButtonVariant.danger
                      : MdyButtonVariant.primary,
                  busy: _mutation.busy,
                  disabled:
                      !safe ||
                      !validReason(_reason.text) ||
                      (!_cancel && !_checked),
                  label: t(
                    lv(_cancel ? 'makeup.place.cancel' : 'makeup.place.submit'),
                  ),
                  onPressed: _send,
                ),
              MdyButton(
                variant: MdyButtonVariant.text,
                disabled: locked,
                label: t(lv('back')),
                onPressed: close,
              ),
            ],
          ),
      ],
      children: [
        if (_result?.kind == LeaveOutcomeKind.denied ||
            _result?.kind == LeaveOutcomeKind.notFound)
          MdyCard(
            key: Key(
              '$_prefix-${_result!.kind == LeaveOutcomeKind.denied ? 'denied' : 'not-found'}',
            ),
            margin: EdgeInsets.zero,
            children: [
              text(
                t(
                  lv(
                    _result!.kind == LeaveOutcomeKind.denied
                        ? 'denied'
                        : 'makeup.place.notFound',
                  ),
                ),
              ),
            ],
          )
        else if (conflict == null) ...[
          if (_finding)
            const LeaveLoading()
          else
            MdyCard(
              key: Key('$_prefix-${offline ? 'offline' : 'error'}'),
              margin: EdgeInsets.zero,
              children: [
                text(t(lv(offline ? 'leave.offlineEmpty' : 'error'))),
                if (!offline)
                  MdyButton(
                    key: const Key('$_prefix-retry'),
                    label: t(lv('retry')),
                    onPressed: _find,
                  ),
              ],
            ),
        ] else ...[
          KeyedSubtree(
            key: const Key('$_prefix-student'),
            child: ConflictCard(
              item: conflict,
              prefix: _prefix,
              className: name(conflict.source.classId),
            ),
          ),
          if (mode == 'NEEDS_PLACEMENT') ...[
            Semantics(
              header: true,
              child: text(
                t(lv('makeup.place.pickSection'), {
                  'count': candidates?.data?.total ?? 0,
                }),
                heading: true,
              ),
            ),
            text(t(lv('makeup.place.pickHint')), color: c.secondary),
            if (candidates?.result?.code == 'MAKEUP_NOT_ELIGIBLE')
              LeaveNotice(
                t(lv('makeup.place.notEligiblePending')),
                key: const Key('$_prefix-not-eligible'),
                warning: true,
              )
            else if (candidates != null && controller != null)
              LeaveQueryBlock(
                query: candidates,
                controller: controller,
                prefix: '$_prefix-candidates',
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: MdySpace.s16,
                  children: [
                    for (final candidate
                        in candidates.data?.candidates ?? const <Candidate>[])
                      Semantics(
                        button: true,
                        child: MdyPressed(
                          key: Key(
                            '$_prefix-candidate-${candidate.session.id}',
                          ),
                          enabled: safe && !locked,
                          onTap: () {
                            _mutation.clear();
                            setState(() {
                              _captured = conflict.version;
                              _picked = candidate;
                              _checked = false;
                            });
                          },
                          builder: (context, pressed) => Opacity(
                            opacity: pressed ? .8 : 1,
                            child: MdyCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(MdySpace.s16),
                              gap: MdySpace.s8,
                              children: [
                                if (name(candidate.session.classId)
                                    case final className?)
                                  text(className, color: c.secondary),
                                text(candidate.session.title, heading: true),
                                text(slotLabel(candidate.session)),
                                text(
                                  candidate.mentorName ?? t(lv('noMentor')),
                                  color: c.secondary,
                                ),
                                text(
                                  t(lv('makeup.place.seats'), {
                                    'count': candidate.remainingCapacity,
                                  }),
                                  key: Key(
                                    '$_prefix-candidate-seats-${candidate.session.id}',
                                  ),
                                  color: c.success,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (candidates.data?.total == 0)
                      MdyCard(
                        key: const Key('$_prefix-no-candidates'),
                        margin: EdgeInsets.zero,
                        children: [text(t(lv('makeup.place.noCandidates')))],
                      ),
                    LeaveMore(
                      query: candidates,
                      controller: controller,
                      prefix: _prefix,
                    ),
                  ],
                ),
              ),
          ] else ...[
            if (mode == 'NEEDS_REASSIGNMENT')
              LeaveNotice(
                t(lv('makeup.place.reassignNote')),
                key: const Key('$_prefix-reassign-note'),
                warning: true,
              ),
            if (_placed case final placed?)
              MdyCard(
                key: const Key('$_prefix-placed'),
                margin: EdgeInsets.zero,
                children: [
                  text(t(lv('makeup.place.placedSection'))),
                  text(placed.title),
                  text(slotLabel(placed)),
                ],
              )
            else
              LeaveNotice(
                t(lv('makeup.place.placedUnknown')),
                key: const Key('$_prefix-placed-unknown'),
              ),
            if (mode != 'RESOLVED')
              MdyButton(
                key: const Key('$_prefix-cancel'),
                variant: mode == 'NEEDS_REASSIGNMENT'
                    ? MdyButtonVariant.primary
                    : MdyButtonVariant.secondary,
                disabled: !safe || locked || conflict.placementVersion == null,
                label: t(
                  lv(
                    mode == 'NEEDS_REASSIGNMENT'
                        ? 'makeup.place.cancelReassign'
                        : 'makeup.place.cancel',
                  ),
                ),
                onPressed: () {
                  _mutation.clear();
                  setState(() {
                    _captured = conflict.placementVersion!;
                    _cancel = true;
                  });
                },
              ),
          ],
          if (offline)
            LeaveNotice(
              t(lv('leave.stale')),
              key: const Key('$_prefix-offline'),
              warning: true,
            ),
          if (_result?.kind == LeaveOutcomeKind.error)
            LeaveNotice(t(lv('leave.stale')), warning: true),
        ],
        if (picked == null && !_cancel)
          LeaveOutcomeError(result: _mutation.result, prefix: _prefix),
      ],
    );
  }
}
