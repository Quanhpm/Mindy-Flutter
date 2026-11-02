import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import 'material_actions.dart';
import 'materials_models.dart';

String materialErrorKey(Object error) {
  if (error is! ApiError) {
    return errorKey(error);
  }
  return switch (error.code) {
    'MATERIAL_REVIEW_CONFLICT' => 'mentor.materials.errors.conflict',
    'MATERIAL_RESULT_UNCONFIRMED' => 'mentor.materials.errors.unconfirmed',
    'MATERIAL_NEEDS_EDIT' => 'mentor.materials.errors.needsEdit',
    'MATERIAL_CLASS_CANCELLED' => 'mentor.materials.errors.classCancelled',
    'MATERIAL_NOT_FOUND' => 'mentor.materials.errors.notFound',
    'MATERIAL_SCOPE_MISMATCH' => 'mentor.materials.errors.scope',
    'MATERIAL_INPUT_INVALID' || 'UPLOAD_METADATA_INVALID' => 'mentor.materials.errors.metadata',
    'UPLOAD_FILE_INVALID' || 'UPLOAD_FILE_UNSUPPORTED' || 'UPLOAD_FILE_UNAVAILABLE' => 'mentor.materials.errors.file',
    'UPLOAD_FILE_TOO_LARGE' => 'mentor.materials.errors.size',
    'UPLOAD_URL_EXPIRED' || 'UPLOAD_EXPIRED' || 'MATERIAL_LINK_EXPIRED' => 'mentor.materials.errors.expired',
    'UPLOAD_PROCESSING_TIMEOUT' => 'mentor.materials.errors.processing',
    'UPLOAD_TRANSFER_FAILED' => 'mentor.materials.errors.transfer',
    'UPLOAD_DRAFT_UNCONFIRMED' => 'mentor.materials.errors.draftUnconfirmed',
    'UPLOAD_CANCELLED' => 'mentor.materials.errors.cancelled',
    'UPLOAD_FAILED' || 'FILE_BINARY_INVALID' || 'FILE_SIZE_MISMATCH' => 'mentor.materials.errors.failed',
    'FILE_RETRY_EXHAUSTED' => 'mentor.materials.errors.processingFailed',
    'FILE_STORAGE_DISABLED' || 'FILE_STORAGE_UNAVAILABLE' => 'mentor.materials.errors.storage',
    'FILE_UPLOAD_QUOTA_EXCEEDED' => 'mentor.materials.errors.quota',
    _ => errorKey(error),
  };
}

StatusTone materialTone(MaterialReviewStatus status) => switch (status) {
  MaterialReviewStatus.DRAFT => StatusTone.gray,
  MaterialReviewStatus.PENDING_REVIEW => StatusTone.amber,
  MaterialReviewStatus.APPROVED => StatusTone.green,
  MaterialReviewStatus.REJECTED => StatusTone.red,
};
IconData materialIcon(MentorMaterial material) => switch (material.file?.kind) {
  FileKind.IMAGE => Sym.image,
  FileKind.VIDEO => Sym.movie,
  _ => material.type == MaterialContentType.ARTICLE ? Sym.menuBook : Sym.description,
};

class MaterialCard extends ConsumerWidget {
  const MaterialCard({
    super.key,
    required this.material,
    required this.unitTitle,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
    this.onSubmit,
  });
  final MentorMaterial material;
  final String unitTitle;
  final VoidCallback onOpen;
  final VoidCallback? onEdit, onDelete, onSubmit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(materialIcon(material), color: StaffColors.teal700, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title, style: StaffText.bodyStrong),
                    const SizedBox(height: 4),
                    Text(
                      '$unitTitle${material.file == null ? '' : ' · ${formatBytes(material.file!.size, t.locale.languageCode)}'}',
                      style: StaffText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                t('mentor.materials.status.${material.reviewStatus.name}'),
                tone: materialTone(material.reviewStatus),
              ),
              if (material.reviewStatus == MaterialReviewStatus.APPROVED)
                StatusChip(
                  t(material.published ? 'mentor.materials.published' : 'mentor.materials.awaitingPublication'),
                  tone: StatusTone.gray,
                ),
            ],
          ),
          if (material.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Text(
              t('mentor.materials.reason', {'reason': material.rejectionReason!}),
              style: StaffText.caption.copyWith(color: StaffColors.redFg),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onOpen, child: Text(t('mentor.materials.view'))),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  child: Text(
                    t(
                      material.reviewStatus == MaterialReviewStatus.REJECTED
                          ? 'mentor.materials.editToResubmit'
                          : 'mentor.materials.edit',
                    ),
                  ),
                ),
              if (onDelete != null) TextButton(onPressed: onDelete, child: Text(t('mentor.materials.delete'))),
            ],
          ),
          if (onSubmit != null) StaffButton(label: t('mentor.materials.submit'), onPressed: onSubmit),
        ],
      ),
    );
  }
}

class MaterialActionNotice extends ConsumerWidget {
  const MaterialActionNotice({super.key, required this.classId});
  final String classId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), value = ref.watch(materialActionsProvider(classId));
    if (value.busy) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          t('mentor.materials.sending', {'count': value.changed, 'total': value.total}),
          style: StaffText.caption,
        ),
      );
    }
    if (value.error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StaffDataState(
        title: t('mentor.materials.actionError'),
        description:
            '${t(materialErrorKey(value.error!))}${value.total > 1 ? '\n${t('mentor.materials.partial', {'count': value.changed, 'total': value.total})}' : ''}',
        error: value.error,
        retryLabel: t('mentor.materials.checkResult'),
        onRetry: value.checkRequired || value.reloadOnly
            ? () => ref.read(materialActionsProvider(classId).notifier).check()
            : null,
      ),
    );
  }
}
