import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/i18n.dart';
import '../states.dart';
import 'staff_theme.dart';
import 'staff_widgets.dart';
import 'sym.dart';

/// Trạng thái dữ liệu dùng đúng hệ Staff; lỗi một vùng không che cả màn.
class StaffDataState extends ConsumerWidget {
  const StaffDataState({super.key, required this.title, required this.description, this.error, this.onRetry});
  final String title, description;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final requestId = error == null ? null : requestIdOf(error!);
    return GlassCard(
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(error == null ? Sym.eventNote : Sym.error, color: StaffColors.teal600, size: 32),
            const SizedBox(height: 12),
            Text(title, style: StaffText.bodyStrong),
            const SizedBox(height: 6),
            Text(description, style: StaffText.caption),
            if (requestId != null) ...[
              const SizedBox(height: 8),
              SelectableText(t('common.requestId', {'id': requestId}), style: StaffText.small),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              StaffButton(label: t('common.retry'), onPressed: onRetry, outlined: true),
            ],
          ],
        ),
      ),
    );
  }
}
