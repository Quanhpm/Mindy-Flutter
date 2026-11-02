import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/pressable.dart';
import 'courses_models.dart';

/// Sheet bộ lọc hình thức học - `FilterSheet.tsx`.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({
    super.key,
    this.deliveryMode,
    this.total,
    this.onPreview,
    required this.onApply,
    required this.onClose,
  });

  final DeliveryMode? deliveryMode;
  final int? total;
  final void Function(DeliveryMode? mode)? onPreview;
  final void Function(DeliveryMode? mode) onApply;
  final VoidCallback onClose;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late DeliveryMode? _mode = widget.deliveryMode;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        key: const Key('courses-filter-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t('courses.filter.title'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('courses.filter.mode'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeOption(t, 'all', null),
              _buildModeOption(t, 'ONLINE', DeliveryMode.ONLINE),
              _buildModeOption(t, 'OFFLINE', DeliveryMode.OFFLINE),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              MindyButton(
                key: const Key('courses-filter-reset'),
                variant: ButtonVariant.outline,
                label: t('courses.filter.reset'),
                expand: false,
                minHeight: 52,
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                onPressed: () {
                  setState(() => _mode = null);
                  widget.onPreview?.call(null);
                  widget.onApply(null);
                  widget.onClose();
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MindyButton(
                  key: const Key('courses-filter-apply'),
                  variant: ButtonVariant.solid,
                  label: widget.total == null
                      ? t('courses.recommend.view')
                      : t('courses.filter.apply', {'count': widget.total!}),
                  minHeight: 52,
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    widget.onApply(_mode);
                    widget.onClose();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(Translator t, String id, DeliveryMode? value) {
    final selected = _mode == value;
    return Pressable(
      key: Key('courses-filter-mode-$id'),
      selected: selected,
      semanticLabel: t('courses.filter.$id'),
      onTap: () {
        setState(() => _mode = value);
        widget.onPreview?.call(value);
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.forest : AppColors.soft,
        ),
        child: Text(
          t('courses.filter.$id'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.canvas : AppColors.forest,
          ),
        ),
      ),
    );
  }
}
