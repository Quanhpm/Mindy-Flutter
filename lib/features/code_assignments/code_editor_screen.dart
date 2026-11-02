import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/states.dart';
import 'code_custom_input_sheet.dart';
import 'code_editor.dart';
import 'code_models.dart';
import 'code_providers.dart';
import 'code_result_sheet.dart';
import 'code_widgets.dart';

/// Editor toàn màn hình: chọn ngôn ngữ, autosave nháp, Chạy thử, Nộp bài.
class CodeEditorScreen extends ConsumerStatefulWidget {
  const CodeEditorScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends ConsumerState<CodeEditorScreen> {
  CodeLanguageKey? _language;

  /// Tăng khi người dùng chọn tải bản nháp mới nhất: dựng lại editor với nội dung server.
  int _generation = 0;

  void _back() => context.canPop() ? context.pop() : context.go(Routes.codeAssignment(widget.assignmentId));

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final value = ref.watch(codeAssignmentProvider(widget.assignmentId));
    final assignment = value.value?.assignment;
    Widget body;
    if (assignment == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: AsyncView<({StudentCodeAssignment assignment, DateTime receivedAt})>(
          value: value,
          onRetry: () => ref.invalidate(codeAssignmentProvider(widget.assignmentId)),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    } else {
      final language = assignment.language(_language ?? assignment.languages.first.key).key;
      final key = (assignmentId: widget.assignmentId, language: language);
      final draft = ref.watch(codeDraftProvider(key));
      body = draft.hasValue && !draft.isLoading
          ? _Workspace(
              key: ValueKey('${language.name}-$_generation'),
              assignment: assignment,
              draftKey: key,
              initial: draft.value!.draft,
              onLanguage: (next) => setState(() => _language = next),
              onReload: () {
                ref.read(codeDraftProvider(key).notifier).reload();
                setState(() => _generation++);
              },
              onBack: _back,
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncView<DraftState>(
                value: draft,
                onRetry: () => ref.invalidate(codeDraftProvider(key)),
                data: (_) => const Skeleton(height: 320),
              ),
            );
    }
    return Scaffold(
      key: const Key('code-editor-screen'),
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: assignment == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(title: t('code.editor.title'), status: null, onBack: _back, t: t),
                  body,
                ],
              )
            : body,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.status, required this.onBack, required this.t});
  final String title;
  final String? status;
  final VoidCallback onBack;
  final Translator t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: t('learning.back'),
          excludeSemantics: true,
          child: InkWell(
            key: const Key('code-editor-back'),
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox.square(dimension: 44, child: Center(child: MindyIcon(MindyIconName.back))),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.forest),
            ),
          ),
        ),
        if (status != null)
          Semantics(
            liveRegion: true,
            child: Text(status!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
      ],
    ),
  );
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({
    super.key,
    required this.assignment,
    required this.draftKey,
    required this.initial,
    required this.onLanguage,
    required this.onReload,
    required this.onBack,
  });

  final StudentCodeAssignment assignment;
  final DraftKey draftKey;
  final CodeDraft initial;
  final ValueChanged<CodeLanguageKey> onLanguage;
  final VoidCallback onReload;
  final VoidCallback onBack;

  @override
  ConsumerState<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace> {
  late final _controller = TextEditingController(text: widget.initial.sourceCode);
  final _undo = UndoHistoryController();
  Timer? _debounce;
  String _lastText = '';
  List<String> _customTexts = const [];

  static const _autosave = Duration(milliseconds: 1500);

  StudentCodeAssignment get _a => widget.assignment;
  bool get _closed => _a.status == AssignmentStatus.ARCHIVED || _a.deadlinePassed;

  @override
  void initState() {
    super.initState();
    _lastText = _controller.text;
    _controller.addListener(_changed);
  }

  void _changed() {
    if (_controller.text == _lastText) return; // chỉ đổi vùng chọn
    _lastText = _controller.text;
    _debounce?.cancel();
    if (!_closed) _debounce = Timer(_autosave, _flush);
  }

  /// Lưu ngay bản đang gõ (rời màn, đổi ngôn ngữ, trước khi nộp).
  Future<void> _flush() async {
    _debounce?.cancel();
    if (_closed) return;
    await ref.read(codeDraftProvider(widget.draftKey).notifier).save(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    _undo.dispose();
    super.dispose();
  }

  void _leave(VoidCallback next) {
    // Gửi lệnh lưu trước khi rời; request vẫn tới server dù màn đã đóng.
    unawaited(_flush());
    next();
  }

  Future<void> _run({List<Object?>? customArgs}) async {
    FocusScope.of(context).unfocus();
    final result = await ref
        .read(codeCommandProvider(_a.assignmentId).notifier)
        .run(widget.draftKey.language, _controller.text, customArgs: customArgs);
    if (!mounted || result == null) return;
    await showAppSheet<void>(context, (_) => RunResultView(result: result), initialSize: 0.85);
  }

  /// Chạy thử với một bộ input học viên tự nhập (ngoài các ví dụ của đề).
  Future<void> _runCustom() async {
    FocusScope.of(context).unfocus();
    final input = await showAppSheet<CustomInput>(
      context,
      (_) => CodeCustomInputSheet(signature: _a.problem.signature, initial: _customTexts),
      initialSize: 0.75,
    );
    if (!mounted || input == null) return;
    _customTexts = input.texts;
    await _run(customArgs: input.args);
  }

  Future<void> _submit({bool retry = false}) async {
    FocusScope.of(context).unfocus();
    final t = ref.read(trProvider);
    if (!retry) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(t('code.editor.confirmTitle')),
          content: Text(
            t('code.editor.confirmBody', {
              'left': _a.attemptsRemaining,
              'language': t('code.language.${widget.draftKey.language.name}'),
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(t('code.editor.cancel'))),
            TextButton(
              key: const Key('code-editor-confirm-submit'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(t('code.editor.submit')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    unawaited(_flush());
    final submission = await ref
        .read(codeCommandProvider(_a.assignmentId).notifier)
        .submit(widget.draftKey.language, _controller.text, retry: retry);
    if (!mounted || submission == null) return;
    await showAppSheet<void>(context, (_) => SubmissionResultView(submissionId: submission.id), initialSize: 0.85);
  }

  String? _saveLabel(Translator t, DraftState? draft) => switch (draft?.save) {
    DraftSave.saving => t('code.editor.saving'),
    DraftSave.saved => t('code.editor.saved'),
    DraftSave.failed => t('code.editor.saveFailed'),
    DraftSave.conflict => t('code.editor.conflictShort'),
    _ => _closed ? t('code.editor.readOnly') : null,
  };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final draft = ref.watch(codeDraftProvider(widget.draftKey)).value;
    final command = ref.watch(codeCommandProvider(_a.assignmentId));
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canSubmit = _a.canSubmit && !_closed && _a.inFlightSubmissionId == null && _a.attemptsRemaining > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: _a.title, status: _saveLabel(t, draft), onBack: () => _leave(widget.onBack), t: t),
        if (_a.languages.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final l in _a.languages)
                  ChoiceChip(
                    key: Key('code-language-${l.key.name}'),
                    label: Text(l.displayName),
                    selected: l.key == widget.draftKey.language,
                    onSelected: command.busy || l.key == widget.draftKey.language
                        ? null
                        : (_) => _leave(() => widget.onLanguage(l.key)),
                  ),
              ],
            ),
          ),
        if (draft?.save == DraftSave.conflict)
          Container(
            color: AppColors.peach,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text(t('code.editor.conflict'), style: const TextStyle(fontSize: 13))),
                TextButton(
                  key: const Key('code-editor-reload'),
                  onPressed: widget.onReload,
                  child: Text(t('code.editor.reload')),
                ),
              ],
            ),
          ),
        Expanded(
          child: CodeEditorField(
            controller: _controller,
            undo: _undo,
            label: t('code.editor.label'),
            readOnly: _closed || draft?.save == DraftSave.conflict,
          ),
        ),
        if (!_closed)
          CodeKeyBar(
            controller: _controller,
            undo: _undo,
            undoLabel: t('code.editor.undo'),
            redoLabel: t('code.editor.redo'),
            tabLabel: t('code.editor.tab'),
          ),
        if (command.error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CodeErrorText(command.error!, t: t)),
        if (command.busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.mint),
        if (!keyboard)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: command.retryPending
                ? MindyButton(
                    key: const Key('code-editor-retry-submit'),
                    label: t('code.editor.retrySubmit'),
                    loading: command.busy,
                    onPressed: () => _submit(retry: true),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('code-editor-run-custom'),
                          onPressed: _closed || command.busy ? null : _runCustom,
                          child: Text(t('code.editor.runCustom')),
                        ),
                      ),
                      Row(
                        children: [
                      Expanded(
                        child: MindyButton(
                          key: const Key('code-editor-run'),
                          label: t('code.editor.run'),
                          variant: ButtonVariant.outline,
                          onPressed: _closed || command.busy ? null : _run,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MindyButton(
                          key: const Key('code-editor-submit'),
                          label: t('code.editor.submit'),
                          onPressed: !canSubmit || command.busy ? null : _submit,
                        ),
                      ),
                        ],
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
