import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/json.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/brand_bar.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/ui/tab_bar.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import 'course_sheet.dart';
import 'course_tile.dart';
import 'courses_models.dart';
import 'courses_providers.dart';
import 'filter_sheet.dart';
import 'recommendations.dart';

/// Màn hình danh mục khoá học - port từ `CoursesScreen.tsx` + `CoursesRoute.tsx`.
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _categoriesKey = GlobalKey();

  void _goto(int page) {
    ref.read(catalogFilterProvider.notifier).page(page);
    final context = _categoriesKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, alignment: 0.0);
    }
  }

  void _openFilter(BuildContext context) {
    final filter = ref.read(catalogFilterProvider);
    showAppSheet<void>(
      context,
      (ctx) => Consumer(
        builder: (context, ref, _) {
          final count = ref.watch(filterCountProvider(filter.deliveryMode)).value;
          return FilterSheet(
            deliveryMode: filter.deliveryMode,
            total: count,
            onPreview: (draft) {
              ref.invalidate(filterCountProvider(draft));
            },
            onApply: (mode) {
              ref.read(catalogFilterProvider.notifier).mode(mode);
            },
            onClose: () => Navigator.of(ctx).pop(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final insets = MediaQuery.paddingOf(context);
    final filter = ref.watch(catalogFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final pageAsync = ref.watch(catalogPageProvider);
    final recsAsync = ref.watch(recommendationsProvider);
    final cartCount = ref.watch(cartCountProvider);
    final ctrl = ref.read(catalogFilterProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.mint,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            // Cột cuộn gồm header và nội dung
            Column(
              children: [
                // Header BrandBar nền mint
                Container(
                  key: const Key('courses-header'),
                  padding: EdgeInsets.only(top: insets.top, bottom: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3312302E),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: BrandBar(
                    prefix: 'courses',
                    onTop: () => goTab(context, HomeTab.home),
                    onCart: () => showCartSheet(context),
                    cartCount: cartCount,
                  ),
                ),

                // Vùng cuộn
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.mint,
                    onRefresh: () async {
                      ref.invalidate(categoriesProvider);
                      ref.invalidate(catalogPageProvider);
                      ref.invalidate(recommendationsProvider);
                      ref.invalidate(cartProvider);
                    },
                    child: SingleChildScrollView(
                      key: const Key('courses-screen'),
                      controller: _scrollController,
                      padding: EdgeInsets.only(bottom: 100 + insets.bottom),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Gợi ý
                            _buildRecommendations(t, recsAsync),
                            const SizedBox(height: 22),

                            // 2. Danh mục & Lọc
                            _buildCategories(t, categoriesAsync, filter, ctrl),
                            const SizedBox(height: 22),

                            // 3. Lưới khoá học
                            _buildCoursesGrid(t, pageAsync, filter, ctrl),

                            // 4. Phân trang
                            if (pageAsync.hasValue) _buildPagination(t, pageAsync.value!, filter.page),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Tab bar nổi
            Positioned(
              left: 12,
              right: 12,
              bottom: math.max(insets.bottom - 12.0, 0.0),
              child: AppTabBar(
                prefix: 'courses',
                selected: HomeTab.courses,
                learningEnabled: true,
                onTop: () => goTab(context, HomeTab.home),
                onTab: (tab) => goTab(context, tab),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(Translator t, AsyncValue<List<Course>> recs) {
    if (recs.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Skeleton(height: 206, radius: 24),
      );
    }
    if (recs.hasError) {
      return ScreenState(
        title: t('home.errorTitle'),
        description: t('errors.generic'),
        retryKey: const Key('courses-recommend-retry'),
        onRetry: () => ref.invalidate(recommendationsProvider),
      );
    }
    return Recommendations(
      courses: recs.value ?? const [],
      onOpen: (id) => showCourseSheet(context, id),
    );
  }

  Widget _buildCategories(
    Translator t,
    AsyncValue<List<CourseCategory>> catsAsync,
    CatalogFilter filter,
    CatalogFilterController ctrl,
  ) {
    return Column(
      key: _categoriesKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('courses-categories'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('courses.categories.title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              Pressable(
                key: const Key('courses-filter-button'),
                semanticLabel: t('courses.filter.title'),
                onTap: () => _openFilter(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const MindyIcon(
                        MindyIconName.filter,
                        size: 19,
                        color: AppColors.black,
                      ),
                      if (filter.deliveryMode != null)
                        Positioned(
                          top: 6,
                          right: 7,
                          child: Container(
                            key: const Key('courses-filter-dot'),
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.coral,
                              border: Border.all(color: AppColors.canvas, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (catsAsync.hasError)
          ScreenState(
            title: t('courses.categories.title'),
            description: t('errors.generic'),
            retryKey: const Key('courses-categories-retry'),
            onRetry: () => ref.invalidate(categoriesProvider),
          )
        else if (catsAsync.isLoading)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Skeleton(width: 76, height: 38, radius: 12),
                  ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                _buildCategoryChip(
                  t('courses.categories.all'),
                  'all',
                  filter.categoryId == null,
                  () => ctrl.category(null),
                ),
                for (final c in catsAsync.value ?? const <CourseCategory>[])
                  _buildCategoryChip(
                    c.name,
                    c.id,
                    filter.categoryId == c.id,
                    () => ctrl.category(c.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(String name, String id, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        key: Key('courses-category-$id'),
        selected: selected,
        semanticLabel: name,
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? AppColors.forest : AppColors.soft,
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.canvas : AppColors.forest,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesGrid(
    Translator t,
    AsyncValue<Paged<Course>> pageAsync,
    CatalogFilter filter,
    CatalogFilterController ctrl,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;

          if (pageAsync.isLoading) {
            return Wrap(
              key: const Key('courses-loading'),
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: itemWidth,
                    child: const AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Skeleton(radius: 20),
                    ),
                  ),
              ],
            );
          }

          if (pageAsync.hasError) {
            return ScreenState(
              key: const Key('courses-error'),
              title: t('home.errorTitle'),
              description: t('errors.generic'),
              retryKey: const Key('courses-retry'),
              onRetry: () => ref.invalidate(catalogPageProvider),
            );
          }

          final items = pageAsync.value?.items ?? const [];
          if (items.isEmpty) {
            return Container(
              key: const Key('courses-empty'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.soft,
              ),
              child: Column(
                children: [
                  Text(
                    t('courses.grid.empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  if (filter.categoryId != null || filter.deliveryMode != null) ...[
                    const SizedBox(height: 8),
                    Pressable(
                      onTap: () {
                        ctrl.category(null);
                        ctrl.mode(null);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        child: Text(
                          t('courses.grid.clearFilter'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return Wrap(
            key: const Key('courses-grid'),
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < math.min(items.length, 6); i++)
                SizedBox(
                  width: itemWidth,
                  child: CourseTile(
                    course: items[i],
                    index: i,
                    prefix: 'courses',
                    onTap: () => showCourseSheet(context, items[i].id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPagination(Translator t, Paged<Course> paged, int currentPage) {
    final pages = (paged.total / catalogPageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();

    final pageItems = List.generate(pages, (i) => i + 1).where((n) {
      return pages <= 5 || n == 1 || n == pages || (n - currentPage).abs() <= 1;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            label: '‹',
            id: 'prev',
            disabled: currentPage == 1,
            selected: false,
            onPress: () => _goto(currentPage - 1),
            semanticLabel: t('courses.pagination.previous'),
          ),
          for (var i = 0; i < pageItems.length; i++) ...[
            if (i > 0 && pageItems[i] > pageItems[i - 1] + 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  t('courses.pagination.ellipsis'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            _buildPageButton(
              label: '${pageItems[i]}',
              id: '${pageItems[i]}',
              disabled: false,
              selected: pageItems[i] == currentPage,
              onPress: () => _goto(pageItems[i]),
              semanticLabel: t('courses.pagination.page', {'page': pageItems[i]}),
            ),
          ],
          const SizedBox(width: 8),
          _buildPageButton(
            label: '›',
            id: 'next',
            disabled: currentPage == pages,
            selected: false,
            onPress: () => _goto(currentPage + 1),
            semanticLabel: t('courses.pagination.next'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required String label,
    required String id,
    required bool disabled,
    required bool selected,
    required VoidCallback onPress,
    required String semanticLabel,
  }) {
    return Pressable(
      key: Key('courses-page-$id'),
      semanticLabel: semanticLabel,
      selected: selected,
      onTap: disabled ? null : onPress,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? AppColors.mint
              : disabled
                  ? Colors.transparent
                  : AppColors.soft,
          border: disabled ? Border.all(color: AppColors.line) : null,
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.canvas : AppColors.forest,
            ),
          ),
        ),
      ),
    );
  }
}
