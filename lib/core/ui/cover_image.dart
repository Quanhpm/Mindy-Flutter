import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'icon.dart';

/// Ảnh bìa khoá học có fallback khi thiếu/lỗi ảnh - `CoverImage.tsx`.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url, required this.label, this.hideLabel = false, this.fallback});

  final String? url;
  final String label;
  final bool hideLabel;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ?? _Placeholder(label: label, hideLabel: hideLabel);
    if (url == null || url!.isEmpty) return placeholder;
    return Semantics(
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
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.forest)),
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
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scroll) => PrimaryScrollController(controller: scroll, child: builder(ctx)),
      ),
    ),
  );
}
