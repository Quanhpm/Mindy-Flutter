import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import 'my_classes_models.dart';
import 'my_classes_providers.dart';

/// Lớp của tôi - `my-classes/MyClassesScreen.tsx`.
/// Hiện tại / Lịch sử · nhóm folder theo khoá · "Tải thêm" · nút theo quyền:
/// FULL -> Xem lớp, CASH_PREVIEW -> Xem trước, PAYMENT -> Tiếp tục thanh toán.
/// TODO(UI): port folder thu gọn/mở rộng + ảnh khoá theo MyClassesScreen.tsx.
class MyClassesScreen extends ConsumerStatefulWidget {
  const MyClassesScreen({super.key, required this.origin});

  /// home | courses | account - để Back/tab đúng nơi
  final String origin;

  @override
  ConsumerState<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends ConsumerState<MyClassesScreen> {
  String _view = 'current';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final list = ref.watch(myClassesProvider(_view));

    return Scaffold(
      appBar: AppBar(
        title: Text(t(_view == 'current' ? 'myClasses.title' : 'myClasses.historyTitle')),
        leading: IconButton(
          tooltip: t('learning.back'),
          icon: const MindyIcon(MindyIconName.back),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myClassesProvider(_view)),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'current', label: Text(t('myClasses.view.current'))),
                ButtonSegment(value: 'history', label: Text(t('myClasses.view.history'))),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
            const SizedBox(height: 16),
            AsyncView(
              value: list,
              onRetry: () => ref.invalidate(myClassesProvider(_view)),
              data: (data) {
                if (data.items.isEmpty) {
                  return Column(children: [
                    ScreenState(title: t('myClasses.state.empty'), description: t('myClasses.empty.$_view')),
                    const SizedBox(height: 12),
                    MindyButton(label: t('myClasses.explore'), onPressed: () => context.go(Routes.courses)),
                  ]);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final g in groupEnrollments(data.items)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(children: [
                          const MindyIcon(MindyIconName.folder),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g.title, style: AppText.title(AppColors.forest))),
                          Text(t('myClasses.count', {'count': g.items.length}), style: AppText.caption(AppColors.muted)),
                        ]),
                      ),
                      for (final e in g.items) _row(t, e),
                    ],
                    if (data.moreError != null)
                      Text(t('myClasses.moreError'), style: const TextStyle(color: AppColors.headsup)),
                    if (data.hasMore)
                      MindyButton(
                        label: t('myClasses.loadMore'),
                        variant: ButtonVariant.outline,
                        loading: data.loadingMore,
                        onPressed: () => ref.read(myClassesProvider(_view).notifier).loadMore(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Translator t, Enrollment e) {
    final action = e.action;
    final order = e.order;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.className, style: AppText.label(AppColors.forest)),
          Text('${e.classCode} · ${t('learning.delivery.${e.deliveryMode.name}')} · '
              '${Dates.dateOnly(e.startDate)} – ${Dates.dateOnly(e.endDate)}',
              style: AppText.caption(AppColors.muted)),
          const SizedBox(height: 4),
          Text(t('myClasses.access.${e.accessReason.name}'), style: AppText.caption(AppColors.forest)),
          if (order?.expiresAt != null && action == EnrollmentAction.PAYMENT)
            Text(t('myClasses.expires', {'date': Dates.instant(order!.expiresAt!, 'Asia/Ho_Chi_Minh')}),
                style: AppText.caption(AppColors.muted)),
          if (order?.requiresReview == true)
            Text(t('myClasses.review'), style: const TextStyle(color: AppColors.statusYellow)),
          const SizedBox(height: 8),
          switch (action) {
            EnrollmentAction.FULL => MindyButton(
                label: t('myClasses.open'),
                onPressed: () => context.push(Routes.classDetail(e.classId)),
              ),
            EnrollmentAction.CASH_PREVIEW => MindyButton(
                label: t('myClasses.preview'),
                variant: ButtonVariant.outline,
                onPressed: () => context.push(Routes.classDetail(e.classId)),
              ),
            EnrollmentAction.PAYMENT => MindyButton(
                label: t('myClasses.resume'),
                variant: ButtonVariant.action,
                onPressed: () => context.push(Routes.payment(order!.orderId, fromLearning: true)),
              ),
            EnrollmentAction.NONE => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}
