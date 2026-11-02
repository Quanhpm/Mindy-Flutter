import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/remote.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';
import 'attendance_widgets.dart';

String _a(String key) => 'mdy.attendance.$key';

/// Clone `TeachingNoteEditorScreen.tsx`: ghi chú nội bộ của buổi, xử lý xung đột phiên bản.
class StaffTeachingNoteEditorScreen extends ConsumerStatefulWidget {
  const StaffTeachingNoteEditorScreen({super.key, required this.sessionId, this.classTitle});
  final String sessionId;
  final String? classTitle;

  @override
  ConsumerState<StaffTeachingNoteEditorScreen> createState() => _NoteState();
}

class _NoteState extends ConsumerState<StaffTeachingNoteEditorScreen> {
  late final AttendanceMutator _mutation = AttendanceMutator(ref, () {
    if (mounted) setState(() {});
  });
  final _content = TextEditingController();
  final _nextSteps = TextEditingController();
  ({String content, String nextSteps, int version}) _baseline = (content: '', nextSteps: '', version: 0);
  AttendanceData? _conflict;
  bool _replace = false, _closed = false, _expanded = false;
  AttendanceData? _loadedFrom;

  AttendanceRequest get _contextRequest =>
      AttendanceRequest(kind: AttendanceKind.context, role: TeachingRole.MENTOR, sessionId: widget.sessionId);
  AttendanceRequest get _noteRequest =>
      AttendanceRequest(kind: AttendanceKind.note, role: TeachingRole.MENTOR, sessionId: widget.sessionId);

  bool get _dirty => _content.text != _baseline.content || _nextSteps.text != _baseline.nextSteps;

  @override
  void dispose() {
    _content.dispose();
    _nextSteps.dispose();
    super.dispose();
  }

  void _load(AttendanceData data) {
    _content.text = data.note?.content ?? '';
    _nextSteps.text = data.note?.nextSteps ?? '';
    _baseline = (content: _content.text, nextSteps: _nextSteps.text, version: data.noteVersion);
  }

  Future<void> _submit({bool retry = false}) async {
    final t = ref.read(trProvider);
    final result = await _mutation.submit(
      AttendanceIntent(
        key: '',
        kind: IntentKind.note,
        sessionId: widget.sessionId,
        role: TeachingRole.MENTOR,
        expectedVersion: _baseline.version,
        content: _content.text,
        nextSteps: _nextSteps.text,
      ),
      retry: retry,
    );
    if (!mounted || result == null) return;
    if (result.success && result.data != null) {
      setState(() {
        _load(result.data!);
        _conflict = null;
      });
      ref.read(mdyToastProvider.notifier).show(t(_a('note.saved')));
    } else if (result.kind == WriteKind.error && result.code == 'TEACHING_VERSION_CONFLICT') {
      await ref.read(attendanceQueryProvider(_noteRequest).notifier).refresh();
      final fresh = ref.read(attendanceQueryProvider(_noteRequest));
      if (mounted && fresh.error == null && fresh.data != null) setState(() => _conflict = fresh.data);
    } else if (result.kind == WriteKind.error &&
        const ['TEACHING_NOTE_WINDOW_CLOSED', 'TEACHING_NOTE_STATE_CONFLICT'].contains(result.code)) {
      setState(() => _closed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final contextQuery = ref.watch(attendanceQueryProvider(_contextRequest));
    final query = ref.watch(attendanceQueryProvider(_noteRequest));
    final denied =
        query.error?.kind == RemoteFailure.denied ||
        contextQuery.error?.kind == RemoteFailure.denied ||
        _mutation.result?.kind == WriteKind.denied;
    if (query.data != null && !identical(query.data, _loadedFrom) && !_dirty) {
      _loadedFrom = query.data;
      _load(query.data!);
    }
    if (denied && (_content.text.isNotEmpty || _nextSteps.text.isNotEmpty || _conflict != null)) {
      _content.clear();
      _nextSteps.clear();
      _baseline = (content: '', nextSteps: '', version: 0);
      _conflict = null;
    }
    final session = contextQuery.data?.session;
    final editable =
        session != null &&
        const [SessionStatus.IN_PROGRESS, SessionStatus.COMPLETED].contains(session.status) &&
        session.isEffectiveMentor &&
        session.editableUntil != null &&
        session.asOf.isBefore(session.editableUntil!) &&
        !_closed &&
        !denied;
    final invalid = noteLength(_content.text) > 10000 || noteLength(_nextSteps.text) > 5000;
    final locked = _mutation.busy || _mutation.uncertain;
    final readonlyReason = _closed
        ? 'note.closedUnsaved'
        : session?.status == SessionStatus.SCHEDULED
        ? 'note.notStarted'
        : session?.status == SessionStatus.CANCELLED
        ? 'note.cancelled'
        : !(session?.isEffectiveMentor ?? false)
        ? 'note.notTeacher'
        : 'note.expired';
    final noteController = ref.read(attendanceQueryProvider(_noteRequest).notifier);
    return AttendancePage(
      prefix: 'note',
      title: t(_a('note.title')),
      subtitle: widget.classTitle ?? session?.classTitle,
      onBack: () => staffBack(context),
      dirty: _dirty,
      busy: _mutation.busy,
      uncertain: _mutation.uncertain,
      refresh: noteController.refresh,
      footer: _dirty && editable
          ? [
              Row(
                spacing: MdySpace.s12,
                children: [
                  Expanded(child: MdyText(t(_a('note.unsaved')), key: const Key('note-unsaved'))),
                  MdyButton(
                    key: const Key('note-save'),
                    disabled: query.offline || locked || invalid || _conflict != null,
                    busy: _mutation.busy,
                    label: t(_a('note.save')),
                    onPressed: _submit,
                  ),
                ],
              ),
            ]
          : null,
      overlays: [
        if (_replace && _conflict != null)
          MdyInlineDialog(
            title: t(_a('note.useLatest')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _replace = false),
            children: [
              MdyText(t(_a('note.useLatestConfirm')), textAlign: TextAlign.center),
              MdyButton(
                key: const Key('note-use-latest-confirm'),
                label: t(_a('confirm')),
                onPressed: () => setState(() {
                  _load(_conflict!);
                  _conflict = null;
                  _replace = false;
                  _mutation.clear();
                }),
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(_a('cancel')),
                onPressed: () => setState(() => _replace = false),
              ),
            ],
          ),
      ],
      children: [
        AttendanceQueryBlock(
          query: contextQuery,
          prefix: 'note-context',
          controller: ref.read(attendanceQueryProvider(_contextRequest).notifier),
          builder: (_) => AttendanceQueryBlock(
            query: query,
            prefix: 'note',
            controller: noteController,
            builder: (_) => denied
                ? MdyAlert('${t(_a('denied'))} ${t(_a('note.deniedExtra'))}', key: const Key('note-denied'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MdySpace.s20,
                    children: [
                      if (session != null) SessionHeading(session: session),
                      Text(t(_a('note.internal')), style: MdyType.size(12).copyWith(color: c.secondary)),
                      if (_conflict != null)
                        FocusPanel(
                          key: const Key('note-conflict'),
                          children: [
                            Semantics(header: true, child: MdyText(t(_a('note.conflictTitle')))),
                            MdyText(_conflict!.note?.content ?? '', maxLines: _expanded ? null : 6),
                            MdyText(_conflict!.note?.nextSteps ?? '', maxLines: _expanded ? null : 6),
                            MdyButton(
                              variant: MdyButtonVariant.text,
                              label: t(_a('audit.more')),
                              onPressed: () => setState(() => _expanded = !_expanded),
                            ),
                            MdyButton(
                              variant: MdyButtonVariant.secondary,
                              label: t(_a('note.useLatest')),
                              onPressed: () => setState(() => _replace = true),
                            ),
                            MdyButton(
                              key: const Key('note-keep-mine'),
                              variant: MdyButtonVariant.secondary,
                              label: t(_a('note.keepMine')),
                              onPressed: () => setState(() {
                                _baseline = (
                                  content: _conflict!.note?.content ?? '',
                                  nextSteps: _conflict!.note?.nextSteps ?? '',
                                  version: _conflict!.noteVersion,
                                );
                                _conflict = null;
                                _mutation.clear();
                              }),
                            ),
                          ],
                        ),
                      if (editable) ...[
                        if (session.status == SessionStatus.COMPLETED && session.editableUntil != null)
                          MdyText(
                            t(_a('note.editUntil'), {
                              'deadline': '${isoTime(session.editableUntil!)} ${isoDate(session.editableUntil!)}',
                            }),
                            key: const Key('note-edit-until'),
                          ),
                        AttendanceField(
                          id: 'note-content',
                          label: t(_a('note.content')),
                          controller: _content,
                          onChanged: (_) => setState(() {}),
                          max: 10000,
                          disabled: locked,
                        ),
                        AttendanceField(
                          id: 'note-next-steps',
                          label: t(_a('note.nextSteps')),
                          controller: _nextSteps,
                          onChanged: (_) => setState(() {}),
                          max: 5000,
                          disabled: locked,
                        ),
                      ] else
                        Column(
                          key: const Key('note-readonly'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: MdySpace.s12,
                          children: [
                            MdyAlert(t(_a(readonlyReason)), warning: true),
                            if (_content.text.isNotEmpty || _nextSteps.text.isNotEmpty) ...[
                              MdyText(t(_a('note.content'))),
                              SelectableText(_content.text, style: MdyType.text.copyWith(color: c.ink)),
                              MdyText(t(_a('note.nextSteps'))),
                              SelectableText(_nextSteps.text, style: MdyType.text.copyWith(color: c.ink)),
                            ] else
                              MdyText(t(_a('note.empty')), key: const Key('note-empty')),
                            if (_closed)
                              MdyButton(
                                key: const Key('note-copy'),
                                variant: MdyButtonVariant.secondary,
                                label: t(_a('note.copy')),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: '${_content.text}\n\n${_nextSteps.text}'));
                                  ref.read(mdyToastProvider.notifier).show(t(_a('copied')));
                                },
                              ),
                          ],
                        ),
                      if (query.data?.note != null)
                        Text(
                          t(_a('note.updatedAt'), {
                            'time': isoTime(query.data!.note!.updatedAt),
                            'date': isoDate(query.data!.note!.updatedAt),
                          }),
                          style: MdyType.size(12).copyWith(color: c.secondary),
                        ),
                      if (query.offline) MdyAlert(t(_a('note.offline')), key: const Key('note-offline'), warning: true),
                      if (_mutation.uncertain)
                        IntentBanner(
                          prefix: 'note',
                          offline: query.offline,
                          busy: _mutation.busy,
                          onRetry: () => _submit(retry: true),
                        ),
                      MutationError(result: _mutation.result, prefix: 'note'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
