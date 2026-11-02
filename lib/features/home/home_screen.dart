import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/session/session_controller.dart';
import '../../core/ui/ui.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import '../courses/course_sheet.dart';
import '../courses/course_tile.dart';
import '../courses/courses_models.dart';
import '../schedule/schedule_models.dart';
import 'home_providers.dart';
import 'home_sections.dart';

/// Trang chủ học viên - port từ `StudentHome.tsx` + `ProductionStudentHome.tsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  double _previousY = 0;
  bool _compact = false;
  bool _hidden = false;
  bool _active = false, _seen = false;
  Object? _refreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final y = _scroll.position.pixels;
    final delta = y - _previousY;

    final newCompact = y > 150;
    if (newCompact != _compact) {
      setState(() => _compact = newCompact);
    }

    if (y < 20 || delta < -3) {
      if (_hidden) setState(() => _hidden = false);
    } else if (y > 60 && delta > 3) {
      if (!_hidden) setState(() => _hidden = true);
    }
    _previousY = y;
  }

  void _scrollToTop() {
    if (Motion.reduced(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: Motion.base, curve: Motion.curve);
    }
    setState(() => _hidden = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncActive();

  void _syncActive() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) && ModalRoute.of(context)?.isCurrent != false;
    if (active == _active) return;
    _active = active;
    if (!active) return;
    if (_seen) {
      Future.microtask(() async {
        if (mounted && _active) await _refresh();
      });
    }
    _seen = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshError = null);
    try {
      ref.invalidate(homeCoursesProvider);
      ref.invalidate(homeNextSessionProvider);
      await Future.wait([
        ref.read(homeCoursesProvider.future),
        ref.read(homeNextSessionProvider.future),
      ]);
    } catch (e) {
      if (mounted) setState(() => _refreshError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider).user;
    final cartCount = ref.watch(cartCountProvider);
    final courses = ref.watch(homeCoursesProvider);
    final next = ref.watch(homeNextSessionProvider);

    final insets = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final reduced = Motion.reduced(context);
    final screenReader = MediaQuery.accessibleNavigationOf(context);

    final mascotWidth = width < 360 ? 128.0 : 196.0;
    final mascotHeight = mascotWidth * 0.8;
    final greetingMaxWidth = width < 360 ? width - mascotWidth - 4 : 218.0;

    final tabHidden = _hidden && !reduced && !screenReader;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.mint,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            // Nội dung cuộn chính
            RefreshIndicator(
              color: AppColors.mint,
              onRefresh: _refresh,
              child: ListView(
                key: const Key('home-content'),
                controller: _scroll,
                padding: EdgeInsets.zero,
                children: [
                  // 1. Hero
                  Container(
                    key: const Key('home-header'),
                    color: AppColors.mint,
                    padding: EdgeInsets.only(top: insets.top, bottom: 26),
                    constraints: BoxConstraints(minHeight: insets.top + 190),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandBar(
                              prefix: 'home',
                              onTop: _scrollToTop,
                              onCart: () => showCartSheet(context),
                              cartCount: cartCount,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 18, top: 18),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: greetingMaxWidth),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('home.greeting', {'name': user?.displayName ?? ''}),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.line,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        t('home.title'),
                                        style: const TextStyle(
                                          fontSize: 27,
                                          fontWeight: FontWeight.w800,
                                          height: 30.2 / 27,
                                          letterSpacing: -0.54,
                                          color: AppColors.canvas,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Mascot Mindy
                        Positioned(
                          bottom: -14,
                          right: -4,
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/illustrations/mindy-mascot-laptop.png',
                              key: const Key('home-mascot'),
                              width: mascotWidth,
                              height: mascotHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Lỗi refresh nếu có
                  if (_refreshError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ScreenState(
                        title: t('home.errorTitle'),
                        description: t('errors.generic'),
                        onRetry: _refresh,
                        retryKey: const Key('home-refresh-retry-button'),
                      ),
                    ),

                  // 3. Buổi tiếp theo (chỉ hiện khi có lỗi, đang tải, hoặc có buổi)
                  _buildNextSession(context, t, next),

                  // 4. Khoá học nổi bật (2 cột)
                  _buildFeaturedCourses(context, t, courses),

                  // 5. Intro carousel
                  const HomeIntro(),

                  // 6. Compiler
                  HomeCompiler(name: user?.displayName ?? ''),

                  // 7. About carousel
                  const HomeAbout(),

                  // 8. Footer tràn ngang
                  HomeFooter(
                    sessionControls: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: MindyButton(
                        key: const Key('session-logout'),
                        label: t('auth.session.logout'),
                        variant: ButtonVariant.solid,
                        expand: false,
                        onPressed: () => ref.read(sessionProvider.notifier).logout(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header thu gọn nổi
            AnimatedPositioned(
              duration: Duration(milliseconds: reduced ? 0 : 200),
              curve: Motion.curve,
              top: _compact ? 0 : -(insets.top + 52),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: reduced ? 0 : 200),
                opacity: _compact ? 1 : 0,
                child: _compact
                    ? Container(
                        key: const Key('home-compact-header'),
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
                          compact: true,
                          prefix: 'home',
                          onTop: _scrollToTop,
                          onCart: () => showCartSheet(context),
                          cartCount: cartCount,
                        ),
                      )
                    : const IgnorePointer(
                        child: ExcludeSemantics(
                          child: SizedBox.shrink(),
                        ),
                      ),
              ),
            ),

            // Tab bar nổi
            AnimatedPositioned(
              duration: Duration(milliseconds: reduced ? 0 : 200),
              curve: Motion.curve,
              left: 12,
              right: 12,
              bottom: tabHidden ? -160 : math.max(insets.bottom - 12.0, 0.0),
              child: tabHidden
                  ? const IgnorePointer(
                      child: ExcludeSemantics(
                        child: SizedBox.shrink(),
                      ),
                    )
                  : AppTabBar(
                      prefix: 'home',
                      selected: HomeTab.home,
                      learningEnabled: true,
                      onTop: _scrollToTop,
                      onTab: (tab) => goTab(context, tab),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSession(BuildContext context, Translator t, AsyncValue<HomeNextSession> next) {
    // Chỉ hiện khi status ≠ success hoặc có buổi
    final hasSession = next.value?.session != null;
    if (next.hasValue && !hasSession && !next.hasError) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('home-next-session'),
      margin: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sunshine,
        borderRadius: BorderRadius.circular(20),
      ),
      child: next.when(
        data: (n) {
          final s = n.session;
          if (s == null) return const SizedBox.shrink();
          final timeStr = DateFormat('dd/MM HH:mm').format(Dates.inZone(s.startsAt, n.timeZone));
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 144),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t('home.sections.nextSession')} · $timeStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.className} · ${s.sessionTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              MindyButton(
                key: const Key('home-join-class-button'),
                label: t(s.access == ScheduleAccess.CASH_PREVIEW ? 'home.actions.previewClass' : 'home.actions.join'),
                variant: ButtonVariant.solid,
                minHeight: 44,
                radius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                expand: false,
                onPressed: () => context.push(Routes.classDetail(s.classId, sessionId: s.sessionId)),
              ),
            ],
          );
        },
        loading: () => const Skeleton(
          key: Key('home-schedule-loading'),
          height: 72,
          radius: 20,
        ),
        error: (e, _) => ScreenState(
          key: const Key('home-schedule-error'),
          title: t('home.errorTitle'),
          description: t(errorKey(e)),
          onRetry: () => ref.invalidate(homeNextSessionProvider),
          requestId: requestIdOf(e),
          retryKey: const Key('home-schedule-retry-button'),
        ),
      ),
    );
  }

  Widget _buildFeaturedCourses(BuildContext context, Translator t, AsyncValue<List<Course>> courses) {
    return Container(
      key: const Key('home-featured-courses'),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              t('home.sections.courses'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.44,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: 14),
          courses.when(
            data: (list) {
              if (list.isEmpty) {
                return ScreenState(
                  key: const Key('home-empty'),
                  title: t('home.empty.title'),
                  description: t('home.empty.description'),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        SizedBox(
                          width: itemWidth,
                          child: CourseTile(
                            course: list[i],
                            index: i,
                            loadOpenClass: false,
                            prefix: 'home',
                            onTap: () => showCourseSheet(context, list[i].id),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => LayoutBuilder(
              key: const Key('home-loading'),
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: itemWidth,
                        child: const AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Skeleton(radius: 20),
                        ),
                      ),
                  ],
                );
              },
            ),
            error: (e, _) => ScreenState(
              key: const Key('home-error'),
              title: t('home.errorTitle'),
              description: t(errorKey(e)),
              onRetry: () => ref.invalidate(homeCoursesProvider),
              requestId: requestIdOf(e),
              retryKey: const Key('home-retry-button'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: HomeButton(
              key: const Key('home-explore-courses-button'),
              label: t('home.actions.explore'),
              minHeight: 52,
              onPressed: () => context.go(Routes.courses),
            ),
          ),
        ],
      ),
    );
  }
}
