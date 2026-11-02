import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_controller.dart';

/// Đổi phiên phải đóng cả sheet và dialog con đang mang dữ liệu user cũ.
class SessionSheetGuard extends ConsumerWidget {
  const SessionSheetGuard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ModalRoute.of(context);
    ref.listen(sessionEpochProvider, (before, after) {
      if (before == null || before == after) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || route == null || !route.isActive) return;
        final navigator = Navigator.of(context);
        navigator.popUntil((current) => current == route);
        if (route.isCurrent) navigator.pop();
      });
    });
    return child;
  }
}

/// Form riêng tư tạo State mới ngay khi actor đổi, trước khi frame mới hiển thị.
class SessionBoundView extends ConsumerWidget {
  const SessionBoundView({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      KeyedSubtree(key: ValueKey(ref.watch(sessionEpochProvider)), child: child);
}
