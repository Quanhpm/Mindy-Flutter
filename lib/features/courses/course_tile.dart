import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/pressable.dart';
import 'courses_models.dart';
import 'courses_providers.dart';

/// Thẻ khoá học 3:4 với gradient tối và chữ trắng đè lên - `CourseTile.tsx`.
class CourseTile extends ConsumerWidget {
  const CourseTile({
    super.key,
    required this.course,
    required this.index,
    required this.onTap,
    this.prefix = 'home',
    this.loadOpenClass = true,
  });

  final Course course;
  final int index;
  final VoidCallback onTap;
  final String prefix;

  /// Home đã đọc metadata cả trường hợp không có lớp; không gửi request thứ hai.
  final bool loadOpenClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final mq = MediaQuery.of(context);
    final enlarged = mq.textScaler.scale(1) > 1.2;

    // Ưu tiên openClass có sẵn (Home), không thì tự tải (Courses)
    final open = course.openClass ?? (loadOpenClass ? ref.watch(nextClassProvider(course.id)).value : null);

    final cardKey = Key('$prefix-course-${course.id}');
    final arrowKey = Key('${prefix == 'home' ? 'home-course-open' : 'courses-open'}-${course.id}');

    final textContent = Padding(
      padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (open != null)
            Text(
              '${open.deliveryMode.name}${t('home.starts', {'date': Dates.dateOnly(open.startDate)})}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.sunshine,
              ),
            ),
          const SizedBox(height: 3),
          Text(
            course.title,
            maxLines: enlarged ? null : 3,
            overflow: enlarged ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 18.8 / 15,
              color: AppColors.canvas,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 36),
            child: Text(
              formatVnd(course.priceAmount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.canvas,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Pressable(
            key: cardKey,
            onTap: onTap,
            semanticLabel: t('home.actions.course', {'title': course.title}),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    CoverImage(
                      url: course.imgUrl,
                      label: course.title,
                      hideLabel: true,
                      aspectRatio: 3 / 4,
                      borderRadius: BorderRadius.zero,
                      fallback: CourseCover(index: index),
                    ),
                    // Gradient dọc forestDeep che ảnh
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.45, 1.0],
                              colors: [
                                AppColors.forestDeep.withValues(alpha: 0.0),
                                AppColors.forestDeep.withValues(alpha: 0.82),
                                AppColors.forestDeep.withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!enlarged)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: textContent,
                      ),
                  ],
                ),
                if (enlarged)
                  Container(
                    color: AppColors.forestDeep,
                    child: textContent,
                  ),
              ],
            ),
          ),
          // Nút mũi tên action ở góc dưới bên phải
          Positioned(
            bottom: 7,
            right: 7,
            child: Pressable(
              key: arrowKey,
              onTap: onTap,
              semanticLabel: t('home.actions.course', {'title': course.title}),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: MindyIcon(MindyIconName.arrow, size: 22, color: AppColors.action),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
