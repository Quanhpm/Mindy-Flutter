import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/network/api_error.dart';
import '../../../core/utils/await_provider.dart';
import '../classes/classes_providers.dart';
import '../../../core/ui/staff/staff_input.dart';
import '../../../core/ui/staff/staff_text_area.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/states.dart';
import 'material_actions.dart';
import 'material_widgets.dart';
import 'materials_models.dart';
import 'materials_providers.dart';

Future<void> showMaterialEditor(BuildContext context, WidgetRef ref, String classId, MentorMaterial material) =>
    showStaffSheet<void>(
      context,
      title: ref.read(trProvider)('mentor.materials.edit'),
      builder: (_) => MaterialEditContent(classId: classId, material: material),
    );

class MaterialEditContent extends ConsumerStatefulWidget {
  const MaterialEditContent({super.key, required this.classId, required this.material});
  final String classId;
  final MentorMaterial material;
  @override
  ConsumerState<MaterialEditContent> createState() => _MaterialEditContentState();
}

class _MaterialEditContentState extends ConsumerState<MaterialEditContent> {
  late MentorMaterial _material = widget.material;
  MentorMaterial? _latest;
  bool _needsReview = false, _loadingLatest = false;
  Object? _latestError;
  late final _title = TextEditingController(text: widget.material.title),
      _description = TextEditingController(text: widget.material.description ?? '');
  bool _allowPop = false, _closing = false, _confirming = false;
  bool get dirty => _title.text != _material.title || _description.text != (_material.description ?? '');
  Future<void> _loadLatest() async {
    final epoch = ref.read(sessionEpochProvider), query = (classId: widget.classId, materialId: _material.id);
    setState(() {
      _loadingLatest = true;
      _latestError = null;
    });
    try {
      ref.invalidate(mentorMaterialDetailProvider(query));
      final detail = await awaitWidgetProvider(ref, mentorMaterialDetailProvider(query).future);
      if (!mounted || ref.read(sessionEpochProvider) != epoch) {
        return;
      }
      setState(() => _latest = detail.material);
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _latestError = error);
      }
    } finally {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _loadingLatest = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _description.addListener(_changed);
  }

  void _changed() {
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) {
      return;
    }
    _closing = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _leave() async {
    if (_confirming || ref.read(materialActionsProvider(widget.classId)).busy) {
      return;
    }
    _confirming = true;
    final t = ref.read(trProvider);
    final leave = await showStaffSheet<bool>(
      context,
      title: t('mentor.materials.discardTitle'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('mentor.materials.discardDescription'), style: StaffText.body),
          const SizedBox(height: 16),
          StaffButton(label: t('mentor.materials.keepEditing'), onPressed: () => Navigator.of(ctx).pop(false)),
          const SizedBox(height: 8),
          StaffButton(
            label: t('mentor.materials.discard'),
            outlined: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    _confirming = false;
    if (leave == true) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), provider = materialActionsProvider(widget.classId), action = ref.watch(provider);
    final workspace = ref.watch(mentorPrimaryWorkspaceProvider(widget.classId));
    final writable =
        !workspace.isLoading &&
        !workspace.hasError &&
        workspace.value?.readonly == false &&
        workspace.value?.authorMaterials == true;
    final actor = ref.watch(sessionProvider).user;
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final route = ModalRoute.of(context);
          if (route?.isActive == true) {
            Navigator.of(context).popUntil((r) => r == route);
            _close();
          }
        });
      }
    });
    ref.listen(provider, (before, after) {
      final error = after.error;
      if (error is ApiError && error.status == 409 && !after.locked) {
        setState(() {
          _needsReview = true;
          _latest = null;
        });
      }
      if (before?.busy == true && !after.locked && after.error == null && after.changed == 1 && after.total == 1) {
        _close();
      }
    });
    return PopScope(
      canPop: _allowPop || (!dirty && !action.busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (workspace.isLoading)
            const Skeleton(height: 24)
          else if (workspace.hasError)
            StaffDataState(
              title: t('mentor.classes.loadError'),
              description: t(materialErrorKey(workspace.error!)),
              error: workspace.error,
              onRetry: () => ref.invalidate(mentorPrimaryWorkspaceProvider(widget.classId)),
            )
          else if (!writable || !_material.ownEditable(actor?.id ?? '', widget.classId))
            Text(t('mentor.classes.readonly'), style: StaffText.caption),
          MaterialActionNotice(classId: widget.classId),
          if (_needsReview) ...[
            Text(t('mentor.materials.reviewDraftNote'), style: StaffText.caption),
            const SizedBox(height: 12),
            if (_latestError != null) Text(t(materialErrorKey(_latestError!)), style: StaffText.caption),
            StaffButton(
              label: t('mentor.materials.loadLatest'),
              loading: _loadingLatest,
              onPressed: _loadingLatest ? null : _loadLatest,
              outlined: true,
            ),
            if (_latest != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('mentor.materials.latestRevision', {'revision': _latest!.revision}),
                      style: StaffText.bodyStrong,
                    ),
                    const SizedBox(height: 6),
                    Text(_latest!.title, style: StaffText.body),
                    if (_latest!.description != null) Text(_latest!.description!, style: StaffText.caption),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (writable && _latest!.ownEditable(actor?.id ?? '', widget.classId))
                StaffButton(
                  label: t('mentor.materials.reviewed'),
                  onPressed: () {
                    ref.read(provider.notifier).clearIssue();
                    setState(() {
                      _material = _latest!;
                      _latest = null;
                      _needsReview = false;
                    });
                  },
                )
              else
                Text(t('mentor.classes.readonly'), style: StaffText.caption),
            ],
            const SizedBox(height: 16),
          ],
          if (widget.material.reviewStatus == MaterialReviewStatus.REJECTED) ...[
            Text(t('mentor.materials.rejectedEditNote'), style: StaffText.caption),
            const SizedBox(height: 12),
          ],
          StaffInput(label: t('mentor.materials.titleLabel'), controller: _title, enabled: !action.locked),
          StaffTextArea(label: t('mentor.materials.description'), controller: _description, enabled: !action.locked),
          StaffButton(
            label: t('mentor.materials.saveDraft'),
            loading: action.busy,
            onPressed:
                action.locked ||
                    _needsReview ||
                    !writable ||
                    !_material.ownEditable(actor?.id ?? '', widget.classId) ||
                    !dirty
                ? null
                : () async {
                    final success = await ref
                        .read(provider.notifier)
                        .edit(
                          _material,
                          title: _title.text,
                          description: _description.text.isEmpty ? null : _description.text,
                        );
                    if (!mounted || !context.mounted || !success) {
                      return;
                    }
                    showStaffToast(context, t('mentor.materials.saved'));
                    _close();
                  },
          ),
        ],
      ),
    );
  }
}
