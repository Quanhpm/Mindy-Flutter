import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import '../teaching/classes_screens.dart';
import '../teaching/session_context_screen.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';
import 'manager_attendance_screens.dart';

String _a(String key) => 'mdy.attendance.$key';

typedef _Selection = ({RecoveryStudent student, Mark? status});

/// Định dạng `DD/MM/YYYY` khi gõ.
final _dateFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  var v = newValue.text.replaceAll(RegExp(r'[^\d/]'), '');
  v = v.replaceFirstMapped(RegExp(r'^(\d{2})(\d)'), (m) => '${m[1]}/${m[2]}');
  v = v.replaceFirstMapped(RegExp(r'^(\d{2}/\d{2})(\d)'), (m) => '${m[1]}/${m[2]}');
  if (v.length > 10) v = v.substring(0, 10);
  return TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
});

/// Clone `AttendanceRecoveryScreen.tsx` (+ View trong tab Khôi phục của chi tiết buổi).
class AttendanceRecoveryView extends ConsumerStatefulWidget {
  const AttendanceRecoveryView({
    super.key,
    required this.sessionId,
    required this.onBack,
    this.classTitle,
    this.enrollmentId,
    this.onSaved,
    this.detailTabs,
  });

  final String sessionId;
  final String? classTitle;
  final String? enrollmentId;
  final VoidCallback onBack;
  final VoidCallback? onSaved;
  final StaffDetailTabs? detailTabs;

  @override
  ConsumerState<AttendanceRecoveryView> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<AttendanceRecoveryView> {
  late final AttendanceMutator _mutation = AttendanceMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _date = TextEditingController(), _start = TextEditingController(), _end = TextEditingController();
  final _evidence = TextEditingController(), _reason = TextEditingController(), _search = TextEditingController();
  final _dateFocus = FocusNode(), _evidenceFocus = FocusNode(), _reasonFocus = FocusNode();
  late bool _picker = widget.enrollmentId == null;
  AttendanceData? _review;
  Map<String, _Selection> _selected = {};
  bool _invalid = false, _noLonger = false, _saved = false;
  String _feedback = '';
  String? _timesFor;
  DateTime? _asOf, _asOfReceived;
  bool _preselected = false;
  late final Timer _tick;

  AttendanceRequest get _context => AttendanceRequest(kind: AttendanceKind.context, role: TeachingRole.MANAGER, sessionId: widget.sessionId);
  AttendanceRequest get _permissions =>
      AttendanceRequest(kind: AttendanceKind.attendance, role: TeachingRole.MANAGER, sessionId: widget.sessionId, pageSize: 1);
  AttendanceRequest _students(String classId) => AttendanceRequest(
    kind: AttendanceKind.recoveryStudents,
    role: TeachingRole.MANAGER,
    sessionId: widget.sessionId,
    classId: classId,
    pageSize: 100,
  );
  AttendanceRequest get _existing => AttendanceRequest(
    kind: AttendanceKind.attendance,
    role: TeachingRole.MANAGER,
    sessionId: widget.sessionId,
    pageSize: 100,
    all: true,
  );

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    for (final c in [_date, _start, _end, _evidence, _reason, _search]) {
      c.dispose();
    }
    for (final f in [_dateFocus, _evidenceFocus, _reasonFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _toast(String text) => ref.read(mdyToastProvider.notifier).show(text);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(attendanceQueryProvider(_context));
    final permissions = ref.watch(attendanceQueryProvider(_permissions));
    final session = permissions.data?.session ?? query.data?.session;
    if (session != null && session.asOf != _asOf) {
      _asOf = session.asOf;
      _asOfReceived = DateTime.now();
    }
    final now = serverNow(session?.asOf, _asOfReceived ?? DateTime.now());
    // Điền ngày/giờ mặc định theo buổi (giờ thực tế nếu đã có).
    if (session != null) {
      final key = '${session.startsAt}|${session.endsAt}|${session.actualStartedAt}|${session.actualEndedAt}';
      if (_timesFor != key) {
        _timesFor = key;
        _date.text = isoDate(session.actualStartedAt ?? session.startsAt);
        _start.text = isoTime(session.actualStartedAt ?? session.startsAt);
        _end.text = isoTime(session.actualEndedAt ?? session.endsAt);
      }
    }
    final studentsRequest = session == null ? null : _students(session.classId);
    final studentsEnabled =
        (session?.permissions.canRecover ?? false) && (_picker || widget.enrollmentId != null) && studentsRequest != null;
    final students = studentsEnabled ? ref.watch(attendanceQueryProvider(studentsRequest)) : null;
    if (!_preselected && widget.enrollmentId != null) {
      final student = students?.data?.students.where((s) => s.id == widget.enrollmentId).firstOrNull;
      if (student != null) {
        _preselected = true;
        _selected = {student.id: (student: student, status: null)};
      }
    }
    final existingEnabled = _picker && (permissions.data?.totals?.eligible ?? 0) > 0;
    final existing = existingEnabled ? ref.watch(attendanceQueryProvider(_existing)) : null;
    final locked = _mutation.busy || _mutation.uncertain;
    final denied =
        query.error?.kind == RemoteFailure.denied ||
        permissions.error?.kind == RemoteFailure.denied ||
        _mutation.result?.kind == WriteKind.denied;
    if (denied && (_selected.isNotEmpty || _picker || _review != null)) {
      _evidence.clear();
      _reason.clear();
      _selected = {};
      _picker = false;
      _review = null;
    }
    final canRecover =
        (permissions.data?.session?.permissions.canRecover ?? false) &&
        session != null &&
        !session.endsAt.isAfter(session.asOf) &&
        !_noLonger;
    final started = parseVietnamTime(_date.text, _start.text), ended = parseVietnamTime(_date.text, _end.text);
    final startedAt = started == null ? null : DateTime.tryParse(started);
    final endedAt = ended == null ? null : DateTime.tryParse(ended);
    final timeValid =
        startedAt != null && endedAt != null && endedAt.isAfter(startedAt) && session != null && !endedAt.isAfter(now);
    if (startedAt != null) {
      final kept = {
        for (final e in _selected.entries)
          if (admissionBasis(e.value.student.enrollmentStatus, e.value.student.paymentType, e.value.student.paidAt, startedAt) !=
              null)
            e.key: e.value,
      };
      if (kept.length != _selected.length) _selected = kept;
    }
    final entries = _selected.values.toList();

    AttendanceIntent makeBody([int? version]) => AttendanceIntent(
      key: '',
      kind: IntentKind.recover,
      sessionId: widget.sessionId,
      role: TeachingRole.MANAGER,
      expectedVersion: version ?? session?.version ?? 0,
      reason: _reason.text.trim(),
      evidenceNote: _evidence.text.trim(),
      actualStartedAt: session?.actualStartedAt?.toUtc().toIso8601String() ?? started ?? '',
      actualEndedAt: session?.actualEndedAt?.toUtc().toIso8601String() ?? ended ?? '',
      recoveryRecords: [
        for (final e in entries)
          if (startedAt != null && e.status != null)
            if (admissionBasis(e.student.enrollmentStatus, e.student.paymentType, e.student.paidAt, startedAt)
                case final basis?)
              RecoveryRecord(enrollmentId: e.student.id, status: e.status!, admissionBasis: basis),
      ],
    );
    final tooLarge = recoveryRequestBytes(makeBody()) > 256 * 1024;

    Future<void> openReview() async {
      setState(() => _invalid = true);
      if (!timeValid) {
        _dateFocus.requestFocus();
        return;
      }
      final evidence = _evidence.text.trim(), reason = _reason.text.trim();
      if (evidence.isEmpty || noteLength(evidence) > 2000) {
        _evidenceFocus.requestFocus();
        return;
      }
      if (reason.isEmpty || noteLength(reason) > 1000) {
        _reasonFocus.requestFocus();
        return;
      }
      if (entries.isEmpty || entries.any((e) => e.status == null) || tooLarge) return;
      await ref.read(attendanceQueryProvider(_permissions).notifier).refresh();
      final fresh = ref.read(attendanceQueryProvider(_permissions));
      if (fresh.error != null || !(fresh.data?.session?.permissions.canRecover ?? false)) return;
      if (mounted) setState(() => _review = fresh.data);
    }

    Future<void> submit({bool retry = false}) async {
      final body = makeBody(_review?.session?.version);
      if (!retry && recoveryRequestBytes(body) > 256 * 1024) return;
      final result = await _mutation.submit(body, retry: retry);
      if (!mounted || result == null) return;
      if (result.success) {
        setState(() {
          _selected = {};
          _reason.clear();
          _evidence.clear();
          _review = null;
          _saved = true;
        });
        _toast(t(_a('recoveryDone'), {'count': result.changed}));
        (widget.onSaved ?? widget.onBack)();
      } else if (result.kind == WriteKind.error) {
        if (result.code == 'SESSION_VERSION_CONFLICT' || result.code == 'ATTENDANCE_RECOVERY_RECORD_EXISTS') {
          final existingController = ref.read(attendanceQueryProvider(_existing).notifier);
          await existingController.load(preserve: false);
          unawaited(ref.read(attendanceQueryProvider(_permissions).notifier).refresh());
          final fresh = ref.read(attendanceQueryProvider(_existing));
          if (!mounted) return;
          setState(() {
            _review = null;
            if (fresh.error == null && fresh.data != null) {
              final keys = {for (final r in fresh.data!.rows) r.enrollmentId};
              _selected = {for (final e in _selected.entries) if (!keys.contains(e.key)) e.key: e.value};
            }
            _feedback = t(result.code == 'SESSION_VERSION_CONFLICT' ? _a('changedReview') : _a('recordExists'));
          });
        } else if (result.code == 'ATTENDANCE_RECOVERY_CLOCK_CONFLICT') {
          await ref.read(attendanceQueryProvider(_context).notifier).refresh();
          await ref.read(attendanceQueryProvider(_permissions).notifier).refresh();
          if (!mounted) return;
          setState(() {
            _review = null;
            _feedback = t(_a('clockConflict'));
          });
        } else if (result.code == 'SESSION_STATE_CONFLICT') {
          setState(() {
            _noLonger = true;
            _review = null;
          });
        }
      }
    }

    String defaultDate() => session == null ? '' : isoDate(session.actualStartedAt ?? session.startsAt);
    String defaultStart() => session == null ? '' : isoTime(session.actualStartedAt ?? session.startsAt);
    String defaultEnd() => session == null ? '' : isoTime(session.actualEndedAt ?? session.endsAt);
    final dirty =
        !_saved &&
        !denied &&
        (_evidence.text.isNotEmpty ||
            _reason.text.isNotEmpty ||
            entries.isNotEmpty ||
            _date.text != defaultDate() ||
            _start.text != defaultStart() ||
            _end.text != defaultEnd());

    Widget scheduleButton(String key, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: MdyPressed(
        key: Key(key),
        enabled: !locked,
        onTap: onTap,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? .7 : 1,
          child: const SizedBox.square(dimension: MdySpace.s44, child: Center(child: MdyIcon(MdyIcons.eventRepeat, size: 20))),
        ),
      ),
    );

    List<Widget> form() => [
      MdyAlert(t(_a('recoveryWarning')), key: const Key('recovery-warning'), warning: true),
      if (session?.status == SessionStatus.SCHEDULED) MdyText(t(_a('recoveryComplete'))),
      _TimeField(
        id: 'recovery-date',
        label: t(_a('date')),
        controller: _date,
        focusNode: _dateFocus,
        formatter: _dateFormatter,
        disabled: locked || session?.actualStartedAt != null,
        error: _invalid && !timeValid ? t(_a('timeRequired')) : null,
        onChanged: () => setState(() {}),
        trailing: session?.actualStartedAt != null
            ? null
            : scheduleButton('recovery-use-date', t(_a('useScheduleDate')), () {
                if (session != null) setState(() => _date.text = isoDate(session.startsAt));
              }),
      ),
      _TimeField(
        id: 'recovery-start-time',
        label: t(_a('startTime')),
        controller: _start,
        formatter: hhmmFormatter,
        disabled: locked || session?.actualStartedAt != null,
        onChanged: () => setState(() {}),
        trailing: session?.actualStartedAt != null
            ? null
            : scheduleButton('recovery-use-start', '${t(_a('useScheduleTime'))}: ${t(_a('startTime'))}', () {
                if (session != null) setState(() => _start.text = isoTime(session.startsAt));
              }),
      ),
      _TimeField(
        id: 'recovery-end-time',
        label: t(_a('endTime')),
        controller: _end,
        formatter: hhmmFormatter,
        disabled: locked || session?.actualEndedAt != null,
        error: _invalid && !timeValid ? t(_a('timeInvalid')) : null,
        onChanged: () => setState(() {}),
        trailing: session?.actualEndedAt != null
            ? null
            : scheduleButton('recovery-use-end', '${t(_a('useScheduleTime'))}: ${t(_a('endTime'))}', () {
                if (session != null) setState(() => _end.text = isoTime(session.endsAt));
              }),
      ),
      if (timeValid && _date.text != isoDate(session.startsAt))
        MdyAlert(t(_a('dateDiffers')), key: const Key('recovery-date-differs'), warning: true),
      AttendanceField(
        id: 'recovery-evidence',
        focusNode: _evidenceFocus,
        label: t(_a('recovery.evidence')),
        controller: _evidence,
        onChanged: (_) => setState(() {}),
        max: 2000,
        disabled: locked,
        error: _invalid && _evidence.text.trim().isEmpty ? t(_a('evidenceRequired')) : null,
      ),
      AttendanceField(
        id: 'recovery-reason',
        focusNode: _reasonFocus,
        label: t(_a('correction.reason')),
        controller: _reason,
        onChanged: (_) => setState(() {}),
        max: 1000,
        disabled: locked,
        error: _invalid && _reason.text.trim().isEmpty ? t(_a('reasonRequired')) : null,
      ),
      if (_feedback.isNotEmpty) MdyAlert(_feedback, key: const Key('recovery-feedback'), warning: true),
      MdyCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(MdySpace.s6),
        gap: 0,
        children: [
          for (final e in entries)
            Column(
              key: ValueKey(e.student.id),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s8,
              children: [
                AttendanceRowView(
                  row: AttendanceRow(
                    id: e.student.id,
                    enrollmentId: e.student.id,
                    makeupPlacementId: null,
                    entryType: EntryType.REGULAR,
                    name: e.student.name,
                    status: e.status ?? Mark.UNMARKED,
                    checkedInAt: null,
                  ),
                  status: e.status ?? Mark.UNMARKED,
                  prefix: 'recovery',
                  editable: true,
                  disabled: locked,
                  onMark: (status) => setState(() {
                    _selected = {..._selected, e.student.id: (student: e.student, status: status)};
                  }),
                ),
                if (_invalid && e.status == null)
                  Text(t(_a('selectMark')), style: MdyType.text.copyWith(color: c.danger)),
              ],
            ),
        ],
      ),
      if (_invalid && entries.isEmpty) Text(t(_a('recoveryNone')), style: MdyType.text.copyWith(color: c.danger)),
      if (tooLarge) MdyAlert(t(_a('tooLarge')), key: const Key('recovery-too-large')),
      MutationError(result: _mutation.result, prefix: 'recovery'),
    ];

    final pickerSheet = _picker && canRecover && students != null && studentsRequest != null
        ? MdyInlineSheet(
            key: const Key('recovery-picker'),
            title: t(_a('recoveryPick')),
            onClose: () => setState(() => _picker = false),
            children: [
              MdyText(t(_a('recoverGuestLimit'))),
              AttendanceField(
                id: 'recovery-search',
                label: t(_a('search')),
                controller: _search,
                multiline: false,
                onChanged: (_) => setState(() {}),
              ),
              AttendanceQueryBlock(
                query: students,
                prefix: 'recovery-students',
                controller: ref.read(attendanceQueryProvider(studentsRequest).notifier),
                builder: (_) => ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s8,
                      children: [
                        for (final s in students.data?.students ?? const <RecoveryStudent>[])
                          if ((s.name ?? '').toLowerCase().contains(_search.text.toLowerCase()))
                            Builder(
                              builder: (context) {
                                final already = existing?.data?.rows.any((r) => r.enrollmentId == s.id) ?? false;
                                final basis = startedAt == null
                                    ? null
                                    : admissionBasis(s.enrollmentStatus, s.paymentType, s.paidAt, startedAt);
                                final waiting =
                                    (permissions.data?.totals?.eligible ?? 0) > 0 &&
                                    (existing?.data == null ||
                                        existing!.busy ||
                                        existing.data!.rows.length < existing.data!.total);
                                final unavailable = already
                                    ? t(_a('alreadyRecorded'))
                                    : s.enrollmentStatus == EnrollmentStatus.PENDING_PAYMENT
                                    ? t(_a('notEligible'))
                                    : s.paidAt == null
                                    ? t(_a('noPayment'))
                                    : basis == null
                                    ? t(_a('latePayment'))
                                    : waiting
                                    ? t(_a('loading'))
                                    : null;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: MdySpace.s4,
                                  children: [
                                    MdyButton(
                                      key: Key('recovery-student-${s.id}'),
                                      variant: _selected.containsKey(s.id) ? MdyButtonVariant.primary : MdyButtonVariant.secondary,
                                      disabled: unavailable != null,
                                      label: s.name ?? t(_a('nameMissing')),
                                      onPressed: () => setState(() {
                                        _selected = {s.id: (student: s, status: null)};
                                        _picker = false;
                                      }),
                                    ),
                                    Text(
                                      '${unavailable ?? t(_a('basis.${basis?.name}'))}'
                                      '${s.paidAt == null ? '' : ' · ${isoTime(s.paidAt!)} ${isoDate(s.paidAt!)}'}',
                                      style: MdyType.size(12).copyWith(color: c.secondary),
                                    ),
                                  ],
                                );
                              },
                            ),
                        AttendanceMore(
                          query: students,
                          controller: ref.read(attendanceQueryProvider(studentsRequest).notifier),
                          count: students.data?.students.length ?? 0,
                          prefix: 'recovery-students',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : null;

    final reviewSheet = _review == null
        ? null
        : MdyInlineSheet(
            key: const Key('recovery-review'),
            title: t(_a('reviewRecovery')),
            busy: locked,
            onClose: () => setState(() => _review = null),
            children: [
              MdyText('${_date.text} · ${_start.text}–${_end.text}'),
              MdyText(_evidence.text),
              MdyText(_reason.text),
              MdyText(
                t(_a('recoverySummary'), {
                  'count': entries.length,
                  'present': entries.where((e) => e.status == Mark.PRESENT).length,
                  'absent': entries.where((e) => e.status == Mark.ABSENT).length,
                }),
              ),
              if (session?.status == SessionStatus.SCHEDULED) MdyText(t(_a('recoveryComplete'))),
              MdyAlert(t(_a('recoveryWarning')), warning: true),
              if (_review!.session?.version != session?.version) MdyText(t(_a('changedReview'))),
              MutationError(result: _mutation.result, prefix: 'recovery'),
              if (_mutation.uncertain)
                IntentBanner(prefix: 'recovery', offline: permissions.offline, busy: _mutation.busy, onRetry: () => submit(retry: true))
              else
                MdyButton(
                  key: const Key('recovery-submit'),
                  disabled: permissions.offline || locked || tooLarge,
                  label: t(_a('recover')),
                  onPressed: submit,
                ),
              MdyButton(
                variant: MdyButtonVariant.text,
                disabled: locked,
                label: t(_a('back')),
                onPressed: () => setState(() => _review = null),
              ),
            ],
          );

    return AttendancePage(
      prefix: 'recovery',
      title: widget.detailTabs?.title ?? t(_a('recovery.title')),
      tabs: widget.detailTabs?.tabs,
      tab: widget.detailTabs?.tab,
      onTab: widget.detailTabs?.onTab,
      subtitle: widget.classTitle ?? session?.classTitle,
      onBack: widget.onBack,
      dirty: dirty,
      allowLeave: _saved,
      busy: locked,
      uncertain: _mutation.uncertain,
      refresh: ref.read(attendanceQueryProvider(_context).notifier).refresh,
      footer: canRecover && !denied && entries.isNotEmpty
          ? [
              MdyButton(
                key: const Key('recovery-open-review'),
                disabled: locked || permissions.offline,
                label: t(_a('reviewRecovery')),
                onPressed: openReview,
              ),
            ]
          : null,
      overlays: [?pickerSheet, ?reviewSheet],
      children: [
        if (denied)
          MdyAlert(t(_a('denied')), key: const Key('recovery-denied'))
        else
          AttendanceQueryBlock(
            query: query,
            prefix: 'recovery',
            controller: ref.read(attendanceQueryProvider(_context).notifier),
            builder: (_) => AttendanceQueryBlock(
              query: permissions,
              prefix: 'recovery-permissions',
              controller: ref.read(attendanceQueryProvider(_permissions).notifier),
              builder: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  if (session != null) SessionHeading(session: session),
                  if (!canRecover)
                    Column(
                      key: const Key('recovery-unavailable'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s12,
                      children: [
                        MdyText(t(_a('recoverUnavailable'))),
                        if (_noLonger) SelectableText(_evidence.text),
                      ],
                    )
                  else if (entries.isEmpty)
                    if (students != null && studentsRequest != null)
                      AttendanceQueryBlock(
                        query: students,
                        prefix: 'recovery-student',
                        controller: ref.read(attendanceQueryProvider(studentsRequest).notifier),
                        builder: (_) => _picker
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: MdySpace.s12,
                                children: [
                                  MdyText(t(_a('recoveryNone'))),
                                  MdyText(t(_a('recoverySelectionHint'))),
                                  MdyButton(
                                    key: const Key('recovery-pick'),
                                    label: t(_a('recoveryPick')),
                                    onPressed: () => setState(() => _picker = true),
                                  ),
                                ],
                              ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: MdySpace.s12,
                        children: [
                          MdyText(t(_a('recoveryNone'))),
                          MdyText(t(_a('recoverySelectionHint'))),
                          MdyButton(
                            key: const Key('recovery-pick'),
                            label: t(_a('recoveryPick')),
                            onPressed: () => setState(() => _picker = true),
                          ),
                        ],
                      )
                  else
                    ...form(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ô nhập 1 dòng có định dạng (ngày / giờ) + nút "Theo lịch".
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.id,
    required this.label,
    required this.controller,
    required this.formatter,
    required this.disabled,
    required this.onChanged,
    this.focusNode,
    this.error,
    this.trailing,
  });

  final String id;
  final String label;
  final TextEditingController controller;
  final TextInputFormatter formatter;
  final bool disabled;
  final VoidCallback onChanged;
  final FocusNode? focusNode;
  final String? error;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    OutlineInputBorder border(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(MdyRadius.r14), borderSide: BorderSide(color: color));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(label, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
        Stack(
          children: [
            TextField(
              key: Key('$id-input'),
              controller: controller,
              focusNode: focusNode,
              enabled: !disabled,
              keyboardType: TextInputType.datetime,
              inputFormatters: [formatter],
              onChanged: (_) => onChanged(),
              cursorColor: c.primary,
              style: MdyType.size(14).copyWith(color: c.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: disabled ? c.muted2 : c.surface,
                contentPadding: EdgeInsets.fromLTRB(
                  MdySpace.s12,
                  MdySpace.s12,
                  trailing != null ? MdySpace.s56 : MdySpace.s12,
                  MdySpace.s12,
                ),
                enabledBorder: border(error != null ? c.dangerBorder : c.border),
                focusedBorder: border(error != null ? c.dangerBorder : c.primary),
                disabledBorder: border(c.border),
              ),
            ),
            if (trailing != null) Positioned(right: MdySpace.s4, top: 0, bottom: 0, child: Center(child: trailing)),
          ],
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(error!, key: Key('$id-error'), style: MdyType.size(12).copyWith(color: c.danger)),
          ),
      ],
    );
  }
}

/// Màn đứng riêng (từ nút "Thiếu học viên" của màn sửa điểm danh).
class StaffAttendanceRecoveryScreen extends StatelessWidget {
  const StaffAttendanceRecoveryScreen({super.key, required this.sessionId, this.classTitle, this.enrollmentId});
  final String sessionId;
  final String? classTitle;
  final String? enrollmentId;

  @override
  Widget build(BuildContext context) => AttendanceRecoveryView(
    sessionId: sessionId,
    classTitle: classTitle,
    enrollmentId: enrollmentId,
    onBack: () => staffBack(context, manager: true),
  );
}
