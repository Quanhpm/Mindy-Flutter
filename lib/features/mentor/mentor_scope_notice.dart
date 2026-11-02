import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/ui/states.dart';
import '../../core/ui/staff/staff_data_state.dart';
import 'mentor_providers.dart';

/// Quyền lớp chưa xác định không được làm lộ tiện ích primaryOnly. Các tiện ích
/// lịch/dạy thay vẫn dùng được; lỗi quyền có một đường thử lại ngay trên màn.
class MentorScopeNotice extends ConsumerWidget {
  const MentorScopeNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(mentorSubstituteOnlyProvider);
    final t = ref.watch(trProvider);
    if (scope.isLoading) {
      return const Padding(padding: EdgeInsets.only(bottom: 16), child: Skeleton(height: 80));
    }
    if (scope.hasError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: StaffDataState(
          title: t('mentor.utilities.scopeError'),
          description: t(errorKey(scope.error!)),
          error: scope.error,
          onRetry: () => ref.invalidate(mentorSubstituteOnlyProvider),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
