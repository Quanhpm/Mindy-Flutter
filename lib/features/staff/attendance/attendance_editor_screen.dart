import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Tham số `AttendanceCorrection` / tab tiện ích (correction | history).
typedef CorrectionParams = ({
  String sessionId,
  String? classTitle,
  String? classId,
  String? enrollmentId,
  String? makeupPlacementId,
  String? studentName,
  bool utilityTabs,
});

String _query(String path, CorrectionParams p) {
  final q = {
    if (p.classTitle != null) 'title': p.classTitle!,
    if (p.classId != null) 'classId': p.classId!,
    if (p.enrollmentId != null) 'enrollmentId': p.enrollmentId!,
    if (p.makeupPlacementId != null) 'makeupPlacementId': p.makeupPlacementId!,
    if (p.studentName != null) 'studentName': p.studentName!,
    if (p.utilityTabs) 'utility': '1',
  };
  return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
}

/// `/manager/correction/:sessionId?...` (AttendanceCorrection).
String correctionRoute(CorrectionParams p) => _query('/manager/correction/${p.sessionId}', p);

/// `/manager/audits/:sessionId?...` (AttendanceAudits).
String auditsRoute(CorrectionParams p) => _query('/manager/audits/${p.sessionId}', p);

/// Đọc lại tham số từ URL.
CorrectionParams correctionParamsOf(String sessionId, Map<String, String> q) => (
  sessionId: sessionId,
  classTitle: q['title'],
  classId: q['classId'],
  enrollmentId: q['enrollmentId'],
  makeupPlacementId: q['makeupPlacementId'],
  studentName: q['studentName'],
  utilityTabs: q['utility'] == '1',
);

/// Tab "Sửa điểm danh / Lịch sử" của tiện ích Quản lý (`useUtilityTabs`).
({List<({String value, String label})>? tabs, String? tab, ValueChanged<String>? onTab}) utilityTabs(
  BuildContext context,
  Translator t,
  CorrectionParams p,
  String mode,
) {
  if (!p.utilityTabs) return (tabs: null, tab: null, onTab: null);
  return (
    tabs: [(value: 'correction', label: t(_a('utility.edit'))), (value: 'history', label: t(_a('utility.history')))],
    tab: mode,
    onTab: (next) {
      if (next == mode) return;
      context.replace(next == 'history' ? auditsRoute(p) : correctionRoute(p));
    },
  );
}

/// Clone `AttendanceEditorScreen.tsx` (Mentor) + `AttendanceCorrectionScreen` (Quản lý).
class StaffAttendanceEditorScreen extends ConsumerStatefulWidget {
  const StaffAttendanceEditorScreen({super.key, required this.params, required this.manager});
  final CorrectionParams params;
  final bool manager;

  @override
  ConsumerState<StaffAttendanceEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<StaffAttendanceEditorScreen> {
  late final AttendanceMutator _mutation = AttendanceMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  Draft _draft = {};
  int? _version;
  bool _reasonError = false, _writeClosed = false, _finalized = false, _changedReview = false;
  String? _sheet; // start | save | finalize
  AttendanceData? _review;
  List<String>? _conflicts;
  String _message = '';

  bool get _manager => widget.manager;
  TeachingRole get _role => _manager ? TeachingRole.MANAGER : TeachingRole.MENTOR;
  String get _id => widget.params.sessionId;
  String get _prefix => _manager ? 'correction' : 'attendance';

  AttendanceRequest get _contextRequest => AttendanceRequest(kind: AttendanceKind.context, role: _role, sessionId: _id);
  AttendanceRequest get _listRequest => AttendanceRequest(
    kind: AttendanceKind.attendance,
    role: _role,
    sessionId: _id,
    pageSize: 100,
    all: _manager && widget.params.enrollmentId != null,
  );
  AttendanceRequest get _previewRequest =>
      AttendanceRequest(kind: AttendanceKind.candidates, role: _role, sessionId: _id, pageSize: 100);

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _toast(String text) => ref.read(mdyToastProvider.notifier).show(text);

  AttendanceQuery get _list => ref.read(attendanceQueryProvider(_listRequest).notifier);
  AttendanceQuery get _context => ref.read(attendanceQueryProvider(_contextRequest).notifier);

  List<AttendanceRow> _rows(AttendanceQueryState q) {
    final student = widget.params.enrollmentId, makeup = widget.params.makeupPlacementId;
    return (q.data?.rows ?? const <AttendanceRow>[])
        .where((r) => !_manager || student == null || (r.enrollmentId == student && r.makeupPlacementId == makeup))
        .toList();
  }

  void _mark(AttendanceRow row, Mark status, AttendanceSession? session) {
    final t = ref.read(trProvider);
    try {
      final next = changeDraft(_draft, row, status);
      setState(() {
        if (_draft.isEmpty) _version = session?.version;
        _draft = next;
        _message = '';
      });
    } on BatchLimitError {
      setState(() => _message = t(_a('batchLimit')));
    }
  }

  AttendanceIntent _body(IntentKind kind, List<AttendanceRow> rows, int expectedVersion) => AttendanceIntent(
    key: '',
    kind: kind,
    sessionId: _id,
    role: _role,
    expectedVersion: expectedVersion,
    reason: _manager ? _reason.text.trim() : null,
    records: kind == IntentKind.save
        ? [
            for (final r in rows)
              if (_draft[r.id] != null && r.entryType == EntryType.REGULAR)
                (enrollmentId: r.enrollmentId, status: _draft[r.id]!.status),
          ]
        : null,
    guestRecords: kind == IntentKind.save
        ? [
            for (final r in rows)
              if (_draft[r.id] != null && r.entryType == EntryType.MAKEUP && r.makeupPlacementId != null)
                (makeupPlacementId: r.makeupPlacementId!, status: _draft[r.id]!.status),
          ]
        : null,
  );

  Future<AttendanceData?> _fresh() async {
    await _list.refresh();
    final s = ref.read(attendanceQueryProvider(_listRequest));
    return s.error == null ? s.data : null;
  }

  Future<WriteResult?> _handle(AttendanceIntent value, {bool retry = false}) async {
    final t = ref.read(trProvider);
    final result = await _mutation.submit(value, retry: retry);
    if (!mounted || result == null) return result;
    if (result.success) {
      setState(() {
        if (value.kind == IntentKind.save || value.kind == IntentKind.bulk) {
          _draft = {};
          _reason.clear();
          _conflicts = null;
          _version = result.data?.session?.version;
        }
        if (value.kind == IntentKind.sync) _version = result.data?.session?.version;
        if (value.kind == IntentKind.finalize) _finalized = true;
        _sheet = null;
        _message = '';
      });
      _toast(
        t(
          switch (value.kind) {
            IntentKind.start => _a('editor.started'),
            IntentKind.finalize => _a('editor.finalized'),
            IntentKind.sync => result.changed > 0 ? _a('editor.syncAdded') : _a('editor.syncSame'),
            _ => result.changed > 0 ? _a('changed') : _a('noChange'),
          },
          {'count': result.changed},
        ),
      );
      await _list.refresh();
      await _context.refresh();
    } else if (result.kind == WriteKind.error && result.code == 'SESSION_VERSION_CONFLICT') {
      final fresh = await _fresh();
      if (!mounted || fresh == null) return result;
      setState(() {
        if (value.kind == IntentKind.finalize) {
          _review = fresh;
          _changedReview = true;
        } else {
          final compared = compareDraft(_draft, fresh.rows);
          _draft = compared.draft;
          _conflicts = compared.conflicts;
          _version = fresh.session?.version;
          _sheet = null;
          if (compared.dropped > 0) _message = t(_a('rowsDropped'), {'count': compared.dropped});
        }
      });
    } else if (result.kind == WriteKind.error && result.code == 'ATTENDANCE_EDIT_WINDOW_EXPIRED') {
      setState(() {
        _writeClosed = true;
        _message = t(_a('note.closedUnsaved'));
      });
      await _list.refresh();
    } else if (result.kind == WriteKind.error && (result.code ?? '').contains('NOT_ELIGIBLE')) {
      final fresh = await _fresh();
      if (!mounted || fresh == null) return result;
      final compared = compareDraft(_draft, fresh.rows);
      setState(() {
        _draft = compared.draft;
        _message = t(_a('rowsDropped'), {'count': compared.dropped});
      });
    }
    return result;
  }

  Future<WriteResult?> _save(List<AttendanceRow> rows, AttendanceSession? session) async {
    final reason = _reason.text.trim();
    if (_manager && (reason.isEmpty || noteLength(reason) > 1000)) {
      setState(() => _reasonError = true);
      _reasonFocus.requestFocus();
      return null;
    }
    return _handle(_body(IntentKind.save, rows, _version ?? session?.version ?? 0));
  }

  Future<void> _finalize(List<AttendanceRow> rows, AttendanceSession? session) async {
    if (_draft.isNotEmpty) {
      final result = await _save(rows, session);
      if (result?.success != true || !mounted) return;
      setState(() => _review = result!.data);
    } else {
      final fresh = await _fresh();
      if (fresh == null || !mounted) return;
      setState(() => _review = fresh);
    }
    setState(() {
      _changedReview = false;
      _sheet = 'finalize';
    });
  }

  void _resolve(List<AttendanceRow> rows, String rowId, bool mine) {
    final row = rows.where((r) => r.id == rowId).firstOrNull;
    if (row == null) return;
    setState(() {
      final next = Map<String, DraftItem>.of(_draft);
      final item = next[rowId];
      if (mine && item != null) {
        next[rowId] = (baseStatus: row.status, status: item.status, entryType: item.entryType);
      } else {
        next.remove(rowId);
      }
      _draft = next;
      _conflicts = _conflicts?.where((k) => k != rowId).toList();
    });
  }

  void _retryIntent() {
    final intent = _mutation.intent;
    if (intent != null) _handle(intent, retry: true);
  }

  String _deadline(AttendanceSession s) =>
      s.editableUntil == null ? '' : '${isoTime(s.editableUntil!)} ${isoDate(s.editableUntil!)}';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final contextQuery = ref.watch(attendanceQueryProvider(_contextRequest));
    final cancelled =
        contextQuery.data?.session?.status == SessionStatus.CANCELLED && contextQuery.data?.session?.actualStartedAt == null;
    final listEnabled = contextQuery.data != null && !cancelled;
    final query = listEnabled ? ref.watch(attendanceQueryProvider(_listRequest)) : const AttendanceQueryState();
    final session = query.data?.session ?? contextQuery.data?.session;
    final previewEnabled = !_manager && session?.status == SessionStatus.SCHEDULED;
    final preview = previewEnabled ? ref.watch(attendanceQueryProvider(_previewRequest)) : null;
    final rows = _rows(query);
    final count = _draft.length;
    final student = widget.params.enrollmentId;
    final totals = query.data?.totals;
    int? present, absent;
    if (totals != null) {
      present =
          (student != null ? rows.where((r) => r.status == Mark.PRESENT).length : totals.present) +
          rows.fold<int>(0, (delta, row) {
            final change = _draft[row.id];
            if (change == null) return delta;
            return delta + (change.status == Mark.PRESENT ? 1 : 0) - (row.status == Mark.PRESENT ? 1 : 0);
          });
      absent = (student != null ? rows.length : totals.present + totals.absent + totals.unmarked) - present;
    }
    final denied =
        query.error?.kind == RemoteFailure.denied ||
        query.error?.kind == RemoteFailure.notFound ||
        _mutation.result?.kind == WriteKind.denied ||
        _mutation.result?.kind == WriteKind.notFound;
    if (denied && (_draft.isNotEmpty || _sheet != null || _conflicts != null)) {
      _draft = {};
      _reason.clear();
      _sheet = null;
      _conflicts = null;
    }
    final busy = _mutation.busy, locked = busy || _mutation.uncertain, offline = query.offline;
    final editable = (query.data?.session?.permissions.canEditAttendance ?? false) && !denied && !_writeClosed;
    final dirty = count > 0 || _reason.text.isNotEmpty;
    final tabs = utilityTabs(context, t, widget.params, 'correction');

    final footer = session != null && query.data != null && !denied
        ? <Widget>[
            if (count > 0 && (_manager || !session.permissions.canFinalize))
              Row(
                spacing: MdySpace.s10,
                children: [
                  Expanded(
                    child: Text(
                      t(_a('unsavedCount'), {'count': count}),
                      key: Key('$_prefix-unsaved'),
                      style: MdyType.size(13).copyWith(color: c.ink),
                    ),
                  ),
                  MdyButton(
                    key: Key('$_prefix-save'),
                    disabled: offline || locked || !editable || (_conflicts?.isNotEmpty ?? false),
                    busy: busy,
                    label: t(_manager ? _a('continue') : _a('save')),
                    onPressed: () => _manager ? setState(() => _sheet = 'save') : _save(rows, session),
                  ),
                ],
              ),
            if (!_manager && session.permissions.canStart)
              MdyButton(
                key: const Key('attendance-start'),
                disabled: offline || locked,
                label: t(_a('editor.start')),
                onPressed: () => setState(() => _sheet = 'start'),
              ),
            if (!_manager && !_writeClosed && session.permissions.canFinalize)
              MdyButton(
                key: const Key('attendance-finalize'),
                busy: busy,
                disabled: offline || locked || (_conflicts?.isNotEmpty ?? false),
                label: t(_a('editor.finalize')),
                onPressed: () => _finalize(rows, session),
              ),
            if (_finalized)
              MdyButton(
                key: const Key('attendance-note-link'),
                variant: MdyButtonVariant.secondary,
                label: t(_a('noteLink')),
                onPressed: () => context.push(Routes.mentorNotes(_id)),
              ),
          ]
        : null;

    List<Widget> body() {
      if (session?.status == SessionStatus.SCHEDULED && !_manager) {
        final s = session!;
        return [
          MdyAlert(t(_a('editor.provisional')), key: const Key('attendance-provisional'), warning: true),
          if (!s.permissions.canStart)
            MdyText(
              t(
                isoDate(s.asOf) == isoDate(s.startsAt)
                    ? _a('editor.startBlocked')
                    : s.asOf.isBefore(s.startsAt)
                    ? _a('editor.startBefore')
                    : _a('editor.startAfter'),
                {'date': isoDate(s.startsAt)},
              ),
              key: const Key('attendance-start-note'),
            ),
          if (preview != null)
            AttendanceQueryBlock(
              query: preview,
              prefix: 'attendance-candidates',
              controller: ref.read(attendanceQueryProvider(_previewRequest).notifier),
              builder: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  MdyText(t(_a('editor.expected'), {'count': preview.data?.total ?? 0})),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s6),
                    children: [
                      for (final row in preview.data?.rows ?? const <AttendanceRow>[])
                        AttendanceRowView(row: row, prefix: 'attendance-candidate', provisional: true),
                      if (preview.data?.total == 0) MdyText(t(_a('editor.previewEmpty'))),
                    ],
                  ),
                  AttendanceMore(
                    query: preview,
                    controller: ref.read(attendanceQueryProvider(_previewRequest).notifier),
                    count: preview.data?.rows.length ?? 0,
                    prefix: 'attendance-candidates',
                  ),
                ],
              ),
            ),
        ];
      }
      if (_manager && !editable) {
        return [MdyAlert(t(_a('correction.noEdit')), key: const Key('correction-no-edit'), warning: true)];
      }
      final roster = [
        for (final row in rows)
          AttendanceRowView(
            row: row,
            prefix: _prefix,
            compact: true,
            status: _draft[row.id]?.status ?? row.status,
            dirty: _draft.containsKey(row.id),
            editable: editable,
            disabled: locked,
            onMark: (status) => _mark(row, status, session),
          ),
        if (rows.isEmpty)
          MdyText(t(_manager ? _a('correction.empty') : _a('editor.empty')), key: Key('$_prefix-empty')),
      ];
      return [
        if (_manager)
          Row(
            key: const Key('correction-totals'),
            spacing: MdySpace.s8,
            children: [
              for (final key in const ['present', 'absent'])
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s8),
                    decoration: BoxDecoration(
                      color: key == 'present' ? c.successBg : c.dangerBg,
                      borderRadius: BorderRadius.circular(MdyRadius.r14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s2,
                      children: [
                        Text(
                          '${(key == 'present' ? present : absent) ?? '—'}',
                          style: MdyType.size(18, MdyType.w600).copyWith(color: key == 'present' ? c.success : c.danger),
                        ),
                        Text(
                          t(_a('editor.$key')),
                          style: MdyType.size(11).copyWith(color: key == 'present' ? c.success : c.danger),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (!_manager && session?.status == SessionStatus.COMPLETED)
          MdyAlert(
            editable ? t(_a('editor.editUntil'), {'deadline': _deadline(session!)}) : t(_a('editor.expired')),
            key: Key(editable ? 'attendance-edit-until' : 'attendance-expired'),
            warning: true,
          ),
        if (!_manager && session?.status == SessionStatus.IN_PROGRESS && !editable)
          MdyAlert(t(_a('editor.overdue')), key: const Key('attendance-overdue'), warning: true),
        if (count > 0 && _version != session?.version) MdyText(t(_a('newer')), key: Key('$_prefix-newer-exists')),
        if (offline && editable)
          MdyAlert('${t(_a('editor.offlineMark'))} ${t(_a('memoryOnly'))}', key: Key('$_prefix-offline-mark'), warning: true),
        if (_message.isNotEmpty) MdyAlert(_message, key: Key('$_prefix-message'), warning: true),
        if (_conflicts != null)
          FocusPanel(
            key: Key('$_prefix-conflicts'),
            children: [
              MdyText(t(_a('conflictTitle'))),
              MdyText(t(_conflicts!.isNotEmpty ? _a('conflictBody') : _a('conflictNoDiff'))),
              for (final rowId in _conflicts!)
                if (rows.where((r) => r.id == rowId).firstOrNull case final row?)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MdySpace.s8,
                    children: [
                      MdyText(row.name ?? t(_a('nameMissing'))),
                      MdyText(
                        t(_a('conflictRow'), {
                          'server': t(markKey(row.status)),
                          'mine': _draft[rowId] == null ? '' : t(markKey(_draft[rowId]!.status)),
                        }),
                      ),
                      MdyButton(
                        variant: MdyButtonVariant.secondary,
                        label: t(_a('useLatest')),
                        onPressed: () => _resolve(rows, rowId, false),
                      ),
                      MdyButton(
                        variant: MdyButtonVariant.secondary,
                        label: t(_a('keepMine')),
                        onPressed: () => _resolve(rows, rowId, true),
                      ),
                    ],
                  ),
              if (_conflicts!.length >= 2)
                MdyButton(
                  label: t(_a('useLatestAll')),
                  onPressed: () {
                    for (final id in List.of(_conflicts!)) {
                      _resolve(rows, id, false);
                    }
                  },
                ),
            ],
          ),
        MutationError(result: _mutation.result, prefix: _prefix),
        if (_mutation.uncertain && _sheet == null)
          IntentBanner(prefix: _prefix, offline: offline, busy: busy, onRetry: _retryIntent),
        if (_manager)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: roster)
        else
          MdyCard(margin: EdgeInsets.zero, padding: const EdgeInsets.all(MdySpace.s6), gap: 0, children: roster),
        if (student == null)
          AttendanceMore(query: query, controller: _list, count: rows.length, prefix: _prefix),
        if (_manager &&
            student == null &&
            (session?.permissions.canRecover ?? false) &&
            !session!.endsAt.isAfter(session.asOf))
          MdyButton(
            key: const Key('correction-missing'),
            variant: MdyButtonVariant.text,
            label: t(_a('correction.missing')),
            onPressed: () => context.push(Routes.managerSession(_id, tab: 'recovery')),
          ),
      ];
    }

    final sheetActions = <Widget>[
      MutationError(result: _mutation.result, prefix: _prefix),
      if (_mutation.uncertain)
        IntentBanner(prefix: _prefix, offline: offline, busy: busy, onRetry: _retryIntent),
    ];

    return AttendancePage(
      prefix: _prefix,
      title: t(widget.params.utilityTabs ? _a('utility.management') : (_manager ? _a('correction.title') : _a('editor.title'))),
      subtitle: _manager && session != null
          ? '${widget.params.classTitle ?? session.classTitle} · ${isoTime(session.startsAt)}'
          : (widget.params.classTitle ?? session?.classTitle),
      tabs: tabs.tabs,
      tab: tabs.tab,
      onTab: tabs.onTab,
      onBack: () => staffBack(context, manager: _manager),
      dirty: dirty,
      busy: busy,
      uncertain: _mutation.uncertain,
      footer: footer,
      refresh: listEnabled ? _list.refresh : null,
      overlays: [
        if (_sheet == 'start')
          MdyInlineDialog(
            key: const Key('attendance-start-dialog'),
            title: t(_a('editor.startTitle')),
            icon: MdyIcons.factCheck,
            busy: locked,
            onClose: () => setState(() => _sheet = null),
            children: [
              MdyText(t(_a('editor.startBody')), textAlign: TextAlign.center),
              ...sheetActions,
              if (!_mutation.uncertain)
                MdyButton(
                  key: const Key('attendance-start-confirm'),
                  disabled: offline || busy,
                  label: t(_a('editor.startConfirm')),
                  onPressed: () => _handle(_body(IntentKind.start, rows, session?.version ?? 0)),
                ),
              MdyButton(
                variant: MdyButtonVariant.text,
                disabled: locked,
                label: t(_a('editor.later')),
                onPressed: () => setState(() => _sheet = null),
              ),
            ],
          ),
        if (_sheet == 'save' || _sheet == 'finalize')
          MdyInlineSheet(
            key: Key(_sheet == 'finalize' ? 'attendance-finalize-sheet' : 'correction-sheet'),
            title: t(_sheet == 'finalize' ? _a('editor.finalizeTitle') : _a('correction.confirmTitle')),
            busy: locked,
            onClose: () => setState(() => _sheet = null),
            children: [
              if (_sheet == 'finalize') ...[
                TotalsStrip(totals: _review?.totals, prefix: 'attendance-finalize'),
                if ((_review?.totals?.unmarked ?? 0) > 0)
                  MdyAlert(
                    t(_a('editor.finalizeImpact'), {
                      'count': _review!.totals!.unmarked,
                      'unmarked': _review!.totals!.unmarked,
                    }),
                    warning: true,
                  ),
                if (_changedReview) MdyAlert(t(_a('changedReview')), warning: true),
                MdyText(t(_a('editor.finalizeFoot'), {'deadline': session == null ? '' : _deadline(session)})),
              ] else
                for (final row in rows)
                  if (_draft[row.id] case final change?)
                    MdyText(
                      '${row.name} · ${t(markKey(change.baseStatus))} → ${t(markKey(change.status))}',
                      key: Key('correction-change-${row.id}'),
                    ),
              if (_manager)
                AttendanceField(
                  id: 'correction-reason',
                  focusNode: _reasonFocus,
                  label: t(_a('correction.reason')),
                  controller: _reason,
                  onChanged: (_) => setState(() => _reasonError = false),
                  max: 1000,
                  error: _reasonError ? t(_a('reasonRequired')) : null,
                  disabled: locked,
                ),
              ...sheetActions,
              if (!_mutation.uncertain)
                MdyButton(
                  key: Key(_sheet == 'finalize' ? 'attendance-finalize-confirm' : 'correction-submit'),
                  disabled: offline || busy || (_manager && noteLength(_reason.text.trim()) > 1000),
                  busy: busy,
                  label: t(_sheet == 'finalize' ? _a('editor.finalize') : _a('correction.submit')),
                  onPressed: () {
                    if (_manager && _reason.text.trim().isEmpty) {
                      setState(() => _reasonError = true);
                      _reasonFocus.requestFocus();
                      return;
                    }
                    if (_sheet == 'finalize') {
                      _handle(_body(IntentKind.finalize, rows, _review?.session?.version ?? session?.version ?? 0));
                    } else {
                      _save(rows, session);
                    }
                  },
                ),
              MdyButton(
                variant: MdyButtonVariant.text,
                disabled: locked,
                label: t(_a('back')),
                onPressed: () => setState(() => _sheet = null),
              ),
            ],
          ),
      ],
      children: [
        if (denied)
          MdyAlert('${t(_a('denied'))} ${t(_a('note.deniedExtra'))}', key: Key('$_prefix-denied'))
        else
          AttendanceQueryBlock(
            query: contextQuery,
            prefix: _prefix,
            controller: _context,
            builder: (_) => cancelled
                ? MdyText(t(_a('cancelledEmpty')))
                : AttendanceQueryBlock(
                    query: query,
                    prefix: _prefix,
                    controller: _list,
                    builder: (_) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s20,
                      children: body(),
                    ),
                  ),
          ),
      ],
    );
  }
}
