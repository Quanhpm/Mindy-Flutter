import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/states.dart';
import 'code_models.dart';
import 'code_providers.dart';
import 'code_widgets.dart';

/// Nội dung sheet kết quả Chạy thử (test mẫu, không tính lượt).
class RunResultView extends ConsumerWidget {
  const RunResultView({super.key, required this.result, this.scroll});
  final RunResult result;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final passed = result.tests.where((x) => x.status == 'PASSED').length;
    return ListView(
      key: const Key('code-run-result'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            t('code.run.title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forest),
          ),
        ),
        const SizedBox(height: 8),
        Text(t('code.run.hint'), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 12),
        if (!result.compiled) ...[
          CodePill(t('code.run.compile.${result.compileStatus}'), color: AppColors.statusRed),
          const SizedBox(height: 8),
          CodeBlock(result.compileOutput.isEmpty ? t('code.run.noOutput') : result.compileOutput, error: true),
        ] else ...[
          CodePill(
            t('code.run.passed', {'passed': passed, 'total': result.tests.length}),
            color: passed == result.tests.length ? AppColors.statusGreen : AppColors.statusRed,
          ),
          for (final test in result.tests) _RunTestCard(test: test, t: t),
        ],
      ],
    );
  }
}

class _RunTestCard extends StatelessWidget {
  const _RunTestCard({required this.test, required this.t});
  final RunTest test;
  final Translator t;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                test.custom ? t('code.run.custom') : t('code.run.sample', {'number': test.position ?? 0}),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.black),
              ),
            ),
            CodePill(t('code.test.${test.status}'), color: testColor(test.status)),
          ],
        ),
        const SizedBox(height: 8),
        _Labeled(label: t('code.run.input'), value: test.display),
        if (!test.custom) _Labeled(label: t('code.run.expected'), value: formatCodeValue(test.expected)),
        _Labeled(label: t('code.run.actual'), value: formatCodeValue(test.actual)),
        if (test.console.isNotEmpty) _Labeled(label: t('code.run.console'), value: test.console),
        if (test.stderr.isNotEmpty) _Labeled(label: t('code.run.stderr'), value: test.stderr, error: true),
        Text(
          t('code.measure', {'time': test.timeMs, 'memory': test.memoryKb}),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.value, this.error = false});
  final String label, value;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 4),
        CodeBlock(value, error: error),
      ],
    ),
  );
}

/// Nội dung sheet kết quả một bài nộp; tự hỏi lại tới khi chấm xong (tối đa 60 giây).
class SubmissionResultView extends ConsumerWidget {
  const SubmissionResultView({super.key, required this.submissionId, this.scroll});
  final String submissionId;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final watch = ref.watch(codeSubmissionWatchProvider(submissionId));
    return ListView(
      key: const Key('code-submission-result'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        AsyncView<SubmissionWatch>(
          value: watch,
          onRetry: () => ref.invalidate(codeSubmissionWatchProvider(submissionId)),
          data: (w) => _SubmissionBody(
            watch: w,
            t: t,
            onRefresh: () => ref.read(codeSubmissionWatchProvider(submissionId).notifier).restart(),
          ),
        ),
      ],
    );
  }
}

class _SubmissionBody extends StatelessWidget {
  const _SubmissionBody({required this.watch, required this.t, required this.onRefresh});
  final SubmissionWatch watch;
  final Translator t;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = watch.submission;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            t('code.submission.title', {'number': s.attemptNumber}),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forest),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              CodePill(submissionLabel(t, s), color: verdictColor(s.verdict, s.status)),
              const SizedBox(width: 8),
              if (watch.polling)
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CodeFacts([
          CodeFact(label: t('code.submission.score'), value: scoreText(s.score, s.maxScore)),
          CodeFact(
            label: t('code.submission.tests'),
            value: s.totalCount == null ? '—' : '${s.passedCount ?? 0}/${s.totalCount}',
          ),
          CodeFact(label: t('code.submission.language'), value: t('code.language.${s.languageKey.name}')),
          CodeFact(
            label: t('code.submission.attempt'),
            value: s.countsAsAttempt ? t('code.submission.counted') : t('code.submission.notCounted'),
          ),
        ]),
        if (s.pending) ...[
          const SizedBox(height: 12),
          Text(t('code.submission.pending'), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
        if (watch.timedOut || watch.error != null) ...[
          if (watch.error != null) CodeErrorText(watch.error!, t: t),
          if (watch.timedOut)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t('code.submission.slow'), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
          MindyButton(
            key: const Key('code-submission-refresh'),
            label: t('common.retry'),
            variant: ButtonVariant.outline,
            onPressed: onRefresh,
          ),
        ],
        if (s.status == SubmissionStatus.VOIDED && s.voidedReason != null) ...[
          const SizedBox(height: 12),
          Text(t('code.submission.voided', {'reason': s.voidedReason}), style: const TextStyle(color: AppColors.muted)),
        ],
        if (s.status == SubmissionStatus.FAILED)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(t('code.submission.failed'), style: const TextStyle(color: AppColors.muted)),
          ),
        if (s.compileOutput != null && s.compileOutput!.isNotEmpty) ...[
          CodeSectionTitle(t('code.submission.compile')),
          CodeBlock(s.compileOutput!, error: true),
        ],
        if (s.tests.isNotEmpty) ...[
          CodeSectionTitle(t('code.submission.testList')),
          for (final test in s.tests) _SubmissionTestRow(test: test, t: t),
        ],
      ],
    );
  }
}

class _SubmissionTestRow extends StatelessWidget {
  const _SubmissionTestRow({required this.test, required this.t});
  final SubmissionTest test;
  final Translator t;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t(
                  test.visibility == TestVisibility.HIDDEN ? 'code.submission.hiddenTest' : 'code.submission.sampleTest',
                  {'number': test.position},
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.black),
              ),
            ),
            CodePill(t('code.test.${test.status}'), color: testColor(test.status)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t('code.measure', {'time': test.timeMs, 'memory': test.memoryKb}),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        // Test ẩn: chỉ trạng thái + thời gian (D10). Test mẫu: có input/expected/actual.
        if (test.hasDetail) ...[
          const SizedBox(height: 8),
          _Labeled(label: t('code.run.input'), value: test.input ?? ''),
          _Labeled(label: t('code.run.expected'), value: formatCodeValue(test.expected)),
          _Labeled(label: t('code.run.actual'), value: formatCodeValue(test.actual)),
        ],
      ],
    ),
  );
}
