import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_query.dart';
import '../teaching/teaching_widgets.dart';
import 'quiz_query.dart';
import 'quiz_widgets.dart';

abstract final class StaffQuizRoutes {
  static const classPath = '/mentor/quizzes/:classId';
  static const editorPath = '/mentor/quiz/:classId/editor/:sessionId';
  static const detailPath = '/mentor/quiz/:classId/:assignmentId';
  static String list(
    String classId, {
    String? title,
    String? sessionId,
    String? sessionTitle,
  }) => Uri(
    path: '/mentor/quizzes/$classId',
    queryParameters: {
      'title': ?title,
      'sessionId': ?sessionId,
      'sessionTitle': ?sessionTitle,
    },
  ).toString();
  static String editor(
    String classId,
    String sessionId, {
    String? id,
    String? tab,
    String? title,
  }) => Uri(
    path: '/mentor/quiz/$classId/editor/$sessionId',
    queryParameters: {'id': ?id, 'tab': ?tab, 'title': ?title},
  ).toString();
  static String detail(String classId, String id) =>
      '/mentor/quiz/$classId/$id';
}

class StaffQuizListScreen extends ConsumerStatefulWidget {
  const StaffQuizListScreen({
    super.key,
    this.classId,
    this.classTitle,
    this.sessionId,
    this.sessionTitle,
  });
  final String? classId, classTitle, sessionId, sessionTitle;
  @override
  ConsumerState<StaffQuizListScreen> createState() => _QuizListState();
}

class _QuizListState extends ConsumerState<StaffQuizListScreen> {
  String _classStatus = 'IN_PROGRESS', _status = '', _filterSession = '';
  String? _picker;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        id = widget.classId,
        offline = ref.watch(staffOfflineProvider);
    if (id == null) {
      final r = TeachingRequest(
            kind: TeachingKind.classes,
            role: TeachingRole.MENTOR,
            status: _classStatus,
          ),
          q = ref.watch(teachingQueryProvider(r)),
          controller = ref.read(teachingQueryProvider(r).notifier);
      return QuizPage(
        prefix: 'quiz-classes',
        title: t(qu('title')),
        subtitle: t(qu('chooseClass')),
        onBack: () => staffBack(context),
        children: [
          TeachingFilters(
            prefix: 'quiz-classes',
            values: const ['IN_PROGRESS', 'OPEN', 'COMPLETED'],
            value: _classStatus,
            onChange: (v) => setState(() => _classStatus = v),
          ),
          QueryBlock(
            query: q,
            prefix: 'quiz-classes',
            onRetry: controller.refresh,
            builder: (_) => Column(
              spacing: MdySpace.s16,
              children: [
                for (final c in q.data?.classes ?? const <TeachingClass>[])
                  KeyedSubtree(
                    key: Key('quiz-class-${c.id}'),
                    child: MentorClassCard(
                      item: c,
                      onPress: () => context.push(
                        StaffQuizRoutes.list(c.id, title: c.name),
                      ),
                    ),
                  ),
                if (q.data?.total == 0)
                  MdyText(
                    t(qu('noClasses')),
                    key: const Key('quiz-classes-empty'),
                  ),
                TeachingFooter(
                  query: q,
                  prefix: 'quiz-classes',
                  count: q.data?.classes.length ?? 0,
                  onMore: controller.more,
                ),
              ],
            ),
          ),
        ],
      );
    }
    final cr = TeachingRequest(
          kind: TeachingKind.klass,
          role: TeachingRole.MENTOR,
          classId: id,
        ),
        cls = ref.watch(teachingQueryProvider(cr));
    final sr = TeachingRequest(
          kind: TeachingKind.sessions,
          role: TeachingRole.MENTOR,
          classId: id,
          pageSize: 100,
        ),
        sessions = widget.sessionId == null
            ? ref.watch(teachingQueryProvider(sr))
            : null;
    final cx = widget.sessionId == null
        ? null
        : ref.watch(
            teachingQueryProvider(
              TeachingRequest(
                kind: TeachingKind.context,
                role: TeachingRole.MENTOR,
                sessionId: widget.sessionId,
              ),
            ),
          );
    final writable =
        cls.data?.classInfo != null &&
        ![
          'DRAFT',
          'COMPLETED',
          'CANCELLED',
        ].contains(cls.data!.classInfo!.status.name) &&
        cx?.data?.session?.status != SessionStatus.CANCELLED;
    final request = (
          classId: id,
          sessionId: widget.sessionId,
          filterSession: _filterSession.isEmpty ? null : _filterSession,
          status: _status,
        ),
        q = ref.watch(quizListProvider(request)),
        controller = ref.read(quizListProvider(request).notifier);
    final denied = cls.fatal || cx?.fatal == true;
    void create() {
      final sessionId =
          widget.sessionId ?? (_filterSession.isEmpty ? null : _filterSession);
      if (sessionId != null) {
        context.push(
          StaffQuizRoutes.editor(id, sessionId, title: widget.sessionTitle),
        );
      } else {
        setState(() => _picker = 'create');
      }
    }

    return QuizPage(
      prefix: 'quiz-list',
      title: t(qu(widget.sessionId == null ? 'title' : 'sessionTitle')),
      subtitle: widget.sessionTitle ?? widget.classTitle,
      onBack: () => staffBack(context),
      refresh: controller.refresh,
      rows: denied
          ? const []
          : [
              for (final item in q.items)
                MdyPressed(
                  key: Key('quiz-list-row-${item.id}'),
                  onTap: () =>
                      context.push(StaffQuizRoutes.detail(id, item.id)),
                  builder: (context, pressed) => MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    gap: MdySpace.s12,
                    children: [
                      Text(
                        item.title,
                        style: MdyType.size(
                          15,
                          MdyType.w600,
                        ).copyWith(color: context.mdy.ink),
                      ),
                      QuizChips(item: item, prefix: 'quiz-list-row-${item.id}'),
                      if (widget.sessionId == null)
                            if (sessions?.data?.sessions
                                  .where((s) => s.id == item.sessionId)
                                  .firstOrNull
                          case final session?)
                        MdyText(
                          session.title,
                          key: Key('quiz-list-row-${item.id}-session'),
                        ),
                      QuizConfig(
                        item: item,
                        prefix: 'quiz-list-row-${item.id}',
                      ),
                    ],
                  ),
                ),
            ],
      footer: q.items.length < q.total
          ? [
              MdyButton(
                key: const Key('quiz-list-more'),
                variant: MdyButtonVariant.text,
                label: t(qu('more')),
                busy: q.busy,
                disabled: offline || q.busy,
                onPressed: controller.more,
              ),
            ]
          : null,
      overlays: [
        if (_picker != null)
          MdyInlineSheet(
            key: const Key('quiz-list-session-sheet'),
            title: t(qu(_picker == 'create' ? 'pickSession' : 'allSessions')),
            onClose: () => setState(() => _picker = null),
            children: [
              if (_picker == 'filter')
                MdyButton(
                  label: t(qu('allSessions')),
                  onPressed: () => setState(() {
                    _filterSession = '';
                    _picker = null;
                  }),
                ),
              for (final s
                  in sessions?.data?.sessions ?? const <TeachingSession>[])
                MdyButton(
                  key: Key('quiz-list-session-${s.id}'),
                  variant: _filterSession == s.id
                      ? MdyButtonVariant.primary
                      : MdyButtonVariant.secondary,
                  label:
                      '${s.title} · ${quizInstant(s.startsAt.toIso8601String())}${s.status == SessionStatus.CANCELLED ? ' · ${t(qu('sessionCancelled'))}' : ''}',
                  disabled:
                      _picker == 'create' &&
                      (offline || s.status == SessionStatus.CANCELLED),
                  onPressed: () {
                    if (_picker == 'create') {
                      context.push(
                        StaffQuizRoutes.editor(id, s.id, title: s.title),
                      );
                    }
                    setState(() {
                      if (_picker == 'filter') _filterSession = s.id;
                      _picker = null;
                    });
                  },
                ),
              if (sessions != null)
                TeachingFooter(
                  query: sessions,
                  prefix: 'quiz-list-session',
                  count: sessions.data?.sessions.length ?? 0,
                  onMore: ref.read(teachingQueryProvider(sr).notifier).more,
                ),
            ],
          ),
      ],
      children: [
        if (denied)
          MdyAlert(t(qu('denied')), key: const Key('quiz-list-denied'))
        else
          QuizGate(
            hasData: q.page > 0,
            busy: q.busy,
            error: q.error,
            prefix: 'quiz-list',
            retry: controller.refresh,
            children: [
              if (writable)
                MdyButton(
                  key: const Key('quiz-list-create'),
                  icon: MdyIcons.add,
                  label: t(qu('create')),
                  disabled: offline,
                  onPressed: create,
                )
              else if (cls.data?.classInfo != null)
                MdyAlert(
                  t(qu('closed')),
                  key: const Key('quiz-list-readonly'),
                  warning: true,
                ),
              if (cls.data?.classInfo?.scope == ClassScope.SESSION)
                MdyText(
                  t(qu('substitute')),
                  key: const Key('quiz-list-substitute'),
                ),
              TeachingFilters(
                prefix: 'quiz-list',
                values: const ['', 'DRAFT', 'PUBLISHED', 'ARCHIVED'],
                value: _status,
                onChange: (v) => setState(() => _status = v),
                labelFor: (v, _) => t(qu(v.isEmpty ? 'all' : v)),
              ),
              if (widget.sessionId == null)
                Row(
                  spacing: MdySpace.s8,
                  children: [
                    Expanded(
                      child: MdyButton(
                        key: const Key('quiz-list-session'),
                        variant: MdyButtonVariant.secondary,
                        label:
                            sessions?.data?.sessions
                                .where((s) => s.id == _filterSession)
                                .firstOrNull
                                ?.title ??
                            t(qu('allSessions')),
                        onPressed: () => setState(() => _picker = 'filter'),
                      ),
                    ),
                    if (_filterSession.isNotEmpty)
                      MdyButton(
                        key: const Key('quiz-list-session-clear'),
                        variant: MdyButtonVariant.text,
                        label: t(qu('showAll')),
                        onPressed: () => setState(() => _filterSession = ''),
                      ),
                  ],
                ),
              MdyText(
                t(qu('count'), {'count': q.total}),
                key: const Key('quiz-list-count'),
              ),
              if (q.total == 0) ...[
                MdyText(
                  t(
                    qu(
                      _status.isNotEmpty || _filterSession.isNotEmpty
                          ? 'emptyFilter'
                          : 'empty',
                    ),
                  ),
                  key: Key(
                    _status.isNotEmpty || _filterSession.isNotEmpty
                        ? 'quiz-list-empty-filter'
                        : 'quiz-list-empty',
                  ),
                ),
                if (_status.isNotEmpty || _filterSession.isNotEmpty)
                  MdyButton(
                    key: const Key('quiz-list-show-all'),
                    variant: MdyButtonVariant.text,
                    label: t(qu('showAll')),
                    onPressed: () => setState(() {
                      _status = '';
                      _filterSession = '';
                    }),
                  ),
              ],
              if (q.footerError)
                MdyAlert(
                  t(qu('error')),
                  warning: true,
                  key: const Key('quiz-list-more-error'),
                ),
              if (offline) MdyText(t(qu('needOnline'))),
            ],
          ),
      ],
    );
  }
}
