import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/utils/format.dart';
import '../schedule/schedule_providers.dart';
import 'my_classes_models.dart';
import 'my_classes_providers.dart';

/// Lớp của tôi - port 1:1 từ `MindyMobile/src/modules/my-classes/MyClassesScreen.tsx`.
class MyClassesScreen extends ConsumerStatefulWidget {
  const MyClassesScreen({super.key, required this.origin});

  /// home | courses | account - để Back / tab đúng nơi
  final String origin;

  @override
  ConsumerState<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends ConsumerState<MyClassesScreen> {
  String _view = 'current'; // 'current' | 'history'
  final Set<String> _expanded = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _changeView(String next) {
    if (_view == next) return;
    setState(() => _view = next);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onBack(BuildContext context, HomeTab originTab) {
    if (context.canPop()) {
      context.pop();
    } else {
      goTab(context, originTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final classesAsync = ref.watch(myClassesProvider(_view));
    final timeZone = ref.watch(learningTimeZoneProvider).value ?? 'Asia/Ho_Chi_Minh';
    final originTab = HomeTab.values.asNameMap()[widget.origin] ?? HomeTab.account;
    final destination = _view == 'current' ? 'history' : 'current';

    final items = classesAsync.value?.items ?? const [];
    final groups = groupEnrollments(items);
    final hasMore = classesAsync.value?.hasMore ?? false;
    final loadingMore = classesAsync.value?.loadingMore ?? false;
    final loadMoreError = classesAsync.value?.moreError;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: t('learning.back'),
            child: InkWell(
              key: const Key('my-classes-back'),
              borderRadius: BorderRadius.circular(22),
              onTap: () => _onBack(context, originTab),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                alignment: Alignment.center,
                child: const MindyIcon(MindyIconName.back, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _view == 'history' ? t('myClasses.historyTitle') : t('myClasses.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 24 / 18,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_view == 'history')
            Semantics(
              button: true,
              label: t('myClasses.view.$destination'),
              hint: t('myClasses.switchView'),
              child: InkWell(
                key: Key('my-classes-view-$destination'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => _changeView(destination),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: MindyIcon(MindyIconName.book, size: 18),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );

    return LearningLayout(
      prefix: 'my-classes',
      title: t('myClasses.title'),
      onBack: () => _onBack(context, originTab),
      showTitle: false,
      header: header,
      tab: originTab,
      onTab: (tab) => goTab(context, tab),
      refreshing: classesAsync.isRefreshing,
      onRefresh: () async => ref.refresh(myClassesProvider(_view).future),
      scrollController: _scrollController,
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LearningState<ClassesList>(
            asyncValue: classesAsync,
            prefix: 'my-classes',
            empty: false,
            onRetry: () => ref.refresh(myClassesProvider(_view).future),
            child: groups.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.soft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < groups.length; i++) ...[
                          _buildCourseGroup(
                            context,
                            t,
                            groups[i],
                            timeZone,
                            hasMore,
                            loadingMore,
                            loadMoreError,
                          ),
                          if (i < groups.length - 1)
                            const Divider(height: 1, thickness: 1, color: AppColors.line),
                        ],
                      ],
                    ),
                  ),
          ),
          if (classesAsync.hasValue && groups.isEmpty) ...[
            Container(
              key: const Key('my-classes-empty'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('myClasses.empty.$_view'),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MindyButton(
                    label: t('myClasses.explore'),
                    onPressed: () => context.go(Routes.courses),
                  ),
                ],
              ),
            ),
          ],
          if (hasMore || loadMoreError != null) ...[
            const SizedBox(height: 16),
            MindyButton(
              key: const Key('my-classes-load-more'),
              loading: loadingMore,
              variant: ButtonVariant.outline,
              label: t(loadMoreError != null ? 'common.retry' : 'myClasses.loadMore'),
              onPressed: () => ref.read(myClassesProvider(_view).notifier).loadMore(),
            ),
          ],
          if (loadMoreError != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                t('myClasses.moreError'),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.headsup,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseGroup(
    BuildContext context,
    Translator t,
    ({String courseId, String title, String code, List<Enrollment> items}) group,
    String timeZone,
    bool hasMore,
    bool loadingMore,
    Object? loadMoreError,
  ) {
    final isExpanded = _expanded.contains(group.courseId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: isExpanded,
          child: InkWell(
            key: Key('my-classes-course-${group.courseId}'),
            onTap: () {
              setState(() {
                if (_expanded.contains(group.courseId)) {
                  _expanded.remove(group.courseId);
                } else {
                  _expanded.add(group.courseId);
                }
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isExpanded ? AppColors.mint : AppColors.canvas,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: MindyIcon(
                        isExpanded ? MindyIconName.folderOpen : MindyIconName.folder,
                        size: 19,
                        color: isExpanded ? AppColors.canvas : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            group.title,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${group.code} · ${t(hasMore || loadingMore || loadMoreError != null ? 'myClasses.loaded' : 'myClasses.count', {'count': group.items.length})}',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Text(
                        isExpanded ? t('myClasses.collapseSymbol') : t('schedule.next'),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 10, bottom: 8),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.line, width: 2)),
              ),
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: [
                  for (final row in group.items) ...[
                    _EnrollmentRow(
                      row: row,
                      timeZone: timeZone,
                      onRefresh: () async => ref.refresh(myClassesProvider(_view).future),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EnrollmentRow extends ConsumerWidget {
  const _EnrollmentRow({
    required this.row,
    required this.timeZone,
    this.onRefresh,
  });

  final Enrollment row;
  final String timeZone;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final action = row.action;
    final canOpen = action == EnrollmentAction.FULL || action == EnrollmentAction.CASH_PREVIEW;
    final mismatch = (action == EnrollmentAction.NONE && row.accessMode != AccessMode.NONE) ||
        ((row.accessReason == AccessReason.PENDING_CASH || row.accessReason == AccessReason.PENDING_PAYOS) && row.order == null);

    final deliveryStr = t('schedule.delivery.${row.deliveryMode.name}');
    final description = '$deliveryStr · ${Dates.displayDay(row.startDate)} – ${Dates.displayDay(row.endDate)}';

    final summary = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.classCode,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11.5,
                      height: 16 / 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (action == EnrollmentAction.CASH_PREVIEW) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  t('myClasses.preview'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (canOpen)
              ExcludeSemantics(
                child: Text(
                  t('schedule.next'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.mint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final a11yLabel = [
      row.classCode,
      row.className,
      description,
      row.mentorName,
      t('myClasses.access.${row.accessReason.name}'),
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      key: Key('my-classes-enrollment-${row.enrollmentId}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canOpen)
            Semantics(
              button: true,
              label: a11yLabel,
              child: InkWell(
                key: Key('my-classes-open-${row.enrollmentId}'),
                onTap: () => context.push(Routes.classDetail(row.classId)),
                child: summary,
              ),
            )
          else
            summary,
          if (!canOpen || row.order?.requiresReview == true || action == EnrollmentAction.CASH_PREVIEW)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canOpen)
                    Text(
                      t('myClasses.access.${mismatch ? "STATE_MISMATCH" : row.accessReason.name}'),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  if (row.order?.requiresReview == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      t('myClasses.review'),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: AppColors.headsup,
                      ),
                    ),
                  ],
                  if (row.order?.expiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      t('myClasses.expires', {'date': Dates.instant(row.order!.expiresAt!, timeZone)}),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (action == EnrollmentAction.PAYMENT && row.order != null) ...[
                    const SizedBox(height: 6),
                    MindyButton(
                      key: Key('my-classes-resume-${row.enrollmentId}'),
                      variant: ButtonVariant.action,
                      minHeight: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      label: t('myClasses.resume'),
                      onPressed: () => context.push(Routes.payment(row.order!.orderId, fromLearning: true)),
                    ),
                  ],
                  if (mismatch) ...[
                    const SizedBox(height: 6),
                    MindyButton(
                      variant: ButtonVariant.outline,
                      minHeight: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      label: t('common.retry'),
                      onPressed: onRefresh,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
