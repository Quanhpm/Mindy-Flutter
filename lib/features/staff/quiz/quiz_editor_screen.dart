import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_logic.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';
import 'quiz_models.dart';
import 'quiz_import.dart';
import 'quiz_list_screen.dart';
import 'quiz_query.dart';
import 'quiz_service.dart';
import 'quiz_widgets.dart';

class StaffQuizEditorScreen extends ConsumerStatefulWidget {
  const StaffQuizEditorScreen({
    super.key,
    required this.classId,
    required this.sessionId,
    this.id,
    this.title,
    this.initialTab = 'info',
  });
  final String classId, sessionId;
  final String? id, title;
  final String initialTab;
  @override
  ConsumerState<StaffQuizEditorScreen> createState() => _QuizEditorState();
}

class _QuizEditorState extends ConsumerState<StaffQuizEditorScreen> {
  StaffQuiz? _saved;
  Map<String, String> _metadata = {...initialQuizMetadata};
  List<QuizQuestion> _questions = [];
  List<QuizQuestion> _savedQuestions = [];
  QuizQuestion? _question;
  late String _tab = widget.initialTab;
  String _problem = '';
  Map<String, String> _errors = {}, _questionErrors = {};
  int _index = -1, _serial = 0;
  int? _menu, _deleteIndex;
  bool _busy = false,
      _importing = false,
      _retry = false,
      _checkedCreate = false,
      _newDraft = false,
      _reload = false,
      _discard = false,
      _allowLeave = false,
      _format = false;
  QuizIntent? _intent;
  QuizImport? _import;
  String? _importProblem;
  List<StaffQuiz> _candidates = [];
  final _prompt = TextEditingController(),
      _title = TextEditingController(),
      _description = TextEditingController(),
      _score = TextEditingController(text: '10'),
      _limit = TextEditingController(),
      _hour = TextEditingController(text: '18:00');
  final _options = {
    for (final label in quizLabels) label: TextEditingController(),
  };
  String _date = '';
  @override
  void dispose() {
    for (final c in [
      _prompt,
      _title,
      _description,
      _score,
      _limit,
      _hour,
      ..._options.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _controllers() {
    _title.text = _metadata['title']!;
    _description.text = _metadata['description']!;
    _score.text = _metadata['maxScore']!;
    _limit.text = _metadata['timeLimit']!;
    final due = DateTime.tryParse(_metadata['dueAt']!);
    if (due != null) {
      final d = due.toUtc().add(const Duration(hours: 7)).toIso8601String();
      _date = d.substring(0, 10);
      _hour.text = d.substring(11, 16);
    } else {
      _date = '';
    }
  }

  void _accept(StaffQuiz quiz, String kind) {
    _saved = quiz;
    if (kind == 'create' || kind == 'metadata') {
      _metadata = quiz.metadata;
      _controllers();
    }
    if (kind == 'create' || kind == 'questions') {
      _questions = [...?quiz.questions];
      _savedQuestions = [..._questions];
    }
    if (kind == 'create') _tab = 'questions';
    _intent = null;
    _problem = '';
    ref.read(quizRevisionProvider.notifier).bump();
    ref
        .read(mdyToastProvider.notifier)
        .show(ref.read(trProvider)(qu(kind == 'create' ? 'created' : 'saved')));
  }

  bool get _infoDirty =>
      !quizEqual(_metadata, _saved?.metadata ?? initialQuizMetadata);
  bool get _questionsDirty => !quizEqual(
    _questions.map((q) => q.toJson()).toList(),
    _savedQuestions.map((q) => q.toJson()).toList(),
  );
  Future<void> _execute(QuizIntent intent) async {
    setState(() {
      _busy = true;
      _problem = '';
    });
    try {
      final quiz = await ref
          .read(staffQuizServiceProvider)
          .command(intent, previous: _saved);
      if (mounted && quiz != null) setState(() => _accept(quiz, intent.kind));
    } catch (e) {
      if (mounted) {
        final error = QuizFailure.from(e);
        setState(() {
          if (error.kind == 'uncertain') {
            _intent = intent;
            _retry = false;
            _checkedCreate = false;
          } else {
            _problem = quizProblem(error);
            _intent = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _intent != null) return;
    final info = _saved == null || _tab == 'info';
    if (info) {
      final invalid = metadataErrors(_metadata, _saved == null);
      setState(() => _errors = invalid);
      if (invalid.isNotEmpty) return;
    }
    if (!info &&
        (_questions.isEmpty ||
            _questions.any((q) => questionErrors(q).isNotEmpty))) {
      return;
    }
    await _execute(
      _saved == null
          ? QuizIntent(
              kind: 'create',
              sessionId: widget.sessionId,
              metadata: Map.unmodifiable(_metadata),
            )
          : info
          ? QuizIntent(
              kind: 'metadata',
              id: _saved!.id,
              revision: _saved!.revision,
              metadata: Map.unmodifiable(_metadata),
            )
          : QuizIntent(
              kind: 'questions',
              id: _saved!.id,
              revision: _saved!.revision,
              questions: List.unmodifiable(_questions),
            ),
    );
  }

  void _begin(int index) {
    setState(() {
      _index = index;
      _question = index < 0
          ? QuizQuestion.empty('local-${++_serial}')
          : _questions[index].copyWith(options: {..._questions[index].options});
      _questionErrors = {};
      _prompt.text = _question!.prompt;
      for (final label in quizLabels) {
        _options[label]!.text = _question!.options[label] ?? '';
      }
    });
  }

  void _done([bool next = false]) {
    final q = _question;
    if (q == null) return;
    final errors = questionErrors(q);
    setState(() => _questionErrors = errors);
    if (errors.isNotEmpty) return;
    setState(() {
      final clean = q.copyWith(
        prompt: q.prompt.trim(),
        options: {for (final e in q.options.entries) e.key: e.value.trim()},
      );
      if (_index < 0) {
        _questions = [..._questions, clean];
      } else {
        _questions = [
          for (final (i, item) in _questions.indexed)
            i == _index ? clean : item,
        ];
      }
      _question = null;
    });
    if (next && _questions.length < 200) _begin(-1);
  }

  Future<void> _chooseImport() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _importProblem = null;
    });
    final result = await pickQuizImport();
    if (!mounted) return;
    setState(() {
      _importing = false;
      if (result?.fatal != null) {
        _importProblem = result!.fatal;
      } else {
        _import = result;
      }
    });
  }

  Future<void> _check() async {
    final intent = _intent;
    if (intent == null || _busy) return;
    setState(() => _busy = true);
    final service = ref.read(staffQuizServiceProvider);
    try {
      if (intent.kind == 'create') {
        final page = await service.list(
          widget.classId,
          sessionId: widget.sessionId,
          pageSize: 100,
          status: 'DRAFT',
        );
        if (!mounted) return;
        setState(() {
          _checkedCreate = true;
          _candidates = page.items
              .where(
                (q) =>
                    q.sessionId == widget.sessionId &&
                    q.status == 'DRAFT' &&
                    q.title == intent.metadata!['title']!.trim(),
              )
              .toList();
        });
      } else {
        final latest = await service.detail(intent.id!);
        if (!mounted) return;
        final matches = intent.kind == 'metadata'
            ? quizEqual(latest.metadata, {
                ...intent.metadata!,
                'title': intent.metadata!['title']!.trim(),
                'maxScore': latest.score,
              })
            : quizEqual(
                latest.questions
                    ?.map(
                      (q) => {
                        'prompt': q.prompt,
                        'options': q.options,
                        'correct': q.correct,
                      },
                    )
                    .toList(),
                intent.questions
                    ?.map(
                      (q) => {
                        'prompt': q.prompt,
                        'options': q.options,
                        'correct': q.correct,
                      },
                    )
                    .toList(),
              );
        setState(() {
          if (matches && latest.revision > intent.revision!) {
            _accept(latest, intent.kind);
          } else if (latest.revision == intent.revision &&
              latest.status == 'DRAFT') {
            _retry = true;
          } else {
            _intent = null;
            _problem = 'conflict';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _problem = quizProblem(QuizFailure.from(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadLatest() async {
    if (_saved == null) return;
    try {
      final latest = await ref
          .read(staffQuizServiceProvider)
          .detail(_saved!.id);
      if (mounted) {
        setState(() {
          _saved = latest;
          _metadata = latest.metadata;
          _controllers();
          _questions = [...?latest.questions];
          _savedQuestions = [..._questions];
          _question = null;
          _intent = null;
          _problem = '';
          _reload = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reload = false;
          _problem = quizProblem(QuizFailure.from(e));
        });
      }
    }
  }

  Future<void> _candidate(StaffQuiz q) async {
    setState(() => _busy = true);
    try {
      final detail = await ref.read(staffQuizServiceProvider).detail(q.id);
      if (mounted) {
        setState(() {
          _accept(detail, 'create');
          _candidates = [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _problem = 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _due() {
    final iso = parseVietnamTime(
      _date.split('-').reversed.join('/'),
      _hour.text,
    );
    setState(
      () => _metadata = {
        ..._metadata,
        'dueAt': iso ?? '${_date}T${_hour.text}:00+07:00',
      },
    );
  }

  Future<void> _pickDue() async {
    await showMdySheet<void>(
      context,
      builder: (ctx) => MdySheet(
        key: const Key('quiz-editor-due-sheet'),
        title: ref.read(trProvider)(qu('pickDate')),
        children: [
          CalendarDatePicker(
            initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(9999),
            onDateChanged: (date) {
              _date = date.toIso8601String().substring(0, 10);
              _due();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), offline = ref.watch(staffOfflineProvider);
    final initial = widget.id == null
        ? null
        : ref.watch(quizDetailProvider(widget.id!));
    if (_saved == null && initial?.value != null) {
      _saved = initial!.value;
      _metadata = _saved!.metadata;
      _questions = [...?_saved!.questions];
      _savedQuestions = [..._questions];
      _controllers();
    }
    final cls = ref.watch(
          teachingQueryProvider(
            TeachingRequest(
              kind: TeachingKind.klass,
              role: TeachingRole.MENTOR,
              classId: widget.classId,
            ),
          ),
        ),
        cx = ref.watch(
          teachingQueryProvider(
            TeachingRequest(
              kind: TeachingKind.context,
              role: TeachingRole.MENTOR,
              sessionId: widget.sessionId,
            ),
          ),
        );
    final mismatch =
            cx.data?.session != null &&
            cx.data!.session!.classId != widget.classId,
        fatal = cls.fatal || cx.fatal || mismatch || _problem == 'denied';
    final closed =
            cls.data?.classInfo != null &&
            !quizCanWrite(
              cls.data!.classInfo!.status.name,
              cx.data?.session?.status.name,
            ),
        frozen = _saved != null && _saved!.status != 'DRAFT';
    final editable = !_busy && _intent == null && !closed && !frozen && !fatal,
        ready = editable && !offline && cls.data?.classInfo != null;
    final dirty = _infoDirty || _questionsDirty || _question != null,
        q = _question;
    void change(String key, String value) =>
        setState(() => _metadata = {..._metadata, key: value});
    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      int? max,
      bool multiline = false,
      bool locked = false,
    }) => AttendanceField(
      id: 'quiz-editor-$key',
      label: t(qu(label)),
      controller: controller,
      max: max,
      multiline: multiline,
      disabled: !editable || locked,
      onChanged: (v) => change(
        key == 'score'
            ? 'maxScore'
            : key == 'time-limit'
            ? 'timeLimit'
            : key,
        v,
      ),
      error:
          _errors[key == 'score'
                  ? 'maxScore'
                  : key == 'time-limit'
                  ? 'timeLimit'
                  : key] ==
              null
          ? null
          : t(
              qu(
                _errors[key == 'score'
                    ? 'maxScore'
                    : key == 'time-limit'
                    ? 'timeLimit'
                    : key]!,
              ),
            ),
    );
    return QuizPage(
      prefix: 'quiz-editor',
      title: q == null
          ? t(qu(_saved == null ? 'createTitle' : 'editTitle'))
          : t(qu('questionTitle'), {
              'number': _index < 0 ? _questions.length + 1 : _index + 1,
              'count': _index < 0 ? _questions.length + 1 : _questions.length,
            }),
      subtitle: widget.title,
      onBack: () => staffBack(context),
      busy: _busy,
      dirty: !fatal && !closed && dirty,
      allowLeave: _allowLeave,
      beforeBack: () => q == null
          ? false
          : () {
              setState(() => _discard = true);
              return true;
            }(),
      footer: fatal || closed || frozen
          ? null
          : [
              if (_infoDirty || _questionsDirty)
                MdyText(
                  t(
                    qu(
                      _questionsDirty && _questions.length >= 10
                          ? 'unsavedMany'
                          : 'unsaved',
                    ),
                    {'count': _questions.length},
                  ),
                  key: const Key('quiz-editor-unsaved'),
                ),
              if (offline) MdyText(t(qu('needOnline'))),
              if (q != null)
                Row(
                  spacing: MdySpace.s8,
                  children: [
                    if (_questions.length < 199)
                      Expanded(
                        child: MdyButton(
                          key: const Key('quiz-question-next'),
                          variant: MdyButtonVariant.secondary,
                          label: t(qu('nextQuestion')),
                          disabled: !editable,
                          onPressed: () => _done(true),
                        ),
                      ),
                    Expanded(
                      child: MdyButton(
                        key: const Key('quiz-question-done'),
                        label: t(qu('done')),
                        disabled: !editable,
                        onPressed: _done,
                      ),
                    ),
                  ],
                )
              else ...[
                MdyButton(
                  key: Key(
                    _saved == null
                        ? 'quiz-editor-create'
                        : _tab == 'info'
                        ? 'quiz-editor-save-info'
                        : 'quiz-editor-save-questions',
                  ),
                  label: t(
                    qu(
                      _saved == null
                          ? 'createDraft'
                          : _tab == 'info'
                          ? 'saveInfo'
                          : 'saveQuestions',
                    ),
                  ),
                  busy: _busy,
                  disabled:
                      !ready ||
                      (_saved != null &&
                          (_tab == 'info'
                              ? !_infoDirty
                              : !_questionsDirty || _questions.isEmpty)),
                  onPressed: _save,
                ),
                if (_saved != null)
                  MdyButton(
                    key: const Key('quiz-editor-preview'),
                    variant: MdyButtonVariant.text,
                    label: t(qu(dirty ? 'saveBeforeReview' : 'preview')),
                    disabled: dirty || _busy || _intent != null || offline,
                    onPressed: () {
                      setState(() => _allowLeave = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          context.pushReplacement(
                            StaffQuizRoutes.detail(widget.classId, _saved!.id),
                          );
                        }
                      });
                    },
                  ),
              ],
            ],
      rows: !fatal && _saved != null && _tab == 'questions' && q == null
          ? [
              for (final (index, question) in _questions.indexed)
                MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MdyPressed(
                            key: Key('quiz-editor-question-${question.key}'),
                            enabled: editable,
                            onTap: () => _begin(index),
                            builder: (ctx, pressed) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: MdySpace.s6,
                              children: [
                                MdyText('${index + 1}. ${question.prompt}'),
                                MdyChip(
                                  t(qu('correctIs'), {
                                    'label': question.correct ?? '',
                                  }),
                                  variant: MdyChipVariant.success,
                                ),
                              ],
                            ),
                          ),
                        ),
                        MdyButton(
                          key: Key('quiz-editor-question-menu-${question.key}'),
                          variant: MdyButtonVariant.text,
                          disabled: !editable,
                          semanticLabel: t(qu('questionMenu'), {
                            'number': index + 1,
                          }),
                          onPressed: () => setState(() => _menu = index),
                          child: const MdyIcon(MdyIcons.moreVert),
                        ),
                      ],
                    ),
                  ],
                ),
            ]
          : const [],
      overlays: [
        if (_menu case final index?)
          MdyInlineSheet(
            key: const Key('quiz-question-menu'),
            title: t(qu('questionMenu'), {'number': index + 1}),
            onClose: () => setState(() => _menu = null),
            children: [
              MdyButton(
                key: const Key('quiz-question-edit'),
                label: t(qu('edit')),
                onPressed: () {
                  setState(() => _menu = null);
                  _begin(index);
                },
              ),
              if (index > 0)
                MdyButton(
                  key: const Key('quiz-question-move-up'),
                  label: t(qu('moveUp')),
                  onPressed: () => setState(() {
                    final item = _questions.removeAt(index);
                    _questions.insert(index - 1, item);
                    _menu = null;
                  }),
                ),
              if (index < _questions.length - 1)
                MdyButton(
                  key: const Key('quiz-question-move-down'),
                  label: t(qu('moveDown')),
                  onPressed: () => setState(() {
                    final item = _questions.removeAt(index);
                    _questions.insert(index + 1, item);
                    _menu = null;
                  }),
                ),
              MdyButton(
                key: const Key('quiz-question-delete'),
                variant: MdyButtonVariant.danger,
                label: t(qu('remove')),
                onPressed: () => setState(() {
                  _deleteIndex = index;
                  _menu = null;
                }),
              ),
            ],
          ),
        if (_import case final imported?)
          MdyInlineSheet(
            key: const Key('quiz-import-preview'),
            title: t(qu('importPreviewTitle')),
            onClose: () => setState(() => _import = null),
            children: [
              MdyText(imported.name),
              MdyText(
                t(
                  qu(
                    imported.questions.isEmpty
                        ? 'importNothing'
                        : 'importFound',
                  ),
                  {'count': imported.questions.length},
                ),
                key: const Key('quiz-import-found'),
              ),
              if (imported.issues.isNotEmpty) ...[
                MdyText(
                  t(qu('importSkipped'), {'count': imported.issues.length}),
                  key: const Key('quiz-import-issues'),
                ),
                for (final issue in imported.issues.take(5))
                  MdyText(
                    t(qu('importLine'), {
                      'line': issue.line,
                      'reason': t(qu(issue.code)),
                    }),
                  ),
                if (imported.issues.length > 5)
                  MdyText(
                    t(qu('importMoreIssues'), {
                      'count': imported.issues.length - 5,
                    }),
                  ),
              ],
              if (_questions.length + imported.questions.length > 200)
                MdyAlert(
                  t(qu('importOverLimit'), {'current': _questions.length}),
                  key: const Key('quiz-import-over-limit'),
                )
              else if (imported.questions.isNotEmpty)
                MdyText(t(qu('importAppendHint'))),
              MdyButton(
                key: const Key('quiz-import-confirm'),
                label: t(qu('importConfirm'), {
                  'count': imported.questions.length,
                }),
                disabled:
                    imported.questions.isEmpty ||
                    _questions.length + imported.questions.length > 200,
                onPressed: () => setState(() {
                  _questions = [..._questions, ...imported.questions];
                  _import = null;
                }),
              ),
              MdyButton(
                key: const Key('quiz-import-cancel'),
                variant: MdyButtonVariant.text,
                label: t(qu('cancel')),
                onPressed: () => setState(() => _import = null),
              ),
            ],
          ),
        if (_deleteIndex case final index?)
          MdyInlineDialog(
            key: const Key('quiz-question-delete-dialog'),
            title: t(qu('deleteQuestion'), {'number': index + 1}),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _deleteIndex = null),
            children: [
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(qu('cancel')),
                onPressed: () => setState(() => _deleteIndex = null),
              ),
              MdyButton(
                key: const Key('quiz-question-delete-confirm'),
                variant: MdyButtonVariant.danger,
                label: t(qu('remove')),
                onPressed: () => setState(() {
                  _questions = [
                    for (final (i, item) in _questions.indexed)
                      if (i != index) item,
                  ];
                  _deleteIndex = null;
                }),
              ),
            ],
          ),
        if (_discard)
          MdyInlineDialog(
            key: const Key('quiz-question-discard-dialog'),
            title: t(qu('questionLeave')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _discard = false),
            children: [
              MdyButton(
                key: const Key('quiz-question-discard-stay'),
                label: t(qu('keepEditing')),
                onPressed: () => setState(() => _discard = false),
              ),
              MdyButton(
                key: const Key('quiz-question-discard-confirm'),
                variant: MdyButtonVariant.danger,
                label: t(qu('discard')),
                onPressed: () => setState(() {
                  _question = null;
                  _discard = false;
                }),
              ),
            ],
          ),
        if (_reload)
          MdyInlineDialog(
            key: const Key('quiz-editor-reload-dialog'),
            title: t(qu('reload')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _reload = false),
            children: [
              MdyText(t(qu('leaveBody'))),
              MdyButton(
                label: t(qu('cancel')),
                onPressed: () => setState(() => _reload = false),
              ),
              MdyButton(
                key: const Key('quiz-editor-reload-confirm'),
                variant: MdyButtonVariant.danger,
                label: t(qu('reload')),
                onPressed: _reloadLatest,
              ),
            ],
          ),
        if (_newDraft)
          MdyInlineDialog(
            key: const Key('quiz-new-draft-dialog'),
            title: t(qu('createNew')),
            icon: MdyIcons.warning,
            onClose: () => setState(() => _newDraft = false),
            children: [
              MdyText(t(qu('duplicateWarning'))),
              MdyButton(
                label: t(qu('cancel')),
                onPressed: () => setState(() => _newDraft = false),
              ),
              MdyButton(
                key: const Key('quiz-new-draft-confirm'),
                label: t(qu('confirm')),
                onPressed: () => setState(() {
                  _intent = null;
                  _checkedCreate = false;
                  _candidates = [];
                  _newDraft = false;
                }),
              ),
            ],
          ),
      ],
      children: [
        if (fatal)
          MdyAlert(t(qu('denied')), key: const Key('quiz-editor-denied'))
        else
          QuizGate(
            hasData: widget.id == null || initial?.value != null,
            busy: initial?.isLoading ?? false,
            error: initial?.error == null
                ? null
                : QuizFailure.from(initial!.error!),
            prefix: 'quiz-editor',
            retry: () => ref.invalidate(quizDetailProvider(widget.id!)),
            children: [
              if (frozen) ...[
                MdyAlert(t(qu('frozen')), key: const Key('quiz-editor-frozen')),
                MdyButton(
                  label: t(qu('detailTitle')),
                  onPressed: () => context.pushReplacement(
                    StaffQuizRoutes.detail(widget.classId, _saved!.id),
                  ),
                ),
              ] else ...[
                if (closed)
                  MdyAlert(
                    t(qu('closed')),
                    key: const Key('quiz-editor-closed'),
                  ),
                if (_saved != null && q == null)
                  Row(
                    spacing: MdySpace.s4,
                    children: [
                      for (final tab in ['info', 'questions'])
                        Expanded(
                          child: MdyButton(
                            key: Key('quiz-editor-tab-$tab'),
                            variant: _tab == tab
                                ? MdyButtonVariant.primary
                                : MdyButtonVariant.secondary,
                            label:
                                '${t(qu(tab))}${tab == 'questions' ? ' (${_questions.length})' : ''}',
                            onPressed: () => setState(() => _tab = tab),
                          ),
                        ),
                    ],
                  ),
                if (_problem.isNotEmpty) ...[
                  MdyAlert(
                    t(qu(_problem)),
                    warning: true,
                    key: const Key('quiz-editor-problem'),
                  ),
                  if (_problem == 'conflict')
                    MdyButton(
                      key: const Key('quiz-editor-reload'),
                      variant: MdyButtonVariant.text,
                      label: t(qu('reload')),
                      onPressed: () => setState(() => _reload = true),
                    ),
                ],
                if (_intent != null) ...[
                  MdyAlert(
                    t(qu('uncertain')),
                    warning: true,
                    key: const Key('quiz-editor-uncertain'),
                  ),
                  if (!offline)
                    MdyButton(
                      key: const Key('quiz-editor-check'),
                      label: t(qu('check')),
                      onPressed: _check,
                    ),
                  if (_retry && !offline)
                    MdyButton(
                      key: const Key('quiz-editor-resend'),
                      label: t(qu('resend')),
                      disabled: _busy,
                      onPressed: () => _execute(_intent!),
                    ),
                  if (_checkedCreate) ...[
                    MdyText(t(qu('maybeCreated'))),
                    MdyButton(
                      key: const Key('quiz-editor-new-draft'),
                      variant: MdyButtonVariant.text,
                      label: t(qu('createNew')),
                      disabled: _busy || offline,
                      onPressed: () => setState(() => _newDraft = true),
                    ),
                  ],
                  for (final candidate in _candidates)
                    MdyButton(
                      label: '${candidate.title} · ${t(qu('edit'))}',
                      disabled: _busy,
                      onPressed: () => _candidate(candidate),
                    ),
                ],
                if (q != null)
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    gap: MdySpace.s16,
                    children: [
                      AttendanceField(
                        id: 'quiz-question-prompt',
                        label: t(qu('prompt')),
                        controller: _prompt,
                        max: 5000,
                        disabled: !editable,
                        error: _questionErrors['prompt'] == null
                            ? null
                            : t(qu(_questionErrors['prompt']!)),
                        onChanged: (v) =>
                            setState(() => _question = q.copyWith(prompt: v)),
                      ),
                      MdyText(t(qu('chooseCorrect'))),
                      for (final label in quizLabels)
                        MdyCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(MdySpace.s16),
                          gap: MdySpace.s6,
                          children: [
                            AttendanceField(
                              id: 'quiz-question-option-$label',
                              label: t(qu('option'), {'label': label}),
                              controller: _options[label]!,
                              max: 2000,
                              disabled: !editable,
                              error: _questionErrors[label] == null
                                  ? null
                                  : t(qu(_questionErrors[label]!)),
                              onChanged: (v) => setState(
                                () => _question = q.copyWith(
                                  options: {...q.options, label: v},
                                ),
                              ),
                            ),
                            Semantics(
                              checked: q.correct == label,
                              inMutuallyExclusiveGroup: true,
                              child: MdyButton(
                                key: Key('quiz-question-correct-$label'),
                                variant: q.correct == label
                                    ? MdyButtonVariant.primary
                                    : MdyButtonVariant.secondary,
                                label: t(
                                  qu(
                                    q.correct == label
                                        ? 'correct'
                                        : 'markCorrect',
                                  ),
                                ),
                                disabled: !editable,
                                onPressed: () => setState(
                                  () => _question = q.copyWith(correct: label),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_questionErrors['correctOption'] != null)
                        MdyAlert(
                          t(qu('correctRequired')),
                          key: const Key('quiz-question-correct-error'),
                        ),
                      MdyText(t(qu('memory'))),
                    ],
                  )
                else if (_saved == null || _tab == 'info') ...[
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    children: [
                      MdyText(t(qu('sectionGeneral'))),
                      field('title', 'titleField', _title, max: 250),
                      field(
                        'description',
                        'description',
                        _description,
                        max: 20000,
                        multiline: true,
                      ),
                    ],
                  ),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    children: [
                      MdyText(t(qu('sectionGrading'))),
                      Row(
                        spacing: MdySpace.s8,
                        children: [
                          for (final purpose in ['TEST', 'HOMEWORK'])
                            Expanded(
                              child: MdyButton(
                                key: Key('quiz-editor-purpose-$purpose'),
                                label: t(qu(purpose)),
                                variant: _metadata['purpose'] == purpose
                                    ? MdyButtonVariant.primary
                                    : MdyButtonVariant.secondary,
                                disabled: _saved != null || !editable,
                                onPressed: () => change('purpose', purpose),
                              ),
                            ),
                        ],
                      ),
                      if (_errors['purpose'] != null)
                        MdyAlert(
                          t(qu(_errors['purpose']!)),
                          key: const Key('quiz-editor-purpose-error'),
                        ),
                      field('score', 'score', _score, locked: _saved != null),
                      MdyText(
                        t(qu('lockedConfig')),
                        key: const Key('quiz-editor-locked-config'),
                      ),
                    ],
                  ),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    children: [
                      MdyText(t(qu('sectionTime'))),
                      MdyButton(
                        key: const Key('quiz-editor-due-date'),
                        variant: MdyButtonVariant.secondary,
                        label: _date.isEmpty
                            ? t(qu('pickDate'))
                            : _date.split('-').reversed.join('/'),
                        disabled: !editable,
                        onPressed: _pickDue,
                      ),
                      if (_date.isNotEmpty) ...[
                        AttendanceField(
                          id: 'quiz-editor-due-time',
                          label: t(qu('hour')),
                          controller: _hour,
                          multiline: false,
                          disabled: !editable,
                          onChanged: (_) => _due(),
                        ),
                        MdyButton(
                          key: const Key('quiz-editor-due-clear'),
                          variant: MdyButtonVariant.text,
                          label: t(qu('clearDue')),
                          disabled: !editable,
                          onPressed: () => setState(() {
                            _date = '';
                            _metadata = {..._metadata, 'dueAt': ''};
                          }),
                        ),
                      ],
                      if (_errors['dueAt'] != null)
                        MdyAlert(
                          t(qu(_errors['dueAt']!)),
                          key: const Key('quiz-editor-due-error'),
                        ),
                      field('time-limit', 'timeLimit', _limit),
                      MdyText(t(qu('timerHint'))),
                      if ((DateTime.tryParse(
                            _metadata['dueAt']!,
                          )?.isBefore(DateTime.now()) ??
                          false))
                        MdyAlert(
                          t(qu('duePast')),
                          warning: true,
                          key: const Key('quiz-editor-due-warning'),
                        ),
                    ],
                  ),
                  MdyText(t(qu('memory'))),
                ] else
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    children: [
                      MdyText(t(qu('sectionAdd'))),
                      if (_questions.isEmpty)
                        MdyText(
                          '${t(qu('noQuestions'))} ${t(qu('needOne'))}',
                          key: const Key('quiz-editor-no-questions'),
                        ),
                      if (_questions.length < 200) ...[
                        Row(
                          spacing: MdySpace.s8,
                          children: [
                            Expanded(
                              child: MdyButton(
                                key: const Key('quiz-editor-add-question'),
                                icon: MdyIcons.add,
                                label: t(qu('addQuestion')),
                                disabled: !editable || _importing,
                                onPressed: () => _begin(-1),
                              ),
                            ),
                            Expanded(
                              child: MdyButton(
                                key: const Key('quiz-editor-import'),
                                variant: MdyButtonVariant.secondary,
                                icon: MdyIcons.uploadFile,
                                label: t(qu('importFile')),
                                disabled: !editable,
                                busy: _importing,
                                onPressed: _chooseImport,
                              ),
                            ),
                          ],
                        ),
                        if (_importProblem != null)
                          MdyAlert(
                            t(qu(_importProblem!)),
                            key: const Key('quiz-import-error'),
                          ),
                        MdyButton(
                          key: const Key('quiz-import-format-toggle'),
                          variant: MdyButtonVariant.text,
                          label: t(
                            qu(
                              _format ? 'importFormatHide' : 'importFormatShow',
                            ),
                          ),
                          onPressed: () => setState(() => _format = !_format),
                        ),
                        if (_format)
                          MdyText(
                            '${t(qu('importFormatIntro'))}\nquestion,A,B,C,D,correct\n"2 + 2 = ?",3,4,5,6,B\n\nCâu 1: 2 + 2 = ?\nA. 3\nB. 4\nC. 5\nD. 6\nĐáp án: B',
                            key: const Key('quiz-import-format'),
                          ),
                      ] else
                        MdyText(t(qu('maxQuestions'))),
                      MdyText(t(qu('memory'))),
                    ],
                  ),
              ],
            ],
          ),
      ],
    );
  }
}
