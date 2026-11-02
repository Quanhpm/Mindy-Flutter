import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/utils/format.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import '../schedule/schedule_providers.dart';
import 'courses_models.dart';
import 'courses_providers.dart';

/// Mở bottom sheet chi tiết khoá học (dùng ở Home và Courses).
Future<void> showCourseSheet(BuildContext context, String courseId) =>
    showAppSheet<void>(context, (_) => CourseSheet(courseId: courseId));

/// Bottom sheet chi tiết khoá học - port từ `CourseSheet.tsx` + `ShoppingSheets.tsx`.
class CourseSheet extends ConsumerStatefulWidget {
  const CourseSheet({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends ConsumerState<CourseSheet> {
  String? _draft;
  bool _touched = false;
  bool _expanded = false;
  bool _buying = false;
  String? _pendingClassId;
  String? _error;
  String? _toast;

  String? _selected(List<CourseClass> classes) {
    if (_touched) return _draft;
    final inCart = ref.read(cartProvider).value?.classIdOfCourse(widget.courseId);
    return inCart;
  }

  void _onPick(CourseClass c, String? currentSelected) {
    if (_pendingClassId != null || _buying || c.isFull) return;
    setState(() {
      _touched = true;
      _draft = currentSelected == c.id ? null : c.id;
      _error = null;
      _toast = null;
    });
  }

  Future<void> _addToCart(List<CourseClass> classes, {required bool buyNow}) async {
    final t = ref.read(trProvider);
    final selectedId = _selected(classes);
    final matches = classes.where((c) => c.id == selectedId && !c.isFull);
    if (matches.isEmpty || _pendingClassId != null || _buying) return;

    final target = matches.first;
    setState(() {
      _pendingClassId = target.id;
      _buying = buyNow;
      _error = null;
      _toast = null;
    });

    try {
      await ref.read(cartProvider.notifier).putClass(
            courseId: widget.courseId,
            classId: target.id,
          );
      if (!mounted) return;
      setState(() {
        _toast = t('courseSheet.added', {'name': target.name});
      });
      if (buyNow) {
        final nav = Navigator.of(context);
        nav.pop();
        await showCartSheet(nav.context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = t(cartErrorKey(e)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingClassId = null;
          _buying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    ref.watch(cartProvider); // Lắng nghe để cập nhật khi giỏ đổi
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final classesAsync = ref.watch(courseClassesProvider(widget.courseId));

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final fontScale = mq.textScaler.scale(1);

    final isLoading = courseAsync.isLoading || classesAsync.isLoading;
    final hasError = courseAsync.hasError || classesAsync.hasError;

    return RegionColors.courseDetail(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            controller: PrimaryScrollController.of(context),
            child: Column(
              key: const Key('course-sheet'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isLoading)
                  _buildLoading()
                else if (hasError)
                  _buildError(t)
                else
                  _buildContent(
                    t,
                    courseAsync.value!,
                    classesAsync.value ?? const [],
                    width,
                    fontScale,
                  ),
              ],
            ),
          ),
          if (_toast != null)
            Positioned(
              top: 12,
              left: 18,
              right: 18,
              child: Container(
                key: const Key('course-sheet-toast'),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _toast!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.canvas,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      key: Key('course-sheet-loading'),
      padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(radius: 18),
          ),
          SizedBox(height: 12),
          Skeleton(height: 24),
          SizedBox(height: 12),
          Skeleton(height: 72, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 72, radius: 16),
        ],
      ),
    );
  }

  Widget _buildError(Translator t) {
    return Padding(
      key: const Key('course-sheet-error'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: ScreenState(
        title: t('home.errorTitle'),
        description: t('errors.generic'),
        retryKey: const Key('course-sheet-retry'),
        onRetry: () {
          ref.invalidate(courseDetailProvider(widget.courseId));
          ref.invalidate(courseClassesProvider(widget.courseId));
        },
      ),
    );
  }

  Widget _buildContent(
    Translator t,
    Course course,
    List<CourseClass> classes,
    double width,
    double fontScale,
  ) {
    final heroHeight = (width * 5) / 8 + 22;
    final selectedId = _selected(classes);
    final canSubmit = classes.any((c) => c.id == selectedId && !c.isFull);
    final isBusy = _pendingClassId != null || _buying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero
        Container(
          key: const Key('course-sheet-hero'),
          width: width,
          height: heroHeight,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(color: AppColors.soft),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(
                url: course.imgUrl,
                label: course.title,
                hideLabel: true,
                fallback: const CourseCover(index: 0),
                borderRadius: BorderRadius.zero,
              ),
              // Gradient forestDeep
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.2, 0.7, 1.0],
                      colors: [
                        AppColors.forestDeep.withValues(alpha: 0.0),
                        AppColors.forestDeep.withValues(alpha: 0.65),
                        AppColors.forestDeep.withValues(alpha: 0.98),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${course.code} · ${course.categoryName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.sunshine,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.title,
                        key: const Key('course-sheet-title'),
                        maxLines: fontScale > 1.2 ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 27 / 22,
                          letterSpacing: -0.44,
                          color: AppColors.canvas,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body
        Container(
          key: const Key('course-sheet-body'),
          transform: Matrix4.translationValues(0, -22, 0),
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mô tả
              if (course.description != null && course.description!.isNotEmpty) ...[
                Text(
                  course.description!,
                  key: const Key('course-sheet-description'),
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 22 / 14,
                    color: AppColors.muted,
                  ),
                ),
                if (!_expanded && (course.description!.length > 160 || course.description!.contains('\n'))) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      key: const Key('course-sheet-more'),
                      onTap: () => setState(() => _expanded = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          t('courseSheet.more'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ],

              // Tiêu đề Lớp đang mở
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    t('courseSheet.openClasses'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  if (classes.isNotEmpty)
                    Text(
                      t('courseSheet.classCount', {'count': classes.length}),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Danh sách lớp
              Container(
                key: const Key('course-sheet-classes-card'),
                margin: const EdgeInsets.only(bottom: 18),
                child: classes.isEmpty
                    ? Text(
                        t('courseSheet.empty'),
                        key: const Key('course-sheet-empty'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      )
                    : Column(
                        key: const Key('course-sheet-classes-scroll'),
                        children: [
                          for (final c in classes) ...[
                            _buildClassItem(t, c, selectedId == c.id, isBusy, fontScale),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusRed,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Hàng giá & nút CTA
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatVnd(course.priceAmount),
                      key: const Key('course-sheet-price'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nút thêm giỏ
                  Pressable(
                    key: const Key('course-sheet-add-to-cart'),
                    semanticLabel: t('courseSheet.addToCart'),
                    onTap: (isBusy || !canSubmit) ? null : () => _addToCart(classes, buyNow: false),
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.forest),
                        color: AppColors.soft,
                      ),
                      child: Opacity(
                        opacity: (isBusy || !canSubmit) ? 0.6 : 1.0,
                        child: _pendingClassId != null && !_buying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.forest,
                                ),
                              )
                            : const MindyIcon(
                                MindyIconName.cart,
                                size: 24,
                                color: AppColors.forest,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nút mua ngay
                  MindyButton(
                    key: const Key('course-sheet-buy'),
                    label: t('courseSheet.buy'),
                    variant: ButtonVariant.action,
                    loading: _buying,
                    minHeight: 50,
                    radius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    expand: false,
                    onPressed: (isBusy || !canSubmit) ? null : () => _addToCart(classes, buyNow: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassItem(
    Translator t,
    CourseClass item,
    bool selected,
    bool pending,
    double fontScale,
  ) {
    final full = item.availableSeats == 0;
    final isPicking = _pendingClassId == item.id;

    // Lịch buổi học (nếu có)
    final times = ref.watch(classSessionsProvider(item.id)).value;
    final zone = ref.watch(learningTimeZoneProvider).value;
    String? schedule;
    if (times != null && times.isNotEmpty && zone != null) {
      final days = times.map((d) => Dates.inZone(d, zone).weekday).toSet().toList()..sort();
      final labels = t.list('schedule.days');
      final clocks = <String, int>{};
      for (final d in times) {
        final clock = Dates.time(d, zone);
        clocks[clock] = (clocks[clock] ?? 0) + 1;
      }
      final sorted = clocks.keys.toList()
        ..sort((a, b) => clocks[b]!.compareTo(clocks[a]!) != 0
            ? clocks[b]!.compareTo(clocks[a]!)
            : a.compareTo(b));
      schedule = '${days.map((day) => labels[day - 1]).join(' · ')}, ${sorted.first}';
    }

    return Container(
      key: Key('course-sheet-class-${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.mint : AppColors.line,
        ),
        color: selected ? AppColors.soft : AppColors.canvas,
      ),
      child: Opacity(
        opacity: full ? 0.55 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.line,
                  ),
                  child: Text(
                    item.deliveryMode.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (fontScale > 1.2) ...[
              _buildClassInfo(t, item, schedule, full),
              const SizedBox(height: 12),
              _buildPickButton(t, item, selected, full, pending, isPicking, double.infinity),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildClassInfo(t, item, schedule, full),
                  ),
                  const SizedBox(width: 12),
                  _buildPickButton(t, item, selected, full, pending, isPicking, 104),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfo(Translator t, CourseClass item, String? schedule, bool full) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${Dates.dateOnly(item.startDate)} – ${Dates.dateOnly(item.endDate)}${schedule != null ? ' · $schedule' : ''}',
          style: const TextStyle(
            fontSize: 12,
            height: 18 / 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${t('courseSheet.mentor', {'name': item.mentorName})} · '),
              TextSpan(
                text: full
                    ? t('courseSheet.full')
                    : t('courseSheet.seats', {'count': item.availableSeats}),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (full || item.availableSeats <= 5) ? AppColors.statusRed : AppColors.muted,
                ),
              ),
            ],
          ),
          key: Key('course-sheet-seats-${item.id}'),
          style: const TextStyle(
            fontSize: 12,
            height: 18 / 12,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildPickButton(
    Translator t,
    CourseClass item,
    bool selected,
    bool full,
    bool pending,
    bool isPicking,
    double width,
  ) {
    return Pressable(
      key: Key('course-sheet-pick-${item.id}'),
      onTap: (pending || full) ? null : () => _onPick(item, _selected([item])),
      semanticLabel: item.name,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 36),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: (selected || full) ? AppColors.line : AppColors.forest,
        ),
        child: isPicking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
              )
            : Text(
                t(full
                    ? 'courseSheet.full'
                    : selected
                        ? 'courseSheet.picked'
                        : 'courseSheet.pick'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: full
                      ? AppColors.muted
                      : selected
                          ? AppColors.forest
                          : AppColors.canvas,
                ),
              ),
      ),
    );
  }
}
