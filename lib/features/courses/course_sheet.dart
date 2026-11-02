import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_sheet.dart';
import 'courses_models.dart';
import 'courses_providers.dart';

/// Mở sheet chi tiết khoá học (dùng ở Home và Courses).
Future<void> showCourseSheet(BuildContext context, String courseId) =>
    showAppSheet<void>(context, (_) => CourseSheet(courseId: courseId));

/// `courses/components/CourseSheet.tsx` + `hooks/useCourseSelection.ts`.
///
/// - Chọn/bỏ chọn lớp chỉ đổi "draft", CHƯA gọi API giỏ.
/// - "Thêm vào giỏ"/"Mua ngay": thêm lớp mới thành công rồi mới xoá lớp cũ cùng khoá.
/// TODO(UI): port bố cục chi tiết (ảnh hero, mô tả "Xem thêm", tóm tắt lịch lớp).
class CourseSheet extends ConsumerStatefulWidget {
  const CourseSheet({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends ConsumerState<CourseSheet> {
  /// null = chưa đụng tới -> dùng lớp đang có trong giỏ
  String? _draft;
  bool _touched = false;
  bool _busy = false, _buying = false;
  String? _error, _toast;

  String? _selected(List<CourseClass> classes) {
    if (_touched) return _draft;
    return ref.read(cartProvider).value?.classIdOfCourse(widget.courseId);
  }

  void _pick(CourseClass c, String? selected) {
    if (_busy || c.isFull) return;
    setState(() {
      _touched = true;
      _draft = selected == c.id ? null : c.id; // bấm lại = bỏ chọn
      _error = null;
      _toast = null;
    });
  }

  Future<void> _run(List<CourseClass> classes, {required bool open}) async {
    final t = ref.read(trProvider);
    final id = _selected(classes);
    final matches = classes.where((c) => c.id == id && !c.isFull);
    if (_busy || matches.isEmpty) return;
    final cls = matches.first;
    setState(() {
      _busy = true;
      _buying = open;
      _error = null;
      _toast = null;
    });
    try {
      await ref.read(cartProvider.notifier).putClass(courseId: widget.courseId, classId: cls.id);
      if (!mounted) return;
      setState(() => _toast = t('courseSheet.added', {'name': cls.name}));
      if (open) {
        // Đóng sheet khoá học rồi mở giỏ bằng context của Navigator (còn sống)
        final nav = Navigator.of(context);
        nav.pop();
        await showCartSheet(nav.context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = t(cartErrorKey(e)));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _buying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    ref.watch(cartProvider); // rebuild khi giỏ đổi
    final course = ref.watch(courseDetailProvider(widget.courseId));
    final classes = ref.watch(courseClassesProvider(widget.courseId));

    return RegionColors.courseDetail(
      child: ListView(
        controller: PrimaryScrollController.of(context),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          AsyncView(
            value: course,
            onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
            data: (c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(aspectRatio: 16 / 9, child: CoverImage(url: c.imgUrl, label: c.title)),
                ),
                const SizedBox(height: 16),
                Text(c.title, style: AppText.title(AppColors.black)),
                const SizedBox(height: 4),
                Text(formatVnd(c.priceAmount), style: AppText.label(AppColors.black)),
                if (c.description != null) ...[
                  const SizedBox(height: 12),
                  Text(c.description!, style: AppText.body(AppColors.black)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t('courseSheet.openClasses'), style: AppText.title(AppColors.black)),
          const SizedBox(height: 12),
          AsyncView(
            value: classes,
            onRetry: () => ref.invalidate(courseClassesProvider(widget.courseId)),
            data: (list) {
              if (list.isEmpty) return Text(t('courseSheet.empty'));
              final selected = _selected(list);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in list) _classRow(t, c, selected),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: AppColors.headsup, fontWeight: FontWeight.w700)),
                  ),
                  if (_toast != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_toast!, style: const TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 16),
                  MindyButton(
                    label: t('courseSheet.addToCart'),
                    variant: ButtonVariant.outline,
                    loading: _busy && !_buying,
                    onPressed: selected == null || _busy ? null : () => _run(list, open: false),
                  ),
                  const SizedBox(height: 12),
                  MindyButton(
                    label: t('courseSheet.buy'),
                    loading: _buying,
                    onPressed: selected == null || _busy ? null : () => _run(list, open: true),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _classRow(Translator t, CourseClass c, String? selected) {
    final picked = selected == c.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: c.isFull ? null : () => _pick(c, selected),
        selected: picked,
        semanticLabel: c.name,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: picked ? AppColors.soft : AppColors.canvas,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: picked ? AppColors.mint : AppColors.line, width: picked ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: AppText.label(AppColors.black)),
                    const SizedBox(height: 2),
                    Text(
                      '${t('home.delivery.${c.deliveryMode.name}')} · '
                      '${Dates.dateOnly(c.startDate)} – ${Dates.dateOnly(c.endDate)} · '
                      '${t('courseSheet.mentor', {'name': c.mentorName})}',
                      style: AppText.caption(AppColors.inkGray),
                    ),
                  ],
                ),
              ),
              Text(
                c.isFull
                    ? t('courseSheet.full')
                    : picked
                        ? t('courseSheet.picked')
                        : t('courseSheet.seats', {'count': c.availableSeats}),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: c.isFull ? AppColors.statusRed : AppColors.mint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
