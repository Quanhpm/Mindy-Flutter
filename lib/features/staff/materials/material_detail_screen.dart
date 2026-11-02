import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import 'materials_models.dart';
import 'materials_query.dart';
import 'materials_screens.dart';
import 'materials_service.dart';
import 'materials_widgets.dart';

class StaffMaterialDetailScreen extends ConsumerStatefulWidget {
  const StaffMaterialDetailScreen({
    super.key,
    required this.id,
    this.classId,
    this.manager = false,
  });
  final String id;
  final String? classId;
  final bool manager;
  @override
  ConsumerState<StaffMaterialDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<StaffMaterialDetailScreen> {
  String? _dialog;
  int _dialogRevision = 0;
  bool _busy = false;
  ({String action, int revision, String reason})? _command;
  MaterialFailure? _error;
  final _reason = TextEditingController();
  MaterialDetailRequest get _request =>
      (manager: widget.manager, classId: widget.classId, id: widget.id);
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(
    ({String action, int revision, String reason}) intent,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _dialog = null;
      _error = null;
    });
    final t = ref.read(trProvider);
    try {
      await ref
          .read(staffMaterialServiceProvider)
          .command(
            widget.manager,
            widget.classId,
            widget.id,
            intent.action,
            intent.revision,
            reason: intent.reason,
          );
      if (!mounted) return;
      setState(() {
        _command = null;
        _reason.clear();
      });
      ref.read(materialRevisionProvider.notifier).bump();
      ref.read(mdyToastProvider.notifier).show(t(mat('done')));
    } catch (e) {
      if (!mounted) return;
      final error = MaterialFailure.from(e);
      setState(() {
        _error = error;
        _command = error.kind == 'uncertain' ? intent : null;
      });
      if (['conflict', 'denied', 'notFound'].contains(error.kind)) {
        ref.invalidate(materialDetailProvider(_request));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(StaffMaterial material) async {
    if (_busy || widget.classId == null) return;
    setState(() => _busy = true);
    try {
      final contextData = await ref.read(
        materialContextProvider(widget.classId!).future,
      );
      if (!mounted) return;
      final unit = contextData.units
          .where((u) => u.courseUnitId == material.unitId)
          .firstOrNull;
      if (unit == null) throw const MaterialFailure('notFound');
      context.push(
        StaffMaterialRoutes.editor(widget.classId!, unit, id: material.id),
      );
    } catch (e) {
      if (mounted) setState(() => _error = MaterialFailure.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        c = context.mdy,
        lang = ref.watch(localeProvider).languageCode;
    final q = ref.watch(materialDetailProvider(_request));
    final m = q.hasError ? null : q.value;
    final offline = ref.watch(staffOfflineProvider),
        locked = _busy || _command != null || offline;
    final canEdit = !widget.manager && m?.canEdit == true,
        submit = canEdit && m?.status == ReviewStatus.DRAFT,
        review = widget.manager && m?.status == ReviewStatus.PENDING_REVIEW;
    final prefix = widget.manager ? 'review-detail' : 'material-detail';
    void open(String action) {
      if (m == null) return;
      setState(() {
        _dialog = action;
        _dialogRevision = m.revision;
      });
    }

    void preview([String? fileId]) {
      if (m != null) {
        context.push(
          StaffMaterialRoutes.preview(
            widget.manager,
            m.id,
            m.revision,
            classId: widget.classId,
            fileId: fileId,
            title: m.title,
          ),
        );
      }
    }

    if (_dialog != null && m != null && _dialogRevision != m.revision) {
      _dialog = null;
      _error = const MaterialFailure('conflict');
    }
    Widget info(String key, String label, String value) => Row(
      key: Key('$prefix-$key'),
      spacing: MdySpace.s16,
      children: [
        Text(label, style: MdyType.size(13).copyWith(color: c.secondary)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink),
          ),
        ),
      ],
    );
    return AttendancePage(
      prefix: prefix,
      title: t(mat(widget.manager ? 'review' : 'detailTitle')),
      onBack: () => staffBack(context, manager: widget.manager),
      busy: _busy,
      uncertain: _command != null,
      footer: canEdit || review
          ? [
              if (submit)
                MdyButton(
                  key: const Key('material-detail-submit'),
                  icon: MdyIcons.send,
                  label: t(mat('submit')),
                  disabled: locked,
                  onPressed: () => open('submit'),
                ),
              if (canEdit)
                MdyButton(
                  key: const Key('material-detail-edit'),
                  icon: MdyIcons.edit,
                  variant: submit
                      ? MdyButtonVariant.secondary
                      : MdyButtonVariant.primary,
                  label: t(mat(submit ? 'edit' : 'editResubmit')),
                  disabled: locked,
                  onPressed: () => _edit(m!),
                ),
              if (review) ...[
                MdyButton(
                  key: const Key('review-detail-approve'),
                  icon: MdyIcons.taskAlt,
                  label: t(mat('approve')),
                  disabled: locked,
                  onPressed: () => open('approve'),
                ),
                MdyButton(
                  key: const Key('review-detail-reject'),
                  icon: MdyIcons.close,
                  variant: MdyButtonVariant.danger,
                  label: t(mat('reject')),
                  disabled: locked,
                  onPressed: () => open('reject'),
                ),
              ],
            ]
          : null,
      overlays: [
        if (_dialog case final dialog?)
          MdyInlineDialog(
            key: Key('$dialog-dialog'),
            title: '${t(mat(dialog))} · ${t(mat('revision'))} ${m?.revision}',
            icon: dialog == 'submit'
                ? MdyIcons.send
                : dialog == 'approve'
                ? MdyIcons.taskAlt
                : MdyIcons.warning,
            onClose: () => setState(() => _dialog = null),
            children: [
              MdyText(t(mat(dialog == 'submit' ? 'submitBody' : 'impact'))),
              if (dialog == 'reject')
                AttendanceField(
                  id: 'reject-reason',
                  label: t(mat('reason')),
                  controller: _reason,
                  max: 2000,
                  onChanged: (_) => setState(() {}),
                ),
              MdyButton(
                key: Key('$dialog-confirm'),
                label: t(mat('confirm')),
                disabled:
                    offline ||
                    (dialog == 'reject' &&
                        (_reason.text.trim().isEmpty ||
                            _reason.text.trim().runes.length > 2000)),
                onPressed: () => _run((
                  action: dialog,
                  revision: _dialogRevision,
                  reason: _reason.text,
                )),
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(mat('later')),
                onPressed: () => setState(() => _dialog = null),
              ),
            ],
          ),
      ],
      children: [
        MaterialRead(
          hasData: m != null,
          busy: q.isLoading,
          error: q.error == null ? null : MaterialFailure.from(q.error!),
          retry: () => ref.invalidate(materialDetailProvider(_request)),
          children: [
            if (m != null) ...[
              if (m.status == ReviewStatus.REJECTED &&
                  m.rejectionReason != null)
                MdyAlert(
                  '${t(mat('REJECTED'))}: ${m.rejectionReason}${m.reviewedAt == null ? '' : '\n${t(mat('rejectedAt'))} ${materialInstant(m.reviewedAt!, lang)}'}',
                  key: Key('$prefix-rejected'),
                ),
              if (widget.manager)
                MdyAlert(
                  t(mat('impact')),
                  warning: true,
                  key: const Key('review-detail-impact'),
                ),
              MdyCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(MdySpace.s16),
                gap: MdySpace.s12,
                children: [
                  Row(
                    spacing: MdySpace.s12,
                    children: [
                      MaterialTile(item: m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: MdySpace.s6,
                          children: [
                            Text(
                              m.title,
                              style: MdyType.size(
                                16,
                                MdyType.w600,
                              ).copyWith(color: c.ink),
                            ),
                            MaterialStatusChip(
                              key: Key('$prefix-status'),
                              item: m,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  info('kind', t(mat('kindLabel')), t(mat(m.type.name))),
                  if (m.file case final f?) ...[
                    info('file', t(mat('fileLabel')), f.name),
                    info(
                      'size',
                      t(mat('sizeLabel')),
                      materialSize(f.size, lang),
                    ),
                  ],
                  info('revision', t(mat('revision')), '${m.revision}'),
                  info(
                    'updated',
                    t(mat('updated')),
                    materialInstant(m.updatedAt, lang),
                  ),
                  if (m.availableAt case final at?)
                    info(
                      'available',
                      t(mat('availableFrom')),
                      materialInstant(at, lang),
                    ),
                  if (m.description case final description?)
                    MdyText(description),
                  if (m.file != null || m.type == StaffMaterialType.ARTICLE)
                    MdyButton(
                      key: Key('$prefix-view'),
                      variant: MdyButtonVariant.secondary,
                      icon: MdyIcons.visibility,
                      label: t(mat('view')),
                      disabled: offline || _busy,
                      onPressed: () => preview(m.file?.id),
                    )
                  else
                    MdyText(
                      t(mat('fileMissing')),
                      key: Key('$prefix-file-missing'),
                    ),
                ],
              ),
              if (m.attachments.isNotEmpty) MdyText(t(mat('attachments'))),
              for (final f in m.attachments)
                MdyButton(
                  key: Key('$prefix-attachment-${f.id}'),
                  variant: MdyButtonVariant.secondary,
                  icon: MdyIcons.attachFile,
                  label: f.name,
                  onPressed: () => preview(f.id),
                ),
            ],
          ],
        ),
        if (offline)
          MdyAlert(
            t(mat('offline')),
            warning: true,
            key: const Key('material-warning'),
          ),
        MaterialProblem(error: _error, prefix: prefix),
        if (_command case final command?)
          if (!offline)
            MdyButton(
              key: Key('$prefix-resend'),
              disabled: _busy,
              label: t(mat('resend')),
              onPressed: () => _run(command),
            ),
      ],
    );
  }
}
