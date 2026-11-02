import 'dart:math' as math;
import 'session_sheet_guard.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'icon.dart';

/// Bìa khoá học hoạ tiết sọc nghiêng 45° - `CourseCover.tsx`.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, this.index = 0});
  final int index;

  @override
  Widget build(BuildContext context) {
    final (stripe, background) = AppColors.covers[index % AppColors.covers.length];
    return CustomPaint(
      size: Size.infinite,
      painter: _CourseCoverPainter(stripe: stripe, background: background),
    );
  }
}

class _CourseCoverPainter extends CustomPainter {
  const _CourseCoverPainter({required this.stripe, required this.background});
  final Color stripe;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.rotate(math.pi / 4);
    final paint = Paint()..color = stripe;
    final maxD = size.width + size.height * 2;
    for (double x = -size.height * 2; x < maxD; x += 18) {
      canvas.drawRect(Rect.fromLTWH(x, -maxD, 9, maxD * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CourseCoverPainter old) =>
      old.stripe != stripe || old.background != background;
}

/// Ảnh bìa khoá học có fallback khi thiếu/lỗi ảnh - `CoverImage.tsx`.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.label,
    this.hideLabel = false,
    this.fallback,
    this.aspectRatio = 3 / 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final String? url;
  final String label;
  final bool hideLabel;
  final Widget? fallback;
  final double? aspectRatio;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ?? _Placeholder(label: label, hideLabel: hideLabel);
    Widget image = placeholder;
    if (url != null && url!.isNotEmpty) {
      image = Semantics(
        image: true,
        label: label,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }

    Widget content = image;
    if (aspectRatio != null) {
      content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    }
    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label, required this.hideLabel});
  final String label;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: Container(
      color: AppColors.banner,
      padding: const EdgeInsets.all(12),
      alignment: hideLabel ? Alignment.topLeft : Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MindyIcon(MindyIconName.image, size: 32),
          if (!hideLabel) ...[
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.forest),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Mở bottom sheet chuẩn của app (bo góc 28, kéo để đóng, né bàn phím).
/// Thay `components/common/AppSheet.tsx` (@gorhom/bottom-sheet).
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder, {double initialSize = 0.9}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: AppColors.forestDeep.withValues(alpha: 0.45),
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                key: const Key('app-sheet-handle'),
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryScrollController(
                  controller: scroll,
                  child: SessionSheetGuard(child: SessionBoundView(child: builder(ctx))),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
