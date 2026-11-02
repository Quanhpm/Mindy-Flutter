import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/pressable.dart';
import '../../core/utils/format.dart';
import 'courses_models.dart';

/// Khối gợi ý khoá học dạng carousel - `Recommendations.tsx`.
class Recommendations extends ConsumerStatefulWidget {
  const Recommendations({
    super.key,
    required this.courses,
    required this.onOpen,
  });

  final List<Course> courses;
  final void Function(String id) onOpen;

  @override
  ConsumerState<Recommendations> createState() => _RecommendationsState();
}

class _RecommendationsState extends ConsumerState<Recommendations> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  bool _userInteracted = false;

  static const _softColors = [
    AppColors.coverASoft,
    AppColors.coverBSoft,
    AppColors.coverCSoft,
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoplay();
  }

  void _startAutoplay() {
    _timer?.cancel();
    if (_userInteracted || widget.courses.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (!mounted || _userInteracted) return;
      final count = math.min(widget.courses.length, 3);
      if (count <= 1) return;
      final next = (_page + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Motion.curve,
      );
    });
  }

  void _onUserInteraction() {
    if (!_userInteracted) {
      _userInteracted = true;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _onUserInteraction();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = math.min(widget.courses.length, 3);
    if (count == 0) return const SizedBox.shrink();

    final t = ref.watch(trProvider);
    final mq = MediaQuery.of(context);
    final fontScale = mq.textScaler.scale(1);
    final reduced = Motion.reduced(context);

    if (reduced && _timer != null) {
      _timer?.cancel();
    }

    return Column(
      key: const Key('courses-recommend'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            t('courses.recommend.title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.black,
            ),
          ),
        ),
        SizedBox(
          height: fontScale > 1.2 ? 380 : 244,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                _onUserInteraction();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) {
                final course = widget.courses[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
                  child: Pressable(
                    key: Key('courses-recommend-${course.id}'),
                    semanticLabel: t('courses.recommend.label', {'title': course.title}),
                    onTap: () => widget.onOpen(course.id),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.forest.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.none,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Nền gradient
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _softColors[index % _softColors.length],
                                      AppColors.canvas,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Nội dung thẻ
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: fontScale > 1.2
                                ? _buildLargeContent(t, course, index)
                                : _buildNormalContent(t, course, index),
                          ),
                          // Ruy băng góc
                          _buildCornerRibbon(t, index),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Chấm phân trang
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Pressable(
                  key: Key('courses-recommend-dot-$i'),
                  semanticLabel: t('courses.pagination.page', {'page': i + 1}),
                  selected: _page == i,
                  onTap: () => _goTo(i),
                  child: Container(
                    width: _page == i ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _page == i ? AppColors.forest : AppColors.banner,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalContent(Translator t, Course course, int index) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.categoryName + (course.openClass != null ? ' · ${course.openClass!.deliveryMode.name}' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 23 / 20,
                      letterSpacing: -0.4,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    course.openClass != null
                        ? t('courses.meta.startsAndPrice', {
                            'date': Dates.dateOnly(course.openClass!.startDate),
                            'price': formatVnd(course.priceAmount),
                          })
                        : formatVnd(course.priceAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 18 / 12.5,
                      color: AppColors.black,
                    ),
                  ),
                  const Spacer(),
                  _buildViewButton(t, course),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 128,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CoverImage(
                url: course.imgUrl,
                label: course.title,
                hideLabel: true,
                fallback: CourseCover(index: index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeContent(Translator t, Course course, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CoverImage(
              url: course.imgUrl,
              label: course.title,
              hideLabel: true,
              fallback: CourseCover(index: index),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          course.categoryName + (course.openClass != null ? ' · ${course.openClass!.deliveryMode.name}' : ''),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          course.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 23 / 20,
            letterSpacing: -0.4,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          course.openClass != null
              ? t('courses.meta.startsAndPrice', {
                  'date': Dates.dateOnly(course.openClass!.startDate),
                  'price': formatVnd(course.priceAmount),
                })
              : formatVnd(course.priceAmount),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            height: 18 / 12.5,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        _buildViewButton(t, course),
      ],
    );
  }

  Widget _buildViewButton(Translator t, Course course) {
    return Pressable(
      key: Key('courses-recommend-view-${course.id}'),
      onTap: () => widget.onOpen(course.id),
      semanticLabel: t('home.actions.course', {'title': course.title}),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
          color: AppColors.canvas.withValues(alpha: 0.9),
        ),
        alignment: Alignment.center,
        child: Text(
          t('courses.recommend.view'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.forest,
          ),
        ),
      ),
    );
  }

  Widget _buildCornerRibbon(Translator t, int index) {
    return Positioned(
      top: -7,
      right: -7,
      width: 104,
      height: 104,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ClipRect(
            child: Stack(
              children: [
                // Góc gập trái
                const Positioned(
                  left: 6,
                  top: 0,
                  width: 7,
                  height: 7,
                  child: ColoredBox(color: AppColors.ribbonFold),
                ),
                // Góc gập phải/dưới
                const Positioned(
                  right: 0,
                  bottom: 6,
                  width: 7,
                  height: 7,
                  child: ColoredBox(color: AppColors.ribbonFold),
                ),
                // Dải ruy băng xoay 45 độ
                Positioned(
                  top: 26,
                  right: -32,
                  width: 156,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: CustomPaint(
                      painter: _RibbonBorderPainter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.ribbon,
                              AppColors.ribbonDeep,
                            ],
                          ),
                        ),
                        child: Text(
                          t('courses.recommend.badge'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.canvas.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 3.0;
    const dashSpace = 3.0;

    // Viền trên
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dashWidth, size.width), 0), paint);
      x += dashWidth + dashSpace;
    }

    // Viền dưới
    x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height), Offset(math.min(x + dashWidth, size.width), size.height), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
