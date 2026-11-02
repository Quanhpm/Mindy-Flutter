import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';
import 'quiz_models.dart';
import 'quiz_list_screen.dart';
import 'quiz_query.dart';
import 'quiz_service.dart';
import 'quiz_widgets.dart';

class StaffQuizDetailScreen extends ConsumerStatefulWidget {
  const StaffQuizDetailScreen({
    super.key,
    required this.classId,
    required this.id,
  });
  final String classId, id;
  @override
  ConsumerState<StaffQuizDetailScreen> createState() => _QuizDetailState();
}

class _QuizDetailState extends ConsumerState<StaffQuizDetailScreen> {
  String? _dialog, _answerStatus;
  String _error = '';
  bool _busy = false,
      _answers = false,
      _expanded = false,
      _retry = false,
      _reasonError = false,
      _allowLeave = false;
  QuizIntent? _intent;
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _execute(QuizIntent command) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(staffQuizServiceProvider).command(command);
      if (!mounted) return;
      setState(() {
        _intent = null;
        _dialog = null;
        _allowLeave = command.kind == 'delete';
      });
      ref.read(quizRevisionProvider.notifier).bump();
      ref
          .read(mdyToastProvider.notifier)
          .show(
            ref.read(trProvider)(
              qu(
                command.kind == 'delete'
                    ? 'deleted'
                    : command.kind == 'publish'
                    ? 'published'
                    : 'archived',
              ),
            ),
          );
      if (command.kind == 'delete') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) staffBack(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final error = QuizFailure.from(e);
      setState(() {
        _dialog = null;
        if (error.kind == 'uncertain') {
          _intent = command;
          _retry = false;
        } else {
          _intent = null;
          _error = quizProblem(error);
        }
      });
      if (['conflict', 'denied', 'notFound'].contains(error.kind)) {
        ref.invalidate(quizDetailProvider(widget.id));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final intent = _intent;
    if (intent == null || _busy) return;
    setState(() => _busy = true);
    StaffQuiz? latest;
    try {
      latest = await ref.read(staffQuizServiceProvider).detail(intent.id!);
    } catch (e) {
      final error = QuizFailure.from(e);
      if (error.kind != 'notFound' || intent.kind != 'delete') {
        if (mounted) {
          setState(() {
            _error = quizProblem(error);
            _busy = false;
          });
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (intent.kind == 'delete' && latest == null ||
        intent.kind == 'publish' && latest?.status == 'PUBLISHED' ||
        intent.kind == 'archive' && latest?.status == 'ARCHIVED') {
      setState(() {
        _intent = null;
        _allowLeave = intent.kind == 'delete';
      });
      ref.read(quizRevisionProvider.notifier).bump();
      ref
          .read(mdyToastProvider.notifier)
          .show(ref.read(trProvider)(qu('saved')));
      if (intent.kind == 'delete') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) staffBack(context);
        });
      }
    } else if (latest?.revision == intent.revision &&
        (intent.kind == 'archive'
            ? latest?.status == 'PUBLISHED'
            : latest?.status == 'DRAFT')) {
      setState(() => _retry = true);
    } else {
      setState(() {
        _intent = null;
        _error = 'conflict';
      });
      ref.invalidate(quizDetailProvider(widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        q = ref.watch(quizDetailProvider(widget.id)),
        item = q.hasError ? null : q.value,
        offline = ref.watch(staffOfflineProvider);
    final cls = ref.watch(
      teachingQueryProvider(
        TeachingRequest(
          kind: TeachingKind.klass,
          role: TeachingRole.MENTOR,
          classId: widget.classId,
        ),
      ),
    );
    final cx = item == null
        ? null
        : ref.watch(
            teachingQueryProvider(
              TeachingRequest(
                kind: TeachingKind.context,
                role: TeachingRole.MENTOR,
                sessionId: item.sessionId,
              ),
            ),
          );
    final fatal =
        cls.fatal ||
        cx?.fatal == true ||
        _error == 'denied' ||
        cx?.data?.session != null &&
            cx!.data!.session!.classId != widget.classId;
    final closed =
        _error == 'closed' ||
        cls.data?.classInfo != null &&
            !quizCanWrite(
              cls.data!.classInfo!.status.name,
              cx?.data?.session?.status.name,
            );
    if (item != null && _answerStatus != '${item.id}:${item.status}') {
      _answerStatus = '${item.id}:${item.status}';
      _answers = item.status == 'DRAFT';
    }
    final blocked = _busy || offline || _intent != null;
    void edit(String tab) {
      if (item != null) {
        context.push(
          StaffQuizRoutes.editor(
            widget.classId,
            item.sessionId,
            id: item.id,
            tab: tab,
          ),
        );
      }
    }

    void send() {
      if (item == null || _dialog == null || blocked) return;
      if (_dialog == 'archive' &&
          (_reason.text.trim().isEmpty || _reason.text.trim().length > 2000)) {
        setState(() => _reasonError = true);
        return;
      }
      _execute(
        QuizIntent(
          kind: _dialog!,
          id: item.id,
          revision: item.revision,
          reason: _dialog == 'archive' ? _reason.text.trim() : null,
        ),
      );
    }

    return QuizPage(
      prefix: 'quiz-detail',
      title: t(qu('detailTitle')),
      onBack: () => staffBack(context),
      refresh: () async {
        ref.invalidate(quizDetailProvider(widget.id));
        await ref.read(quizDetailProvider(widget.id).future);
      },
      busy: _busy,
      dirty: _intent != null,
      allowLeave: _allowLeave,
      rows: fatal
          ? const []
          : [
              for (final (i, question)
                  in (item?.questions ?? const <QuizQuestion>[]).indexed)
                QuizQuestionRead(
                  question: question,
                  index: i,
                  answers: _answers,
                ),
            ],
      footer: !fatal && item != null && !closed && item.status != 'ARCHIVED'
          ? [
              if (offline) MdyText(t(qu('needOnline'))),
              if (item.status == 'DRAFT') ...[
                if (item.questions?.isEmpty ?? true) MdyText(t(qu('needOne'))),
                MdyButton(
                  key: const Key('quiz-detail-publish'),
                  label: t(qu('publish')),
                  disabled: blocked || (item.questions?.isEmpty ?? true),
                  onPressed: () => setState(() => _dialog = 'publish'),
                ),
                Row(
                  spacing: MdySpace.s8,
                  children: [
                    Expanded(
                      child: MdyButton(
                        key: const Key('quiz-detail-edit'),
                        variant: MdyButtonVariant.secondary,
                        icon: MdyIcons.edit,
                        label: t(qu('edit')),
                        disabled: blocked,
                        onPressed: () => edit('info'),
                      ),
                    ),
                    Expanded(
                      child: MdyButton(
                        key: const Key('quiz-detail-delete'),
                        variant: MdyButtonVariant.danger,
                        icon: MdyIcons.delete,
                        label: t(qu('deleteDraft')),
                        disabled: blocked,
                        onPressed: () => setState(() => _dialog = 'delete'),
                      ),
                    ),
                  ],
                ),
              ] else
                MdyButton(
                  key: const Key('quiz-detail-archive'),
                  variant: MdyButtonVariant.danger,
                  label: t(qu('archive')),
                  disabled: blocked,
                  onPressed: () => setState(() => _dialog = 'archive'),
                ),
            ]
          : null,
      overlays: [
        if (_dialog == 'archive')
          MdyInlineSheet(
            key: const Key('quiz-detail-archive-sheet'),
            title: t(qu('archiveTitle')),
            busy: _busy,
            onClose: () => setState(() => _dialog = null),
            children: [
              MdyText(t(qu('archiveBody'))),
              AttendanceField(
                id: 'quiz-detail-archive-reason',
                label: t(qu('reason')),
                controller: _reason,
                max: 2000,
                disabled: _busy,
                onChanged: (_) => setState(() {}),
              ),
              if (_reasonError)
                MdyAlert(
                  t(qu('reasonRequired')),
                  key: const Key('quiz-detail-reason-error'),
                ),
              MdyButton(
                key: const Key('quiz-detail-archive-confirm'),
                variant: MdyButtonVariant.danger,
                label: t(qu('archive')),
                busy: _busy,
                disabled: blocked,
                onPressed: send,
              ),
            ],
          ),
        if (_dialog == 'publish' || _dialog == 'delete')
          MdyInlineDialog(
            key: Key('quiz-detail-$_dialog-dialog'),
            title: t(
              qu(_dialog == 'publish' ? 'publishTitle' : 'deleteDraftTitle'),
            ),
            icon: MdyIcons.warning,
            busy: _busy,
            onClose: () => setState(() => _dialog = null),
            children: [
              MdyText(item?.title ?? ''),
              if (_dialog == 'publish' && item != null) ...[
                MdyText(
                  t(qu('questionsCount'), {
                    'count': item.questions?.length ?? 0,
                  }),
                ),
                QuizConfig(item: item, prefix: 'quiz-publish'),
              ],
              MdyText(
                t(qu(_dialog == 'publish' ? 'publishBody' : 'deleteDraftBody')),
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(qu('cancel')),
                disabled: _busy,
                onPressed: () => setState(() => _dialog = null),
              ),
              MdyButton(
                key: Key('quiz-detail-$_dialog-confirm'),
                variant: _dialog == 'delete'
                    ? MdyButtonVariant.danger
                    : MdyButtonVariant.primary,
                label: t(qu(_dialog == 'publish' ? 'publish' : 'deleteDraft')),
                busy: _busy,
                disabled: blocked,
                onPressed: send,
              ),
            ],
          ),
      ],
      children: [
        if (fatal)
          MdyAlert(t(qu('denied')), key: const Key('quiz-detail-denied'))
        else
          QuizGate(
            hasData: item != null,
            busy: q.isLoading,
            error: q.error == null ? null : QuizFailure.from(q.error!),
            prefix: 'quiz-detail',
            retry: () => ref.invalidate(quizDetailProvider(widget.id)),
            children: [
              if (item != null) ...[
                MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s20),
                  children: [
                    Text(
                      item.title,
                      key: const Key('quiz-detail-title'),
                      style: MdyType.size(
                        17,
                        MdyType.w600,
                      ).copyWith(color: context.mdy.ink),
                    ),
                    QuizChips(item: item, prefix: 'quiz-detail'),
                    QuizConfig(
                      item: item,
                      prefix: 'quiz-detail',
                      attempts: true,
                    ),
                    if (item.publishedAt != null)
                      MdyText(
                        t(qu('publishedAt'), {
                          'time': quizInstant(
                            item.publishedAt!.toIso8601String(),
                          ),
                        }),
                        key: const Key('quiz-detail-published-at'),
                      ),
                    if (item.description.isNotEmpty) ...[
                      Text(
                        item.description,
                        key: const Key('quiz-detail-description'),
                        maxLines: _expanded ? null : 4,
                        style: MdyType.size(
                          14,
                        ).copyWith(color: context.mdy.ink),
                      ),
                      if (item.description.length > 180 ||
                          item.description.split('\n').length > 4)
                        MdyButton(
                          variant: MdyButtonVariant.text,
                          label: t(qu(_expanded ? 'collapse' : 'expand')),
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                        ),
                    ],
                  ],
                ),
                if (closed)
                  MdyAlert(
                    t(qu('closed')),
                    key: const Key('quiz-detail-closed'),
                    warning: true,
                  ),
                if (item.status == 'DRAFT' &&
                    item.dueAt != null &&
                    DateTime.parse(item.dueAt!).isBefore(DateTime.now())) ...[
                  MdyAlert(
                    t(qu('duePast')),
                    warning: true,
                    key: const Key('quiz-detail-due-warning'),
                  ),
                  MdyButton(
                    key: const Key('quiz-detail-fix-due'),
                    variant: MdyButtonVariant.text,
                    label: t(qu('fixDue')),
                    disabled: blocked || closed,
                    onPressed: () => edit('info'),
                  ),
                ],
                if (item.status == 'ARCHIVED')
                  MdyText(
                    t(qu('archivedNote')),
                    key: const Key('quiz-detail-archived-note'),
                  ),
                if (item.status != 'DRAFT')
                  MdyText(
                    t(qu('noResults')),
                    key: const Key('quiz-detail-no-results'),
                  ),
                Row(
                  spacing: MdySpace.s8,
                  children: [
                    Expanded(
                      child: MdyText(
                        t(qu('questionsCount'), {
                          'count': item.questions?.length ?? 0,
                        }),
                        key: const Key('quiz-detail-count'),
                      ),
                    ),
                    if (item.questions?.isNotEmpty ?? false)
                      Semantics(
                        checked: _answers,
                        child: MdyButton(
                          key: const Key('quiz-detail-toggle-answers'),
                          variant: MdyButtonVariant.text,
                          label: t(
                            qu(_answers ? 'hideAnswers' : 'showAnswers'),
                          ),
                          onPressed: () => setState(() => _answers = !_answers),
                        ),
                      ),
                  ],
                ),
                if (item.questions?.isEmpty ?? true) ...[
                  MdyText(
                    t(qu('noQuestions')),
                    key: const Key('quiz-detail-no-questions'),
                  ),
                  if (item.status == 'DRAFT' && !closed)
                    MdyButton(
                      key: const Key('quiz-detail-compose'),
                      variant: MdyButtonVariant.secondary,
                      icon: MdyIcons.add,
                      label: t(qu('addQuestion')),
                      disabled: blocked,
                      onPressed: () => edit('questions'),
                    ),
                ],
              ],
              if (_error.isNotEmpty)
                MdyAlert(t(qu(_error)), key: const Key('quiz-detail-error')),
            ],
          ),
        if (_intent != null) ...[
          MdyAlert(
            t(qu('uncertain')),
            warning: true,
            key: const Key('quiz-detail-uncertain'),
          ),
          if (!offline)
            MdyButton(
              key: const Key('quiz-detail-check'),
              label: t(qu('check')),
              disabled: _busy,
              onPressed: _check,
            ),
          if (_retry && !offline)
            MdyButton(
              key: const Key('quiz-detail-resend'),
              label: t(qu('resend')),
              disabled: _busy,
              onPressed: () {
                setState(() => _retry = false);
                _execute(_intent!);
              },
            ),
        ],
      ],
    );
  }
}
