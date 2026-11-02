import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/ui/states.dart';
import '../../core/utils/format.dart';
import '../my_classes/my_classes_models.dart';
import '../my_classes/my_classes_providers.dart';
import '../schedule/schedule_providers.dart';
import 'code_models.dart';
import 'code_providers.dart';
import 'code_widgets.dart';

/// Danh sách bài tập lập trình của một lớp (Học viên). Mở từ Chi tiết lớp.
class CodeAssignmentsScreen extends ConsumerWidget {
  const CodeAssignmentsScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final list = ref.watch(classCodeAssignmentsProvider(classId));
    final timeZone = ref.watch(learningTimeZoneProvider).value ?? codeFallbackTimeZone;
    // Chi tiết lớp vẫn nằm dưới trong stack nên thường đã có dữ liệu; chỉ dùng để hiện "Buổi n".
    final sessions = {
      for (final s in ref.watch(classDetailProvider(classId)).value?.detail.sessions ?? const <ClassSession>[]) s.id: s.sessionNumber,
    };
    return LearningLayout(
      prefix: 'code-assignments',
      title: t('code.list.title'),
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.classDetail(classId)),
      onRefresh: () async => ref.refresh(classCodeAssignmentsProvider(classId).future),
      children: AsyncView<List<AssignmentItem>>(
        value: list,
        onRetry: () => ref.invalidate(classCodeAssignmentsProvider(classId)),
        data: (items) => items.isEmpty
            ? ScreenState(title: t('code.list.emptyTitle'), description: t('code.list.empty'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    _AssignmentCard(
                      item: item,
                      sessionNumber: sessions[item.sessionId],
                      timeZone: timeZone,
                      t: t,
                      onTap: () => context.push(Routes.codeAssignment(item.id)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.item,
    required this.sessionNumber,
    required this.timeZone,
    required this.t,
    required this.onTap,
  });

  final AssignmentItem item;
  final int? sessionNumber;
  final String timeZone;
  final Translator t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = item.status == AssignmentStatus.ARCHIVED;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('code-assignment-${item.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (sessionNumber != null)
                      CodePill(t('code.list.session', {'number': sessionNumber}), color: AppColors.forest),
                    CodePill(t('code.purpose.${item.purpose.name}'), color: AppColors.mint),
                    if (closed) CodePill(t('code.list.archived'), color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.black),
                ),
                const SizedBox(height: 6),
                Text(
                  item.dueAt == null
                      ? t('code.list.noDue')
                      : t('code.list.due', {'time': Dates.instant(item.dueAt!, timeZone)}),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                Text(
                  t('code.list.meta', {'score': item.maxScore, 'attempts': item.maxAttempts}),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
