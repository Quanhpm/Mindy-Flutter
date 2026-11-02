import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../network/api_error.dart';
import '../theme/app_colors.dart';
import 'button.dart';
import 'icon.dart';

/// Map lỗi -> key dịch (giống `formFailure` bên RN).
String errorKey(Object error) {
  if (error is! ApiError) return 'errors.generic';
  if (error.status == 429) return 'errors.RATE_LIMIT_EXCEEDED';
  return switch (error.code) {
    'INVALID_CREDENTIALS' => 'errors.INVALID_CREDENTIALS',
    'MAIL_DELIVERY_UNAVAILABLE' => 'errors.MAIL_DELIVERY_UNAVAILABLE',
    'NETWORK_UNAVAILABLE' || 'NETWORK_ERROR' => 'errors.NETWORK_UNAVAILABLE',
    'RATE_LIMIT_EXCEEDED' => 'errors.RATE_LIMIT_EXCEEDED',
    _ => 'errors.generic',
  };
}

String? requestIdOf(Object error) => error is ApiError ? error.requestId : null;

/// Khối trạng thái lỗi/trống - `components/common/ScreenState.tsx`
class ScreenState extends ConsumerWidget {
  const ScreenState({super.key, required this.title, required this.description, this.onRetry, this.requestId});

  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String? requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MindyIcon(MindyIconName.book, size: 32),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forest)),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(description, style: const TextStyle(fontSize: 16, color: AppColors.muted)),
          ),
          if (requestId != null) ...[
            const SizedBox(height: 12),
            SelectableText(t('common.requestId', {'id': requestId}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            MindyButton(label: t('common.retry'), variant: ButtonVariant.outline, onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Khung xám nhấp nháy khi đang tải - `components/ui/Skeleton`
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 24, this.width, this.radius = 24});
  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final box = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(widget.radius)),
    );
    return Semantics(
      label: 'loading',
      child: reduced ? box : FadeTransition(opacity: Tween(begin: 0.5, end: 1.0).animate(_c), child: box),
    );
  }
}

/// Render `AsyncValue` của Riverpod theo 3 trạng thái loading / error / data.
///
///   AsyncView(value: ref.watch(homeCoursesProvider),
///             onRetry: () => ref.invalidate(homeCoursesProvider),
///             data: (courses) => ...)
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.errorTitleKey = 'errors.generic',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final String errorTitleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return value.when(
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const Skeleton(height: 120),
      error: (e, _) => ScreenState(
        title: t(errorTitleKey),
        description: t(errorKey(e)),
        requestId: requestIdOf(e),
        onRetry: onRetry,
      ),
    );
  }
}
