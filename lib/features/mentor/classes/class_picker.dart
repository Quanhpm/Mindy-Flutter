import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import 'classes_models.dart';
import 'classes_providers.dart';

/// Chỉ chọn trong danh sách lớp chính; provider của từng trang vẫn kiểm tra scope.
class MentorClassPicker extends ConsumerWidget {
  const MentorClassPicker({super.key, required this.value, required this.selectedId, required this.onSelected});
  final AsyncValue<List<MentorClass>> value;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => const Skeleton(height: 52),
      error: (error, _) => StaffDataState(
        title: t('mentor.classes.loadError'),
        description: t(errorKey(error)),
        error: error,
        onRetry: () => ref.invalidate(mentorPrimaryClassesProvider),
      ),
      data: (classes) => classes.isEmpty
          ? StaffDataState(title: t('mentor.classes.empty'), description: t('mentor.classes.emptyDescription'))
          : FilterChipsBar<String>(
              items: [for (final item in classes) (item.id, item.code)],
              selected: selectedId ?? '',
              onSelected: onSelected,
            ),
    );
  }
}

StatusTone mentorClassTone(MentorClassStatus status) => switch (status) {
  MentorClassStatus.IN_PROGRESS => StatusTone.green,
  MentorClassStatus.OPEN || MentorClassStatus.DRAFT => StatusTone.teal,
  MentorClassStatus.COMPLETED => StatusTone.gray,
  MentorClassStatus.CANCELLED => StatusTone.red,
};
