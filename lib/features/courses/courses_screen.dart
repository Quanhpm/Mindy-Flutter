import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import 'course_sheet.dart';
import 'course_tile.dart';
import 'courses_models.dart';
import 'courses_providers.dart';

/// Danh mục khoá học - `courses/CoursesRoute.tsx` + `CoursesScreen.tsx`.
/// Danh mục · bộ lọc hình thức · gợi ý 3 khoá · lưới 6 khoá/trang · phân trang.
/// TODO(UI): port Recommendations carousel + pagination dạng số trang có "…".
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final filter = ref.watch(catalogFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final page = ref.watch(catalogPageProvider);
    final recommendations = ref.watch(recommendationsProvider);
    final cartCount = ref.watch(cartCountProvider);
    final ctrl = ref.read(catalogFilterProvider.notifier);

    return Scaffold(
      bottomNavigationBar: const AppTabBar(selected: HomeTab.courses),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoriesProvider);
            ref.invalidate(catalogPageProvider);
            ref.invalidate(recommendationsProvider);
            ref.invalidate(cartProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(child: Text(t('home.tabs.courses'), style: AppText.sectionTitle(AppColors.black))),
                  Pressable(
                    onTap: () => _openFilter(context, ref, filter.deliveryMode),
                    semanticLabel: t('courses.filter.title'),
                    child: const SizedBox.square(dimension: 48, child: Center(child: MindyIcon(MindyIconName.filter))),
                  ),
                  Pressable(
                    onTap: () => showCartSheet(context),
                    semanticLabel: t('home.actions.cart'),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Badge(
                        isLabelVisible: cartCount > 0,
                        label: Text('$cartCount'),
                        child: const Center(child: MindyIcon(MindyIconName.cart)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Danh mục (giữ màu gốc, đặt ngoài vùng catalog)
              AsyncView(
                value: categories,
                loading: const Skeleton(height: 40),
                onRetry: () => ref.invalidate(categoriesProvider),
                data: (cats) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(t('courses.categories.all'), filter.categoryId == null, () => ctrl.category(null)),
                      for (final c in cats) _chip(c.name, filter.categoryId == c.id, () => ctrl.category(c.id)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              RegionColors.catalog(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Gợi ý
                    Text(t('courses.recommend.title'), style: AppText.title(AppColors.catalogInk)),
                    const SizedBox(height: 12),
                    AsyncView(
                      value: recommendations,
                      onRetry: () => ref.invalidate(recommendationsProvider),
                      data: (list) => SizedBox(
                        height: 260,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => SizedBox(
                            width: 240,
                            child: CourseTile(
                              course: list[i],
                              index: i,
                              onTap: () => showCourseSheet(context, list[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Lưới khoá học
                    AsyncView(
                      value: page,
                      onRetry: () => ref.invalidate(catalogPageProvider),
                      data: (p) {
                        if (p.items.isEmpty) {
                          return Column(children: [
                            Text(t('courses.grid.empty')),
                            const SizedBox(height: 12),
                            MindyButton(
                              label: t('courses.grid.clearFilter'),
                              variant: ButtonVariant.outline,
                              onPressed: () => ctrl.mode(null),
                            ),
                          ]);
                        }
                        final pages = (p.total / catalogPageSize).ceil();
                        return Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: p.items.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                              itemBuilder: (_, i) => CourseTile(
                                course: p.items[i],
                                index: i,
                                onTap: () => showCourseSheet(context, p.items[i].id),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextLink(t('courses.pagination.previous'),
                                    onTap: filter.page > 1 ? () => ctrl.page(filter.page - 1) : null),
                                const SizedBox(width: 16),
                                Text(t('courses.pagination.page', {'page': filter.page})),
                                const SizedBox(width: 16),
                                TextLink(t('courses.pagination.next'),
                                    onTap: filter.page < pages ? () => ctrl.page(filter.page + 1) : null),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          onTap: onTap,
          selected: active,
          semanticLabel: label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.forest : AppColors.soft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, color: active ? AppColors.canvas : AppColors.forest)),
          ),
        ),
      );

  void _openFilter(BuildContext context, WidgetRef ref, DeliveryMode? current) =>
      showAppSheet<void>(context, initialSize: 0.5, (_) => _FilterSheet(current: current));
}

/// `courses/components/FilterSheet.tsx`: chọn nháp, nút hiện "Xem N khoá học".
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.current});
  final DeliveryMode? current;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DeliveryMode? _draft = widget.current;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final count = ref.watch(filterCountProvider(_draft)).value;

    Widget option(String label, DeliveryMode? mode) {
      final active = _draft == mode;
      return Pressable(
        onTap: () => setState(() => _draft = mode),
        selected: active,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.body(AppColors.forest))),
            if (active) const MindyIcon(MindyIconName.check, color: AppColors.mint),
          ]),
        ),
      );
    }

    return ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(t('courses.filter.title'), style: AppText.title(AppColors.forest)),
        const SizedBox(height: 8),
        Text(t('courses.filter.mode'), style: AppText.label(AppColors.forest)),
        option(t('courses.filter.all'), null),
        option(t('courses.filter.ONLINE'), DeliveryMode.ONLINE),
        option(t('courses.filter.OFFLINE'), DeliveryMode.OFFLINE),
        const SizedBox(height: 12),
        MindyButton(
          label: t('courses.filter.apply', {'count': count ?? '…'}),
          onPressed: () {
            ref.read(catalogFilterProvider.notifier).mode(_draft);
            Navigator.of(context).pop();
          },
        ),
        TextLink(t('courses.filter.reset'), onTap: () => setState(() => _draft = null)),
      ],
    );
  }
}
