import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import 'courses_models.dart';
import 'courses_providers.dart';

/// Thẻ khoá học - `components/common/CourseTile.tsx`.
/// TODO(UI): đối chiếu kích thước/bo góc/badge với CourseTile.tsx + Student Home.dc.html.
class CourseTile extends ConsumerWidget {
  const CourseTile({
    super.key,
    required this.course,
    required this.index,
    required this.onTap,
    this.loadOpenClass = true,
  });

  final Course course;
  final int index;
  final VoidCallback onTap;

  /// Home đã đọc metadata cả trường hợp không có lớp; không gửi request thứ hai.
  final bool loadOpenClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final region = RegionColors.of(context);
    // Ưu tiên openClass có sẵn (Home), không thì tự tải (Courses)
    final open = course.openClass ?? (loadOpenClass ? ref.watch(nextClassProvider(course.id)).value : null);
    final (cover, coverSoft) = AppColors.covers[index % AppColors.covers.length];

    return Pressable(
      onTap: onTap,
      semanticLabel: t('home.actions.course', {'title': course.title}),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CoverImage(
                url: course.imgUrl,
                label: course.title,
                fallback: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [coverSoft, cover])),
                  alignment: Alignment.center,
                  child: const MindyIcon(MindyIconName.book, size: 36, color: AppColors.forest),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.categoryName.toUpperCase(), style: AppText.eyebrow()),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: region.foreground),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    open == null
                        ? formatVnd(course.priceAmount)
                        : t('courses.meta.startsAndPrice', {
                            'date': Dates.dateOnly(open.startDate),
                            'price': formatVnd(course.priceAmount),
                          }),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: region.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
