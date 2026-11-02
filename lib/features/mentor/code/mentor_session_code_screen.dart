import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_stats.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../../code_assignments/code_models.dart';
import '../../code_assignments/code_providers.dart';
import '../../code_assignments/code_widgets.dart';

/// Mentor: tổng hợp bài tập lập trình của một buổi (chỉ đọc). Soạn đề, chấm lại, huỷ bài làm trên web.
class MentorSessionCodeScreen extends ConsumerWidget {
  const MentorSessionCodeScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final list = ref.watch(sessionCodeAssignmentsProvider(sessionId));
    return StaffPage(
      title: t('mentor.code.title'),
      subtitle: t('mentor.code.subtitle'),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(sessionCodeAssignmentsProvider(sessionId).future),
        child: ListView(
          key: const Key('mentor-code-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
          children: [
            ...list.when<List<Widget>>(
              skipLoadingOnRefresh: true,
              loading: () => const <Widget>[Skeleton(height: 160)],
              error: (error, _) => [
                StaffDataState(
                  title: t('mentor.code.failed'),
                  description: t(codeErrorKey(error)),
                  error: error,
                  onRetry: () =>
                      ref.invalidate(sessionCodeAssignmentsProvider(sessionId)),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      StaffDataState(
                        title: t('mentor.code.emptyTitle'),
                        description: t('mentor.code.empty'),
                      ),
                    ]
                  : [
                      for (final item in items) ...[
                        _AssignmentSummary(item: item),
                        const SizedBox(height: 16),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentSummary extends ConsumerWidget {
  const _AssignmentSummary({required this.item});
  final AssignmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final Widget content;
    if (item.status == AssignmentStatus.DRAFT) {
      content = Text(t('mentor.code.draftHint'), style: StaffText.caption);
    } else {
      final summary = ref.watch(codeSummaryProvider(item.id));
      content = summary.when<Widget>(
        skipLoadingOnRefresh: true,
        loading: () => const Skeleton(height: 80),
        error: (error, _) => StaffDataState(
          title: t('mentor.code.failed'),
          description: t(codeErrorKey(error)),
          error: error,
          onRetry: () => ref.invalidate(codeSummaryProvider(item.id)),
        ),
        data: (s) => _SummaryBody(summary: s, t: t),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: StaffText.bodyStrong)),
              const SizedBox(width: 8),
              StatusChip(
                t('mentor.code.status.${item.status.name}'),
                tone: switch (item.status) {
                  AssignmentStatus.DRAFT => StatusTone.amber,
                  AssignmentStatus.PUBLISHED => StatusTone.green,
                  AssignmentStatus.ARCHIVED => StatusTone.teal,
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.dueAt == null
                ? t('mentor.code.noDue')
                : t('mentor.code.due', {
                    'time': Dates.instant(item.dueAt!, codeFallbackTimeZone),
                  }),
            style: StaffText.caption,
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary, required this.t});
  final CodeSummary summary;
  final Translator t;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffStats(
          items: [
            (
              label: t('mentor.code.submitted'),
              value: '${s.submitted}/${s.students}',
              tone: StatusTone.teal,
            ),
            (
              label: t('mentor.code.accepted'),
              value: '${s.accepted}',
              tone: StatusTone.green,
            ),
            (
              label: t('mentor.code.average'),
              value: s.averageBestScore ?? '—',
              tone: StatusTone.blue,
            ),
          ],
        ),
        if (s.failed > 0) ...[
          const SizedBox(height: 8),
          Text(
            t('mentor.code.failedJudge', {'count': s.failed}),
            style: StaffText.caption,
          ),
        ],
        const SizedBox(height: 12),
        for (final row in s.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                InitialsAvatar(name: row.displayName, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.displayName, style: StaffText.body),
                      Text(
                        row.submitted
                            ? t('mentor.code.rowMeta', {
                                'attempts': row.attemptsUsed,
                                'max': s.maxAttempts,
                                'status': row.latestVerdict != null
                                    ? t('code.verdict.${row.latestVerdict}')
                                    : t(
                                        'code.status.${row.latestStatus!.name}',
                                      ),
                              })
                            : t('mentor.code.notSubmitted'),
                        style: StaffText.small,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    scoreText(row.bestScore, s.maxScore),
                    style: StaffText.label,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        if (s.total > s.items.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t('mentor.code.more', {'count': s.total - s.items.length}),
              style: StaffText.caption,
            ),
          ),
        const SizedBox(height: 8),
        Text(t('mentor.code.webHint'), style: StaffText.small),
      ],
    );
  }
}
