import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/session_sheet_guard.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_input.dart';
import '../../../core/ui/staff/staff_text_area.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/await_provider.dart';
import '../../../core/utils/clock.dart';
import '../../../core/router/routes.dart';
import '../schedule/schedule_models.dart';
import '../schedule/schedule_providers.dart';
import '../session/session_context_api.dart';
import '../session/session_context_models.dart';
import 'operations_models.dart';
import 'operations_providers.dart';
import 'operations_widgets.dart';

void showMentorSessionTools(BuildContext context, WidgetRef ref, TeachingEntry entry) {
  final t = ref.read(trProvider);
  openStaffSheet(
    context,
    title: t('mentor.operations.tools'),
    subtitle: entry.className,
    builder: (sheet) => SessionSheetGuard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaffButton(
            label: t('mentor.operations.notes'),
            onPressed: () {
              Navigator.pop(sheet);
              context.push(Routes.mentorNotes(entry.session.id));
            },
          ),
          const SizedBox(height: 12),
          StaffButton(
            label: t('mentor.operations.meeting'),
            outlined: true,
            onPressed: () {
              Navigator.pop(sheet);
              context.push(Routes.mentorMeeting(entry.session.id));
            },
          ),
        ],
      ),
    ),
  );
}

class MentorNotesScreen extends ConsumerStatefulWidget {
  const MentorNotesScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<MentorNotesScreen> createState() => _MentorNotesScreenState();
}

class _MentorNotesScreenState extends ConsumerState<MentorNotesScreen> with OperationsBack<MentorNotesScreen> {
  final _content = TextEditingController(), _next = TextEditingController();
  int? _version;
  String _baseContent = '', _baseNext = '';
  TeachingNote? _latest;
  Object? _error;
  TeachingRoom? _receivedRoom;
  DateTime _receivedAt = DateTime.now();
  @override
  bool get hasDraft =>
      _content.text != _baseContent ||
      _next.text != _baseNext ||
      ref.read(mentorNoteSaveProvider(widget.sessionId)).locked;
  bool _initializing = false;
  @override
  void initState() {
    super.initState();
    _content.addListener(_changed);
    _next.addListener(_changed);
  }

  void _changed() {
    if (!_initializing) setState(() {});
  }

  @override
  void dispose() {
    _content.removeListener(_changed);
    _next.removeListener(_changed);
    _content.dispose();
    _next.dispose();
    super.dispose();
  }

  void _deny(Object? error) {
    if (error is ApiError && [403, 404].contains(error.status)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.invalidate(mentorScheduleProvider);
          context.go(Routes.mentorPage('schedule'));
        }
      });
    }
  }

  Future<void> _save({bool retry = false}) async {
    try {
      final controller = ref.read(mentorNoteSaveProvider(widget.sessionId).notifier);
      final result = retry ? await controller.retry() : await controller.save(_version!, _content.text, _next.text);
      if (mounted && result != null) {
        showStaffToast(context, ref.read(trProvider)('mentor.operations.saved'));
        exit();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _reload() async {
    try {
      ref.invalidate(mentorNoteProvider(widget.sessionId));
      ref.invalidate(mentorRoomProvider(widget.sessionId));
      final latest = await awaitWidgetProvider(ref, mentorNoteProvider(widget.sessionId).future);
      if (mounted) {
        setState(() {
          _latest = latest;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    ref.watch(appNowProvider);
    final note = ref.watch(mentorNoteProvider(widget.sessionId));
    final room = ref.watch(mentorRoomProvider(widget.sessionId));
    final command = ref.watch(mentorNoteSaveProvider(widget.sessionId));
    ref.listen(mentorRoomProvider(widget.sessionId), (_, value) => _deny(value.error));
    ref.listen(mentorNoteProvider(widget.sessionId), (_, value) => _deny(value.error));
    ref.listen(mentorNoteSaveProvider(widget.sessionId), (_, value) => _deny(value.error));
    if (_version == null && note.asData != null) {
      final data = note.requireValue;
      _version = data.version;
      _baseContent = data.content;
      _baseNext = data.nextSteps;
      _initializing = true;
      _content.text = data.content;
      _next.text = data.nextSteps;
      _initializing = false;
    }
    final current = room.asData?.value;
    if (current != null && !identical(current, _receivedRoom)) {
      _receivedRoom = current;
      _receivedAt = DateTime.now();
    }
    final deadline = current?.session.editableUntil;
    final serverNow = current?.session.asOf.add(DateTime.now().difference(_receivedAt));
    final editable =
        current != null &&
        [TeachingStatus.IN_PROGRESS, TeachingStatus.COMPLETED].contains(current.session.status) &&
        deadline != null &&
        serverNow!.isBefore(deadline);
    return protect(
      StaffPage(
        title: t('mentor.operations.notes'),
        onBack: back,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
          children: [
            if (note.isLoading) const Skeleton(height: 160),
            if (note.hasError)
              StaffDataState(
                title: t('mentor.operations.failed'),
                description: t(operationError(note.error!)),
                error: note.error,
                onRetry: () => ref.invalidate(mentorNoteProvider(widget.sessionId)),
              ),
            if (note.asData != null) ...[
              if (!editable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(t('mentor.operations.notesReadonly'), style: StaffText.caption),
                ),
              if (room.hasError)
                StaffDataState(
                  title: t('mentor.operations.failed'),
                  description: t(operationError(room.error!)),
                  error: room.error,
                  onRetry: () => ref.invalidate(mentorRoomProvider(widget.sessionId)),
                ),
              StaffTextArea(
                label: t('mentor.operations.content'),
                controller: _content,
                maxLength: 10000,
                enabled: editable && !command.locked && !command.conflict,
              ),
              StaffTextArea(
                label: t('mentor.operations.nextSteps'),
                controller: _next,
                maxLength: 5000,
                enabled: editable && !command.locked && !command.conflict,
              ),
              if (_error != null) operationFailure(t, _error!),
              if (command.error != null) operationFailure(t, command.error!),
              if (command.retryPending) ...[
                Text(t('mentor.operations.receiptRetry'), style: StaffText.caption),
                const SizedBox(height: 12),
                StaffButton(
                  label: t('mentor.operations.retrySame'),
                  loading: command.busy,
                  onPressed: () => _save(retry: true),
                ),
              ] else if (command.conflict) ...[
                StaffButton(label: t('mentor.operations.readLatest'), outlined: true, onPressed: _reload),
                if (_latest != null) ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('mentor.operations.latest'), style: StaffText.bodyStrong),
                        Text(_latest!.content, maxLines: 8, overflow: TextOverflow.ellipsis, style: StaffText.body),
                        Text(
                          _latest!.nextSteps,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: StaffText.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StaffButton(
                    label: t('mentor.operations.adoptVersion'),
                    onPressed: () {
                      setState(() {
                        _version = _latest!.version;
                        _baseContent = _latest!.content;
                        _baseNext = _latest!.nextSteps;
                        _latest = null;
                      });
                      ref.read(mentorNoteSaveProvider(widget.sessionId).notifier).reviewed();
                    },
                  ),
                ],
              ] else
                StaffButton(
                  label: t('mentor.operations.save'),
                  loading: command.busy,
                  onPressed: editable && !command.locked ? _save : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class MentorMeetingScreen extends ConsumerStatefulWidget {
  const MentorMeetingScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<MentorMeetingScreen> createState() => _MentorMeetingScreenState();
}

class _MentorMeetingScreenState extends ConsumerState<MentorMeetingScreen> with OperationsBack<MentorMeetingScreen> {
  final _url = TextEditingController();
  int? _version;
  bool _inherit = false;
  String _base = '';
  TeachingRoom? _latest;
  Object? _error;
  @override
  bool get hasDraft =>
      _inherit || _url.text.trim() != _base || ref.read(mentorMeetingSaveProvider(widget.sessionId)).locked;
  bool _initializing = false;
  @override
  void initState() {
    super.initState();
    _url.addListener(_changed);
  }

  void _changed() {
    if (!_initializing) setState(() {});
  }

  @override
  void dispose() {
    _url.removeListener(_changed);
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _url.text.trim();
    final uri = Uri.tryParse(value);
    if (!_inherit &&
        (value.length > 2048 ||
            uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      setState(() => _error = ApiError(status: 422, code: 'MEETING_URL_INVALID'));
      return;
    }
    final result = await ref
        .read(mentorMeetingSaveProvider(widget.sessionId).notifier)
        .save(_version!, _inherit ? null : value);
    if (mounted && result != null) {
      showStaffToast(context, ref.read(trProvider)('mentor.operations.saved'));
      exit();
    }
  }

  Future<void> _reload() async {
    try {
      ref.invalidate(mentorRoomProvider(widget.sessionId));
      final latest = await awaitWidgetProvider(ref, mentorRoomProvider(widget.sessionId).future);
      if (mounted) {
        setState(() {
          _latest = latest;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), room = ref.watch(mentorRoomProvider(widget.sessionId));
    final command = ref.watch(mentorMeetingSaveProvider(widget.sessionId));
    if (_version == null && room.asData != null) {
      _version = room.requireValue.session.version;
      _base = room.requireValue.meetingUrl?.toString() ?? '';
      _initializing = true;
      _url.text = _base;
      _initializing = false;
    }
    ref.listen(mentorMeetingSaveProvider(widget.sessionId), (_, value) {
      if (value.error is ApiError && [403, 404].contains((value.error as ApiError).status)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.invalidate(mentorScheduleProvider);
            context.go(Routes.mentorPage('schedule'));
          }
        });
      }
    });
    return protect(
      StaffPage(
        title: t('mentor.operations.meeting'),
        onBack: back,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
          children: [
            if (room.isLoading) const Skeleton(height: 120),
            if (room.hasError)
              StaffDataState(
                title: t('mentor.operations.failed'),
                description: t(operationError(room.error!)),
                error: room.error,
                onRetry: () => ref.invalidate(mentorRoomProvider(widget.sessionId)),
              ),
            if (room.asData != null) ...[
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  title: Text(t('mentor.operations.inheritLink'), style: StaffText.body),
                  value: _inherit,
                  onChanged: command.locked || command.conflict ? null : (v) => setState(() => _inherit = v),
                ),
              ),
              StaffInput(
                label: t('mentor.operations.url'),
                controller: _url,
                keyboardType: TextInputType.url,
                enabled: !_inherit && !command.locked && !command.conflict,
              ),
              const SizedBox(height: 16),
              if (_error != null) operationFailure(t, _error!),
              if (command.error != null) operationFailure(t, command.error!),
              if (command.retryPending || command.conflict) ...[
                Text(t('mentor.operations.meetingUnknown'), style: StaffText.caption),
                const SizedBox(height: 12),
                StaffButton(label: t('mentor.operations.readLatest'), outlined: true, onPressed: _reload),
                if (_latest != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(_latest!.meetingUrl?.toString() ?? t('mentor.room.noLink'), style: StaffText.body),
                  const SizedBox(height: 12),
                  StaffButton(
                    label: t('mentor.operations.adoptVersion'),
                    onPressed: () {
                      setState(() {
                        _version = _latest!.session.version;
                        _base = _latest!.meetingUrl?.toString() ?? '';
                        _latest = null;
                      });
                      ref.read(mentorMeetingSaveProvider(widget.sessionId).notifier).reviewed();
                    },
                  ),
                ],
              ] else
                StaffButton(
                  label: t('mentor.operations.save'),
                  loading: command.busy,
                  onPressed:
                      ![
                            TeachingStatus.SCHEDULED,
                            TeachingStatus.IN_PROGRESS,
                          ].contains(room.requireValue.session.status) ||
                          command.locked
                      ? null
                      : _save,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
