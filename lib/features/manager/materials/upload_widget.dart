import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/file_models.dart';
import '../../mentor/materials/file_picker_service.dart';
import '../../mentor/materials/upload_policy.dart';
import '../manager_widgets.dart';
import 'upload_controller.dart';

class ManagerUploadBlock extends ConsumerStatefulWidget {
  const ManagerUploadBlock({
    super.key,
    required this.uploadKey,
    required this.onUse,
    this.categories = const [UploadCategory.document, UploadCategory.image, UploadCategory.video],
  });
  final ManagerUploadKey uploadKey;
  final ValueChanged<BinaryFileSummary> onUse;
  final List<UploadCategory> categories;
  @override
  ConsumerState<ManagerUploadBlock> createState() => _UploadBlockState();
}

class _UploadBlockState extends ConsumerState<ManagerUploadBlock> {
  bool _picking = false;
  Object? _error;
  UploadCategory? _category;
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final selected = await ref.read(mentorFilePickerProvider).pick(_category ?? widget.categories.first);
      if (!mounted || selected == null) return;
      await ref.read(managerUploadProvider(widget.uploadKey).notifier).start(selected);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        state = ref.watch(managerUploadProvider(widget.uploadKey)),
        controller = ref.read(managerUploadProvider(widget.uploadKey).notifier);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.categories.length > 1)
            DropdownButton<UploadCategory>(
              value: _category ?? widget.categories.first,
              isExpanded: true,
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c, child: Text(t('manager.uploadCategory.${c.name}'))),
              ],
              onChanged: state.busy || _picking ? null : (c) => setState(() => _category = c),
            ),
          if (state.busy) ...[
            LinearProgressIndicator(value: state.progress > 0 ? state.progress : null),
            const SizedBox(height: 8),
            StaffButton(label: t('manager.cancelUpload'), outlined: true, onPressed: controller.cancel),
          ],
          if (state.checkRequired) ...[
            Text(t('manager.uploadCheck'), style: StaffText.caption),
            StaffButton(
              label: t('mentor.operations.readLatest'),
              loading: state.busy,
              onPressed: state.busy ? null : controller.check,
            ),
            TextButton(onPressed: state.busy ? null : controller.retryTransfer, child: Text(t('manager.retryUpload'))),
          ],
          if (!state.busy && !state.checkRequired)
            StaffButton(label: t('manager.chooseUpload'), loading: _picking, onPressed: _picking ? null : _pick),
          if (state.file != null) ...[
            Text(
              '${state.file!.name} · ${formatBytes(state.file!.size, t.locale.languageCode)}',
              style: StaffText.body,
            ),
            StaffButton(label: t('manager.useFile'), onPressed: () => widget.onUse(state.file!)),
          ],
          if (_error != null) managerFailure(t, _error!),
          if (state.error != null) managerFailure(t, state.error!),
        ],
      ),
    );
  }
}
