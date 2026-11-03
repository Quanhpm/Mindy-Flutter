import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_widgets.dart';
import 'quiz_models.dart';
import 'quiz_service.dart';

String qu(String key) => 'mdy.quiz.$key';
String quizProblem(QuizFailure e) => switch (e.code) {
  'ASSIGNMENT_VERSION_CONFLICT' => 'conflict',
  'ASSIGNMENT_FROZEN' => 'frozen',
  'ASSIGNMENT_STATE_CONFLICT' => 'stateConflict',
  'CLASS_NOT_OPEN' => 'closed',
  _ => e.kind,
};

class QuizGate extends ConsumerWidget {
  const QuizGate({
    super.key,
    required this.hasData,
    required this.busy,
    required this.prefix,
    required this.children,
    this.error,
    this.retry,
  });
  final bool hasData, busy;
  final String prefix;
  final List<Widget> children;
  final QuizFailure? error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), e = error;
    final fatal = e != null && ['denied', 'notFound'].contains(e.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s16,
      children: [
        if (hasData && !fatal)
          ...children
        else if (busy)
          KeyedSubtree(
            key: Key('$prefix-skeleton'),
            child: const SkeletonList(count: 2),
          ),
        if (e != null) ...[
          MdyAlert(
            '${t(qu(hasData && !fatal
                ? 'refreshError'
                : e.kind == 'offline'
                ? 'offlineEmpty'
                : quizProblem(e)))}${e.requestId == null ? '' : ' · ${e.requestId}'}',
            key: Key('$prefix-${e.kind == 'notFound' ? 'not-found' : e.kind}'),
            warning: hasData,
          ),
          if (!['denied', 'notFound', 'offline'].contains(e.kind))
            MdyButton(
              key: Key('$prefix-retry'),
              label: t(qu('retry')),
              onPressed: retry,
            ),
        ],
      ],
    );
  }
}

class QuizConfig extends ConsumerWidget {
  const QuizConfig({
    super.key,
    required this.item,
    required this.prefix,
    this.attempts = false,
  });
  final StaffQuiz item;
  final String prefix;
  final bool attempts;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    String score = item.score
        .replaceFirstMapped(RegExp(r'(\.\d*?)0+$'), (m) => m[1]!)
        .replaceFirst(RegExp(r'\.$'), '');
    if (t.locale.languageCode == 'vi') score = score.replaceAll('.', ',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        MdyText(t(qu('points'), {'score': score}), key: Key('$prefix-score')),
        MdyText(
          item.timeLimit == null
              ? t(qu('noLimit'))
              : t(qu('minutes'), {'count': item.timeLimit!}),
          key: Key('$prefix-limit'),
        ),
        MdyText(
          item.dueAt == null
              ? t(qu('noDue'))
              : t(qu('due'), {'time': quizInstant(item.dueAt!)}),
          key: Key('$prefix-due'),
        ),
        if (attempts) MdyText(t(qu('oneAttempt'))),
      ],
    );
  }
}

String quizInstant(String value) {
  final date = DateTime.parse(value).toUtc().add(const Duration(hours: 7));
  String two(int n) => '$n'.padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class QuizChips extends ConsumerWidget {
  const QuizChips({super.key, required this.item, required this.prefix});
  final StaffQuiz item;
  final String prefix;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Wrap(
      spacing: MdySpace.s8,
      children: [
        MdyChip(
          t(qu(item.status)),
          key: Key('$prefix-status'),
          variant: item.status == 'PUBLISHED'
              ? MdyChipVariant.success
              : MdyChipVariant.neutral,
        ),
        MdyChip(
          t(qu(item.purpose)),
          key: Key('$prefix-purpose'),
          variant: MdyChipVariant.neutral,
        ),
      ],
    );
  }
}

class QuizQuestionRead extends ConsumerWidget {
  const QuizQuestionRead({
    super.key,
    required this.question,
    required this.index,
    required this.answers,
  });
  final QuizQuestion question;
  final int index;
  final bool answers;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), c = context.mdy;
    return MdyCard(
      key: Key('quiz-detail-question-${question.id ?? question.key}'),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MdySpace.s20),
      gap: MdySpace.s14,
      children: [
        Text(
          '${index + 1}. ${question.prompt}',
          style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink),
        ),
        for (final label in quizLabels)
          Container(
            padding: const EdgeInsets.all(MdySpace.s8),
            decoration: BoxDecoration(
              color: answers && question.correct == label ? c.successBg : null,
              borderRadius: BorderRadius.circular(MdyRadius.r12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MdySpace.s10,
              children: [
                MdyChip(label, variant: MdyChipVariant.neutral),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s4,
                    children: [
                      MdyText(question.options[label] ?? ''),
                      if (answers && question.correct == label)
                        Text(
                          t(qu('correct')),
                          key: Key(
                            'quiz-detail-correct-${question.id ?? question.key}',
                          ),
                          style: MdyType.size(
                            12,
                            MdyType.w600,
                          ).copyWith(color: c.success),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({
    super.key,
    required this.prefix,
    required this.title,
    required this.onBack,
    required this.children,
    this.rows = const [],
    this.footer,
    this.overlays = const [],
    this.subtitle,
    this.refresh,
    this.dirty = false,
    this.busy = false,
    this.allowLeave = false,
    this.beforeBack,
  });
  final String prefix, title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> children, rows, overlays;
  final List<Widget>? footer;
  final Future<void> Function()? refresh;
  final bool dirty, busy, allowLeave;
  final bool Function()? beforeBack;
  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  bool _leave = false, _leaving = false;
  bool get guarded =>
      !_leaving && !widget.allowLeave && (widget.dirty || widget.busy);
  void back() {
    if (widget.busy || widget.beforeBack?.call() == true) return;
    if (guarded) {
      setState(() => _leave = true);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), c = context.mdy;
    Widget list = ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MdySpace.s16,
        vertical: MdySpace.s28,
      ),
      itemCount: widget.rows.length + 1,
      itemBuilder: (context, index) => index == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s16,
              children: widget.children,
            )
          : Padding(
              padding: const EdgeInsets.only(top: MdySpace.s12),
              child: widget.rows[index - 1],
            ),
    );
    if (widget.refresh != null) {
      list = RefreshIndicator(
        onRefresh: widget.refresh!,
        color: c.primary,
        child: list,
      );
    }
    return PopScope(
      canPop: !guarded,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) back();
      },
      child: Material(
        color: c.bg,
        child: Stack(
          children: [
            Column(
              children: [
                MdyBrandHeader(
                  subpage: true,
                  child: Row(
                    spacing: MdySpace.s12,
                    children: [
                      MdyButton(
                        key: Key('${widget.prefix}-back'),
                        variant: MdyButtonVariant.text,
                        size: MdyButtonSize.sm,
                        semanticLabel: t(qu('back')),
                        onPressed: back,
                        child: MdyIcon(MdyIcons.arrowBack, color: c.onBrand),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: MdyType.size(
                                18,
                                MdyType.w600,
                              ).copyWith(color: c.onBrand),
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: MdyType.size(
                                  13,
                                ).copyWith(color: c.onBrandMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MdyRadius.r28),
                    ),
                    child: list,
                  ),
                ),
                if (widget.footer != null)
                  Container(
                    key: Key('${widget.prefix}-save-bar'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.paddingOf(context).bottom > 12
                          ? MediaQuery.paddingOf(context).bottom
                          : 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(top: BorderSide(color: c.divider)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s10,
                      children: widget.footer!,
                    ),
                  ),
              ],
            ),
            ...widget.overlays,
            if (_leave)
              MdyInlineDialog(
                key: const Key('quiz-leave-dialog'),
                title: t(qu('leaveTitle')),
                icon: MdyIcons.warning,
                onClose: () => setState(() => _leave = false),
                children: [
                  MdyText(t(qu('leaveBody'))),
                  MdyButton(
                    key: const Key('quiz-leave-stay'),
                    label: t(qu('keepEditing')),
                    onPressed: () => setState(() => _leave = false),
                  ),
                  MdyButton(
                    key: const Key('quiz-leave-discard'),
                    variant: MdyButtonVariant.danger,
                    label: t(qu('discard')),
                    onPressed: () {
                      setState(() {
                        _leave = false;
                        _leaving = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) widget.onBack();
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
