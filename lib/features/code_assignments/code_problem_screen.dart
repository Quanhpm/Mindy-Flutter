import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/ui/states.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/format.dart';
import '../schedule/schedule_providers.dart';
import 'code_models.dart';
import 'code_providers.dart';
import 'code_result_sheet.dart';
import 'code_widgets.dart';

/// Đề bài code (Học viên): đề, chữ ký hàm, ví dụ, hạn nộp, lượt còn, điểm cao nhất, lịch sử nộp.
class CodeProblemScreen extends ConsumerWidget {
  const CodeProblemScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final value = ref.watch(codeAssignmentProvider(assignmentId));
    final timeZone = ref.watch(learningTimeZoneProvider).value ?? codeFallbackTimeZone;
    ref.watch(appNowProvider); // đếm ngược theo đồng hồ đã đồng bộ khi app quay lại foreground
    return LearningLayout(
      prefix: 'code-problem',
      title: value.value?.assignment.title ?? t('code.problem.title'),
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
      onRefresh: () async {
        ref.invalidate(codeSubmissionsProvider(assignmentId));
        await ref.refresh(codeAssignmentProvider(assignmentId).future).then((_) {});
      },
      footer: value.value == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: MindyButton(
                key: const Key('code-problem-open-editor'),
                label: value.value!.assignment.canSubmit ? t('code.problem.solve') : t('code.problem.viewCode'),
                onPressed: () => context.push(Routes.codeEditor(assignmentId)),
              ),
            ),
      children: AsyncView<({StudentCodeAssignment assignment, DateTime receivedAt})>(
        value: value,
        onRetry: () => ref.invalidate(codeAssignmentProvider(assignmentId)),
        data: (data) => _ProblemBody(
          assignment: data.assignment,
          receivedAt: data.receivedAt,
          timeZone: timeZone,
          t: t,
        ),
      ),
    );
  }
}

class _ProblemBody extends ConsumerWidget {
  const _ProblemBody({required this.assignment, required this.receivedAt, required this.timeZone, required this.t});
  final StudentCodeAssignment assignment;
  final DateTime receivedAt;
  final String timeZone;
  final Translator t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = assignment;
    final left = timeLeft(a, receivedAt, DateTime.now());
    final closed = a.deadlinePassed || left == Duration.zero || a.status == AssignmentStatus.ARCHIVED;
    final history = ref.watch(codeSubmissionsProvider(a.assignmentId));
    final p = a.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a.description.isNotEmpty) ...[
          Text(a.description, style: const TextStyle(fontSize: 14, height: 22 / 14, color: AppColors.muted)),
          const SizedBox(height: 12),
        ],
        CodeFacts([
          CodeFact(
            label: t('code.problem.due'),
            value: closed
                ? t('code.problem.closed')
                : '${Dates.instant(a.dueAt, timeZone)}\n${_left(t, left)}',
            highlight: !closed && left < const Duration(hours: 24),
          ),
          CodeFact(
            label: t('code.problem.attempts'),
            value: t('code.problem.attemptsValue', {'left': a.attemptsRemaining, 'max': a.maxAttempts}),
          ),
          CodeFact(label: t('code.problem.best'), value: scoreText(a.bestScore, a.maxScore)),
          CodeFact(
            label: t('code.problem.limits'),
            value: t('code.problem.limitsValue', {'time': p.cpuTimeLimitMs, 'memory': p.memoryLimitMb}),
          ),
        ]),
        if (a.inFlightSubmissionId != null) ...[
          const SizedBox(height: 12),
          MindyButton(
            key: const Key('code-problem-in-flight'),
            label: t('code.problem.inFlight'),
            variant: ButtonVariant.outline,
            onPressed: () => _openSubmission(context, a.inFlightSubmissionId!),
          ),
        ],
        CodeSectionTitle(t('code.problem.statement')),
        SelectableText(p.statementMd, style: const TextStyle(fontSize: 15, height: 24 / 15, color: AppColors.black)),
        if (p.constraintsMd.isNotEmpty) ...[
          CodeSectionTitle(t('code.problem.constraints')),
          SelectableText(p.constraintsMd, style: const TextStyle(fontSize: 14, height: 22 / 14, color: AppColors.black)),
        ],
        CodeSectionTitle(t('code.problem.signature')),
        CodeBlock(p.signature.display),
        const SizedBox(height: 6),
        Text(
          '${t('code.problem.languages')}: ${a.languages.map((l) => '${l.displayName} (${l.runtimeVersion})').join(', ')}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        Text(
          '${t('code.problem.scoring.${p.scoringMode.name}')} · ${t('code.problem.compare.${p.compareMode.name}')}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        if (a.samples.isNotEmpty) CodeSectionTitle(t('code.problem.samples')),
        for (final sample in a.samples) _SampleCard(sample: sample, t: t),
        if (a.hiddenTestCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t('code.problem.hidden', {'count': a.hiddenTestCount}),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        CodeSectionTitle(t('code.history.title')),
        AsyncView<List<Submission>>(
          value: history,
          loading: const Skeleton(height: 72),
          onRetry: () => ref.invalidate(codeSubmissionsProvider(a.assignmentId)),
          data: (items) => items.isEmpty
              ? Text(t('code.history.empty'), style: const TextStyle(fontSize: 14, color: AppColors.muted))
              : Column(
                  children: [
                    for (final s in items) _HistoryRow(submission: s, timeZone: timeZone, t: t),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static String _left(Translator t, Duration left) => left.inHours >= 24
      ? t('code.problem.leftDays', {'days': left.inDays, 'hours': left.inHours % 24})
      : t('code.problem.leftHours', {'hours': left.inHours, 'minutes': left.inMinutes % 60});
}

void _openSubmission(BuildContext context, String id) =>
    showAppSheet<void>(context, (_) => SubmissionResultView(submissionId: id), initialSize: 0.85);

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.sample, required this.t});
  final CodeSample sample;
  final Translator t;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('code.run.sample', {'number': sample.position}),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        const SizedBox(height: 6),
        Text(t('code.run.input'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        CodeBlock(sample.display),
        const SizedBox(height: 6),
        Text(
          t('code.run.expected'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
        ),
        CodeBlock(formatCodeValue(sample.expected)),
        if (sample.explanationMd != null && sample.explanationMd!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(sample.explanationMd!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.submission, required this.timeZone, required this.t});
  final Submission submission;
  final String timeZone;
  final Translator t;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('code-history-${s.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openSubmission(context, s.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('code.submission.title', {'number': s.attemptNumber}),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.black),
                      ),
                      Text(
                        '${t('code.language.${s.languageKey.name}')} · ${Dates.instant(s.submittedAt, timeZone)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      if (!s.countsAsAttempt)
                        Text(
                          t('code.submission.notCounted'),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CodePill(submissionLabel(t, s), color: verdictColor(s.verdict, s.status)),
                    const SizedBox(height: 4),
                    Text(
                      scoreText(s.score, s.maxScore),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.forest),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
