import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_logic.dart';
import '../attendance/attendance_widgets.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'operations_query.dart';
import 'operations_service.dart';
import 'operations_widgets.dart';

enum SessionFormMode { assign, reschedule, replacement }

/// Route xung đột học bù (module leave gán khi port xong).
String makeupConflictsRoute = Routes.managerMakeup;

/// Clone `operations/screens/SessionScreens.tsx`: Phân công dạy thay / Dời buổi / Hủy + tạo buổi thay.
class StaffSessionFormScreen extends ConsumerStatefulWidget {
  const StaffSessionFormScreen({
    super.key,
    required this.sessionId,
    required this.mode,
    this.classTitle,
  });
  final String sessionId;
  final SessionFormMode mode;
  final String? classTitle;

  @override
  ConsumerState<StaffSessionFormScreen> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<StaffSessionFormScreen> {
  late final OpsMutator _mutation = OpsMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _search = TextEditingController();
  final _reason = TextEditingController(),
      _clearReason = TextEditingController(),
      _title = TextEditingController();
  final _start = TextEditingController(), _end = TextEditingController();
  final _reasonFocus = FocusNode();
  String _debounced = '';
  Timer? _debounce;
  OpsSession? _cancelled;
  OpsCandidate? _selected;
  String? _date;
  bool _titleTouched = false, _startTouched = false, _endTouched = false;
  bool _invalid = false,
      _confirmation = false,
      _clearSheet = false,
      _allowLeave = false;
  String? _defaultsFor;

  SessionFormMode get _mode => widget.mode;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_search, _reason, _clearReason, _title, _start, _end]) {
      c.dispose();
    }
    _reasonFocus.dispose();
    super.dispose();
  }

  void _toast(String text) => ref.read(mdyToastProvider.notifier).show(text);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final contextRequest = OpsRequest(
      kind: OpsKind.context,
      id: widget.sessionId,
    );
    final query = ref.watch(opsQueryProvider(contextRequest));
    final queryController = ref.read(opsQueryProvider(contextRequest).notifier);
    final ops = _cancelled ?? query.data?.session;
    final session = ops?.session;
    final classRequest = OpsRequest(kind: OpsKind.klass, id: session?.classId);
    final classQuery = session != null && _mode != SessionFormMode.assign
        ? ref.watch(opsQueryProvider(classRequest))
        : null;
    final classInfo = classQuery?.data?.classInfo;
    final isFuture =
        ops != null &&
        session!.status == SessionStatus.SCHEDULED &&
        session.startsAt.isAfter(ops.asOf);
    final candidatesRequest = OpsRequest(
      kind: OpsKind.candidates,
      id: session?.id,
      search: _debounced,
    );
    final candidates = _mode == SessionFormMode.assign && isFuture
        ? ref.watch(opsQueryProvider(candidatesRequest))
        : null;
    final impactRequest = OpsRequest(
      kind: OpsKind.impact,
      id: session?.id,
      status: session?.status.name,
    );
    final impactEnabled =
        _mode == SessionFormMode.replacement &&
        session != null &&
        const [
          SessionStatus.SCHEDULED,
          SessionStatus.IN_PROGRESS,
        ].contains(session.status);
    final impact = impactEnabled
        ? ref.watch(opsQueryProvider(impactRequest))
        : null;
    final replacement =
        _mode == SessionFormMode.replacement &&
        session?.status == SessionStatus.CANCELLED;
    final prefix = switch (_mode) {
      SessionFormMode.assign => 'substitute',
      SessionFormMode.reschedule => 'reschedule',
      SessionFormMode.replacement => 'replacement',
    };
    final locked = _mutation.busy || _mutation.uncertain;
    final code = _mutation.result != null && !_mutation.result!.success
        ? _mutation.result!.code
        : null;
    final unauthorized =
        _mutation.result?.kind == OpsResultKind.denied ||
        _mutation.result?.kind == OpsResultKind.notFound;
    if (unauthorized &&
        (_reason.text.isNotEmpty ||
            _selected != null ||
            _confirmation ||
            _clearSheet ||
            _cancelled != null)) {
      _reason.clear();
      _clearReason.clear();
      _date = null;
      _selected = null;
      _confirmation = false;
      _clearSheet = false;
      _cancelled = null;
    }
    // Giá trị mặc định của form (RN tính lại mỗi render từ draft ?? session).
    if (session != null) {
      final key = '${session.id}|${session.version}|$replacement';
      if (_defaultsFor != key) {
        _defaultsFor = key;
        if (!_titleTouched) _title.text = session.title;
        if (!_startTouched) {
          _start.text = replacement ? '' : isoTime(session.startsAt);
        }
        if (!_endTouched) {
          _end.text = replacement ? '' : isoTime(session.endsAt);
        }
      }
    }
    String blocked = '';
    if (session != null && ops != null) {
      if ((classInfo != null &&
              const [
                ClassStatus.COMPLETED,
                ClassStatus.CANCELLED,
              ].contains(classInfo.status)) ||
          code == 'CLASS_NOT_EDITABLE') {
        blocked = 'classClosed';
      } else if (_mode == SessionFormMode.assign) {
        if (!isFuture) {
          blocked = session.status == SessionStatus.IN_PROGRESS
              ? 'substitute.started'
              : session.status == SessionStatus.SCHEDULED
              ? 'substitute.past'
              : 'substitute.closed';
        }
      } else if (_mode == SessionFormMode.reschedule) {
        if (!isFuture) {
          blocked = session.status == SessionStatus.SCHEDULED
              ? 'rescheduleScreen.past'
              : 'rescheduleScreen.notScheduled';
        }
      } else if (session.status == SessionStatus.COMPLETED) {
        blocked = 'replacement.completed';
      } else if (replacement &&
          classInfo != null &&
          !const [
            ClassStatus.OPEN,
            ClassStatus.IN_PROGRESS,
          ].contains(classInfo.status)) {
        blocked = 'replacement.classNotOpen';
      }
    }
    final duration = session == null
        ? 0
        : session.endsAt.difference(session.startsAt).inMinutes;
    final date =
        _date ??
        (replacement ? '' : (session == null ? '' : isoDate(session.startsAt)));
    if (replacement) {
      final computed = replacementEnd(_start.text, duration) ?? '';
      if (_end.text != computed) _end.text = computed;
    }
    final title = _title.text;
    final startsAt = parseVietnamTime(date, _start.text),
        endsAt = parseVietnamTime(date, _end.text);
    final startsInstant = startsAt == null ? null : DateTime.parse(startsAt);
    final endsInstant = endsAt == null ? null : DateTime.parse(endsAt);
    final sameSchedule =
        session != null &&
        startsInstant != null &&
        endsInstant != null &&
        startsInstant.isAtSameMomentAs(session.startsAt) &&
        endsInstant.isAtSameMomentAs(session.endsAt);
    final outOfPeriod =
        _mode == SessionFormMode.reschedule &&
        classInfo != null &&
        startsAt != null &&
        (startsAt.substring(0, 10).compareTo(classInfo.startDate) < 0 ||
            startsAt.substring(0, 10).compareTo(classInfo.endDate) > 0);
    final timeError =
        ops == null || validSchedule(date, _start.text, _end.text, ops.asOf)
        ? ''
        : startsInstant != null &&
              endsInstant != null &&
              endsInstant.isAfter(startsInstant)
        ? t(o('startPast'))
        : t(o('timeRange'));
    final versionMismatch =
        _mode == SessionFormMode.assign &&
        session != null &&
        candidates?.data?.sessionVersion != null &&
        session.version != candidates!.data!.sessionVersion;
    if (versionMismatch && !query.busy && !candidates.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        queryController.refresh();
        ref.read(opsQueryProvider(candidatesRequest).notifier).refresh();
      });
    }

    void attempt({bool clearing = false}) {
      setState(() => _invalid = true);
      final reason = (clearing ? _clearReason : _reason).text.trim();
      if (reason.isEmpty || reason.length > 1000) {
        _reasonFocus.requestFocus();
        return;
      }
      if (_mode == SessionFormMode.assign) {
        if ((!clearing && _selected == null) ||
            versionMismatch ||
            candidates?.data == null ||
            candidates?.result?.kind != OpsResultKind.success) {
          return;
        }
      } else if (_mode == SessionFormMode.reschedule || replacement) {
        if (timeError.isNotEmpty ||
            outOfPeriod ||
            (replacement &&
                (title.trim().isEmpty || title.trim().length > 250))) {
          return;
        }
      }
      setState(() => _confirmation = true);
    }

    Future<void> submit({bool retry = false}) async {
      if (session == null ||
          blocked.isNotEmpty ||
          query.offline ||
          unauthorized) {
        return;
      }
      final kind = switch (_mode) {
        SessionFormMode.assign => OpsMutationKind.assign,
        SessionFormMode.reschedule => OpsMutationKind.reschedule,
        SessionFormMode.replacement =>
          replacement ? OpsMutationKind.replace : OpsMutationKind.cancel,
      };
      final result = await _mutation.submit(
        OpsMutation(
          kind: kind,
          id: session.id,
          expectedVersion: _mode == SessionFormMode.assign
              ? (candidates?.data?.sessionVersion ?? session.version)
              : session.version,
          reason: (_clearSheet ? _clearReason : _reason).text.trim(),
          mentorId: _selected?.id,
          clearMentor: kind == OpsMutationKind.assign && _clearSheet,
          startsAt:
              kind == OpsMutationKind.reschedule ||
                  kind == OpsMutationKind.replace
              ? startsAt
              : null,
          endsAt:
              kind == OpsMutationKind.reschedule ||
                  kind == OpsMutationKind.replace
              ? endsAt
              : null,
          classUnitId: kind == OpsMutationKind.replace ? session.unitId : null,
          title: kind == OpsMutationKind.replace ? title.trim() : null,
        ),
        retry: retry,
      );
      if (!mounted || result == null) return;
      setState(() {
        _confirmation = false;
        if (result.kind == OpsResultKind.uncertain) _clearSheet = false;
      });
      final updated = result.data?.session;
      if (result.success && updated != null) {
        if (kind == OpsMutationKind.cancel) {
          setState(() {
            _cancelled = updated;
            _invalid = false;
            _date = null;
            _startTouched = _endTouched = _titleTouched = false;
            _defaultsFor = null;
          });
          _mutation.reset();
          return;
        }
        _allowLeave = true;
        final u = updated.session;
        _toast(
          t(
            o(switch (kind) {
              OpsMutationKind.assign =>
                _clearSheet ? 'substitute.cleared' : 'substitute.assigned',
              OpsMutationKind.reschedule => 'rescheduleScreen.done',
              _ => 'replacement.done',
            }),
            {
              'name': u.effectiveMentor,
              'time':
                  '${isoDate(u.startsAt)} ${isoTime(u.startsAt)}–${isoTime(u.endsAt)}',
            },
          ),
        );
        final end = result.data?.classEndDate;
        if (kind == OpsMutationKind.replace &&
            end != null &&
            classInfo != null &&
            end.compareTo(classInfo.endDate) > 0) {
          _toast(
            '${t(o('replacement.done'))} · ${t(o('replacement.doneExtended'), {'date': end})}',
          );
        }
        if (!mounted || !context.mounted) return;
        if (kind == OpsMutationKind.replace) {
          context.replace(
            Routes.managerSession(u.id, classTitle: widget.classTitle),
          );
        } else {
          staffBack(context, manager: true);
        }
      } else if (result.kind == OpsResultKind.error) {
        if (result.code == 'SESSION_VERSION_CONFLICT' ||
            result.code == 'SESSION_STATE_CONFLICT') {
          setState(() => _cancelled = null);
          await queryController.refresh();
        }
        if (_mode == SessionFormMode.assign &&
            const [
              'SESSION_VERSION_CONFLICT',
              'CLASS_MENTOR_SCHEDULE_CONFLICT',
              'CLASS_MENTOR_NOT_ELIGIBLE',
            ].contains(result.code)) {
          setState(() => _selected = null);
          await ref
              .read(opsQueryProvider(candidatesRequest).notifier)
              .refresh();
        }
      }
    }

    final actionLabel = switch (_mode) {
      SessionFormMode.assign => 'substitute.submit',
      SessionFormMode.reschedule => 'rescheduleScreen.submit',
      SessionFormMode.replacement =>
        replacement ? 'replacement.submit' : 'replacement.cancelSubmit',
    };
    final destructive = _mode == SessionFormMode.replacement && !replacement;
    final canShow = session != null && blocked.isEmpty && !unauthorized;
    final dirty =
        _reason.text.isNotEmpty ||
        _clearReason.text.isNotEmpty ||
        _selected != null ||
        _date != null ||
        _startTouched ||
        _endTouched ||
        _titleTouched;

    List<Widget> modeBody(TeachingSession s, DateTime asOf) {
      if (_mode == SessionFormMode.assign) {
        final cq = candidates;
        return [
          MdyText(
            t(o('substitute.primary'), {
              'name': s.primaryMentor ?? t(o('cash.noName')),
            }),
          ),
          if (s.assignment == SessionAssignment.SUBSTITUTE)
            MdyButton(
              key: const Key('substitute-clear'),
              variant: MdyButtonVariant.secondary,
              disabled: locked || query.offline,
              label: t(o('substitute.clear')),
              onPressed: () => setState(() {
                _clearSheet = true;
                _invalid = false;
              }),
            ),
          AttendanceField(
            id: 'substitute-search',
            label: t(o('substitute.search')),
            controller: _search,
            multiline: false,
            disabled: locked || query.offline,
            onChanged: (v) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _debounced = v.trim());
              });
            },
          ),
          if (_selected != null)
            MdyText(
              t(o('substitute.selected'), {'name': _selected!.name}),
              key: const Key('substitute-selected'),
            ),
          if (cq != null)
            OpsQueryBlock(
              query: cq,
              controller: ref.read(
                opsQueryProvider(candidatesRequest).notifier,
              ),
              prefix: 'substitute-candidates',
              builder: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: MdyText(
                      t(
                        o(
                          _search.text.isNotEmpty
                              ? 'substitute.results'
                              : 'substitute.available',
                        ),
                        {'count': cq.data?.total},
                      ),
                    ),
                  ),
                  Text(
                    t(o('substitute.basis')),
                    style: MdyType.size(12).copyWith(color: c.secondary),
                  ),
                  Text(
                    t(o('substitute.checkedAt'), {
                      'time': cq.data == null ? '' : isoTime(cq.data!.asOf),
                    }),
                    style: MdyType.size(12).copyWith(color: c.ink),
                  ),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    gap: 0,
                    children: [
                      for (final m
                          in cq.data?.candidates ?? const <OpsCandidate>[])
                        Semantics(
                          inMutuallyExclusiveGroup: true,
                          checked: _selected?.id == m.id,
                          enabled: !(m.isCurrent || locked || query.offline),
                          label: m.name ?? t(o('cash.noName')),
                          excludeSemantics: true,
                          child: MdyPressed(
                            key: Key('substitute-mentor-${m.id}'),
                            enabled: !(m.isCurrent || locked || query.offline),
                            onTap: () => setState(() => _selected = m),
                            builder: (context, _) => Container(
                              constraints: const BoxConstraints(
                                minHeight: MdySpace.s56,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: MdySpace.s12,
                              ),
                              child: Row(
                                spacing: MdySpace.s12,
                                children: [
                                  MdyAvatar(
                                    name: m.name ?? t(o('cash.noName')),
                                  ),
                                  Expanded(
                                    child: MdyText(
                                      m.name ?? t(o('cash.noName')),
                                    ),
                                  ),
                                  if (m.isCurrent)
                                    MdyChip(
                                      t(o('substitute.isCurrent')),
                                      variant: MdyChipVariant.info,
                                    )
                                  else
                                    MdyText(_selected?.id == m.id ? '◉' : '○'),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (cq.data?.total == 0)
                    MdyText(
                      t(
                        o(
                          _search.text.isNotEmpty
                              ? 'substitute.noResult'
                              : 'substitute.empty',
                        ),
                      ),
                      key: Key(
                        _search.text.isNotEmpty
                            ? 'substitute-no-result'
                            : 'substitute-empty',
                      ),
                    ),
                  OpsMore(
                    query: cq,
                    controller: ref.read(
                      opsQueryProvider(candidatesRequest).notifier,
                    ),
                    prefix: 'substitute',
                  ),
                ],
              ),
            ),
          if (_invalid && _selected == null)
            Semantics(
              liveRegion: true,
              child: Text(
                t(o('substitute.selectRequired')),
                style: MdyType.text.copyWith(color: c.danger),
              ),
            ),
        ];
      }
      if (_mode == SessionFormMode.reschedule || replacement) {
        final minDate = asOf
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(0, 10);
        final minutes = startsInstant != null && endsInstant != null
            ? endsInstant.difference(startsInstant).inMinutes
            : duration;
        return [
          if (_cancelled != null) ...[
            Semantics(
              label: t(o('replacement.stepReplace')),
              excludeSemantics: true,
              child: MdyText(
                '${t(o('replacement.stepCancel'))} ✓ — ${t(o('replacement.stepReplace'))}',
              ),
            ),
            OpsAlert(
              key: const Key('replacement-cancelled'),
              warning: true,
              children: [MdyText(t(o('replacement.cancelled')))],
            ),
          ],
          if (replacement)
            AttendanceField(
              id: 'replacement-title',
              label: t(o('replacement.name')),
              controller: _title,
              max: 250,
              multiline: false,
              disabled: locked,
              onChanged: (_) => setState(() => _titleTouched = true),
              error: _invalid && title.trim().isEmpty
                  ? t(o('replacement.nameRequired'))
                  : null,
            ),
          OpsScheduleFields(
            prefix: prefix,
            date: date,
            start: _start,
            end: _end,
            onDate: (v) => setState(() => _date = v),
            onChanged: () => setState(() {
              _startTouched = true;
              _endTouched = true;
            }),
            disabled: locked || code == 'MAKEUP_ALREADY_EXISTS',
            readOnlyEnd: replacement,
            minDate: minDate,
            maxDate: !replacement && classInfo != null
                ? classInfo.endDate
                : null,
            invalid: _invalid
                ? (timeError.isNotEmpty
                      ? timeError
                      : (outOfPeriod ? t(o('outsidePeriod')) : null))
                : null,
          ),
          if (outOfPeriod && _invalid)
            Text(
              t(o('outsidePeriod')),
              style: MdyType.text.copyWith(color: c.danger),
            ),
          MdyText(
            t(
              o(
                replacement
                    ? 'replacement.keepDuration'
                    : 'rescheduleScreen.duration',
              ),
              {'minutes': minutes},
            ),
            key: Key('$prefix-duration'),
          ),
          MdyText(
            t(
              o(
                replacement
                    ? 'replacement.noCopy'
                    : 'rescheduleScreen.keepTeacher',
              ),
              {'name': s.primaryMentor ?? t(o('cash.noName'))},
            ),
            key: Key(
              replacement ? 'replacement-no-copy' : 'reschedule-keep-teacher',
            ),
          ),
          if (classQuery?.result?.kind == OpsResultKind.error && !replacement)
            MdyText(
              t(o('rescheduleScreen.classUnknown')),
              key: const Key('reschedule-class-unknown'),
            ),
          if (replacement &&
              classInfo != null &&
              startsAt != null &&
              startsAt.substring(0, 10).compareTo(classInfo.endDate) > 0)
            MdyText(
              t(o('replacement.extend'), {'date': date}),
              key: const Key('replacement-extend'),
            ),
        ];
      }
      return [
        if (s.status == SessionStatus.IN_PROGRESS)
          OpsAlert(
            key: const Key('replacement-in-progress'),
            warning: true,
            children: [MdyText(t(o('replacement.inProgress')))],
          ),
        MdyCard(
          key: const Key('replacement-scope'),
          margin: EdgeInsets.zero,
          gap: MdySpace.s8,
          children: [
            Text(
              t(o('replacement.scope')),
              style: MdyType.text.copyWith(
                fontWeight: MdyType.w600,
                color: c.ink,
              ),
            ),
            if (impact?.data?.impact case final i?)
              MdyText(
                t(
                  o(
                    i.present != null
                        ? 'replacement.totals'
                        : 'replacement.candidates',
                  ),
                  {
                    'count': i.total,
                    'eligible': i.total,
                    'present': i.present,
                    'absent': i.absent,
                  },
                ),
                key: const Key('replacement-impact'),
              ),
            MdyText(t(o('replacement.scopeSchedule'))),
            MdyText(t(o('replacement.scopeFinal'))),
          ],
        ),
      ];
    }

    return AttendancePage(
      prefix: prefix,
      title: t(
        o(switch (_mode) {
          SessionFormMode.assign => 'substitute.title',
          SessionFormMode.reschedule => 'rescheduleScreen.title',
          SessionFormMode.replacement =>
            replacement ? 'replacement.title' : 'replacement.cancelTitle',
        }),
      ),
      subtitle: widget.classTitle ?? ops?.classTitle,
      onBack: () => staffBack(context, manager: true),
      dirty: dirty,
      busy: _mutation.busy,
      uncertain: _mutation.uncertain,
      allowLeave: _allowLeave,
      refresh: () async {
        await queryController.refresh();
      },
      footer: canShow
          ? [
              MdyButton(
                key: Key('$prefix-submit'),
                variant: destructive
                    ? MdyButtonVariant.danger
                    : MdyButtonVariant.primary,
                disabled:
                    locked ||
                    query.offline ||
                    versionMismatch ||
                    (_mode == SessionFormMode.assign &&
                        (candidates?.data == null ||
                            candidates?.result?.kind !=
                                OpsResultKind.success)) ||
                    (_mode == SessionFormMode.reschedule && sameSchedule) ||
                    code == 'MAKEUP_ALREADY_EXISTS' ||
                    _reason.text.length > 1000,
                busy: _mutation.busy,
                label: t(o(actionLabel)),
                onPressed: attempt,
              ),
              if (_cancelled != null)
                MdyButton(
                  key: const Key('replacement-later'),
                  variant: MdyButtonVariant.text,
                  disabled: locked,
                  label: t(o('replacement.later')),
                  onPressed: () => staffBack(context, manager: true),
                ),
            ]
          : null,
      overlays: [
        if (_clearSheet && !unauthorized)
          MdyInlineSheet(
            key: const Key('substitute-clear-sheet'),
            title: t(o('substitute.clear')),
            busy: locked,
            onClose: () => setState(() => _clearSheet = false),
            children: [
              MdyText(
                t(o('substitute.clearBody'), {
                  'current': session?.effectiveMentor,
                  'primary': session?.primaryMentor,
                }),
              ),
              AttendanceField(
                id: 'substitute-clear-reason',
                label: t(o('reason')),
                controller: _clearReason,
                onChanged: (_) => setState(() {}),
                max: 1000,
                disabled: locked,
                error: _invalid && _clearReason.text.trim().isEmpty
                    ? t(o('reasonRequired'))
                    : null,
              ),
              MdyButton(
                key: const Key('substitute-clear-submit'),
                disabled: locked || query.offline,
                label: t(o('substitute.clearSubmit')),
                onPressed: () => attempt(clearing: true),
              ),
            ],
          ),
        if (_confirmation)
          MdyInlineDialog(
            key: Key('$prefix-confirm'),
            icon: switch (_mode) {
              SessionFormMode.assign => MdyIcons.swapHoriz,
              SessionFormMode.replacement => MdyIcons.eventBusy,
              SessionFormMode.reschedule => MdyIcons.calendarMonth,
            },
            title: t(
              o(switch (_mode) {
                SessionFormMode.assign =>
                  _clearSheet ? 'substitute.clear' : 'substitute.confirmTitle',
                SessionFormMode.reschedule => 'rescheduleScreen.confirmTitle',
                SessionFormMode.replacement =>
                  replacement
                      ? 'replacement.confirmTitle'
                      : 'replacement.cancelConfirm',
              }),
              {'name': _selected?.name},
            ),
            busy: locked,
            onClose: () => setState(() => _confirmation = false),
            children: [
              if (_mode == SessionFormMode.reschedule && session != null) ...[
                MdyText(
                  t(o('rescheduleScreen.from'), {
                    'time':
                        '${isoDate(session.startsAt)} ${isoTime(session.startsAt)}–${isoTime(session.endsAt)}',
                  }),
                  key: const Key('reschedule-from'),
                ),
                MdyText(
                  t(o('rescheduleScreen.to'), {
                    'time': '$date ${_start.text}–${_end.text}',
                  }),
                  key: const Key('reschedule-to'),
                ),
                MdyText(t(o('rescheduleScreen.confirmBody'))),
              ] else
                MdyText(
                  t(
                    o(switch (_mode) {
                      SessionFormMode.assign =>
                        _clearSheet
                            ? 'substitute.clearBody'
                            : 'substitute.confirmBody',
                      _ =>
                        replacement
                            ? 'replacement.confirmBody'
                            : 'replacement.cancelBody',
                    }),
                    {
                      'name': _selected?.name,
                      'current': session?.effectiveMentor,
                      'primary': session?.primaryMentor,
                      'session': replacement ? title : session?.title,
                      'time': '$date ${_start.text}–${_end.text}',
                      'date': session == null ? '' : isoDate(session.startsAt),
                    },
                  ),
                  textAlign: TextAlign.center,
                ),
              MdyButton(
                key: Key('$prefix-confirm-submit'),
                variant: destructive
                    ? MdyButtonVariant.danger
                    : MdyButtonVariant.primary,
                disabled: _mutation.busy || _mutation.uncertain,
                busy: _mutation.busy,
                label: t(o(actionLabel)),
                onPressed: submit,
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                disabled: locked,
                label: t(o('substitute.back')),
                onPressed: () => setState(() => _confirmation = false),
              ),
            ],
          ),
      ],
      children: [
        if (unauthorized)
          MdyCard(
            key: Key('$prefix-unauthorized'),
            margin: EdgeInsets.zero,
            children: [
              MdyText(
                t(
                  o(
                    _mutation.result?.kind == OpsResultKind.denied
                        ? 'denied'
                        : 'notFound',
                  ),
                ),
              ),
            ],
          )
        else
          OpsQueryBlock(
            query: query,
            controller: queryController,
            prefix: prefix,
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s20,
              children: [
                if (session != null)
                  OpsSessionSummary(session: session, prefix: prefix),
                if (blocked.isNotEmpty)
                  MdyCard(
                    key: Key('$prefix-blocked'),
                    margin: EdgeInsets.zero,
                    children: [MdyText(t(o(blocked)))],
                  )
                else if (session != null && ops != null) ...[
                  ...modeBody(session, ops.asOf),
                  OpsReasonField(
                    prefix: destructive ? 'replacement-cancel' : prefix,
                    controller: _reason,
                    focusNode: _reasonFocus,
                    onChanged: () => setState(() {}),
                    invalid: _invalid,
                    disabled: locked || code == 'MAKEUP_ALREADY_EXISTS',
                  ),
                  OpsMutationError(prefix: prefix, result: _mutation.result),
                  if (code == 'SESSION_HAS_MAKEUP_PLACEMENTS')
                    MdyButton(
                      key: const Key('session-form-placements'),
                      variant: MdyButtonVariant.secondary,
                      label: t(o('placements')),
                      onPressed: () => context.push(makeupConflictsRoute),
                    ),
                  if (code == 'MAKEUP_ALREADY_EXISTS')
                    MdyButton(
                      key: const Key('replacement-open-schedule'),
                      variant: MdyButtonVariant.secondary,
                      label: t(o('replacement.openSchedule')),
                      onPressed: () =>
                          context.push(Routes.managerClass(session.classId)),
                    ),
                  if (_mutation.uncertain)
                    IntentBanner(
                      prefix: prefix,
                      busy: _mutation.busy,
                      offline: query.offline,
                      onRetry: () => submit(retry: true),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
