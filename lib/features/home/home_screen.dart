import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/ui/ui.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import '../courses/course_sheet.dart';
import '../courses/course_tile.dart';
import 'home_providers.dart';

/// Trang chủ học viên - `home/ProductionStudentHome.tsx` + `StudentHome.tsx`.
///
/// Các vùng: header (tên + giỏ) · buổi học tiếp theo · khoá học nổi bật ·
/// carousel giới thiệu · compiler (chỉ giới thiệu) · về chúng tôi · footer.
/// TODO(UI): port HomeCarousel (autoplay, dừng khi background), HomeCompiler (terminal
/// minh hoạ), notes "Về chúng tôi", footer - xem `home/components/*` và Student Home.dc.html.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(homeCoursesProvider);
    ref.invalidate(homeNextSessionProvider);
    await Future.wait([
      ref.read(homeCoursesProvider.future),
      ref.read(homeNextSessionProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider).user;
    final cartCount = ref.watch(cartCountProvider);
    final courses = ref.watch(homeCoursesProvider);
    final next = ref.watch(homeNextSessionProvider);

    return Scaffold(
      bottomNavigationBar: AppTabBar(
        selected: HomeTab.home,
        onHomeTop: () => _scroll.animateTo(0, duration: Motion.base, curve: Motion.curve),
      ),
      body: SafeArea(
        bottom: false,
        child: RegionColors.home(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // ---- Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('home.greeting', {'name': user?.displayName ?? ''}),
                              style: AppText.label(AppColors.black)),
                          Text(t('home.title'), style: AppText.title(AppColors.black)),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: () => showCartSheet(context),
                      semanticLabel: t('home.actions.cart'),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text('$cartCount'),
                          child: const Center(child: MindyIcon(MindyIconName.cart, color: AppColors.black)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---- Buổi học tiếp theo
                Text(t('home.sections.nextSession'), style: AppText.title(AppColors.black)),
                const SizedBox(height: 12),
                AsyncView(
                  value: next,
                  errorTitleKey: 'home.errorTitle',
                  onRetry: () => ref.invalidate(homeNextSessionProvider),
                  loading: const Skeleton(height: 96),
                  data: (n) {
                    final s = n.session;
                    if (s == null) {
                      return MindyButton(
                        label: t('home.actions.explore'),
                        variant: ButtonVariant.outline,
                        onPressed: () => context.go(Routes.courses),
                      );
                    }
                    return Pressable(
                      onTap: () => context.push(Routes.classDetail(s.classId, sessionId: s.sessionId)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.sessionTitle, style: AppText.label(AppColors.black)),
                            Text(s.classCode, style: AppText.caption(AppColors.black)),
                            const SizedBox(height: 6),
                            Text(Dates.instant(s.startsAt, n.timeZone), style: AppText.label(AppColors.mint)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // ---- Khoá học nổi bật
                Text(t('home.sections.courses'), style: AppText.title(AppColors.black)),
                const SizedBox(height: 12),
                AsyncView(
                  value: courses,
                  errorTitleKey: 'home.errorTitle',
                  onRetry: () => ref.invalidate(homeCoursesProvider),
                  data: (list) => list.isEmpty
                      ? ScreenState(title: t('home.empty.title'), description: t('home.empty.description'))
                      : Column(
                          children: [
                            for (var i = 0; i < list.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: CourseTile(
                                  course: list[i],
                                  index: i,
                                  onTap: () => showCourseSheet(context, list[i].id),
                                ),
                              ),
                          ],
                        ),
                ),
                MindyButton(label: t('home.actions.explore'), onPressed: () => context.go(Routes.courses)),
                const SizedBox(height: 12),
                MindyButton(
                  label: t('home.footer.myClasses'),
                  variant: ButtonVariant.outline,
                  onPressed: () => context.push(Routes.myClasses('home')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
