import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_input.dart';
import '../../../core/ui/staff/staff_text_area.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/mindy_haptics.dart';
import '../classes/classes_providers.dart';
import 'file_picker_service.dart';
import 'material_actions.dart';
import 'material_edit_sheet.dart';
import 'material_reader.dart';
import 'material_widgets.dart';
import 'materials_models.dart';
import 'materials_providers.dart';
import 'materials_screen.dart';
import 'upload_controller.dart';
import 'upload_policy.dart';

class MentorUploadScreen extends StatelessWidget {
  const MentorUploadScreen({super.key, this.classId});
  final String? classId;
  @override
  Widget build(BuildContext context) => classId == null
      ? const MaterialClassChooser(upload: true)
      : _UploadClassScreen(key: ValueKey(classId), classId: classId!);
}

class _UploadClassScreen extends ConsumerStatefulWidget {
  const _UploadClassScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<_UploadClassScreen> createState() => _UploadClassScreenState();
}

class _UploadClassScreenState extends ConsumerState<_UploadClassScreen> {
  final _title = TextEditingController(),
      _description = TextEditingController();
  final _scroll = ScrollController();
  PickedUploadFile? _file;
  String? _unitId;
  UploadCategory _category = UploadCategory.document;
  MaterialReviewStatus? _filter;
  bool _picking = false,
      _allowPop = false,
      _confirming = false,
      _validate = false;
  BuildContext? _confirmationContext;
  MentorUploadController get _upload =>
      ref.read(mentorUploadProvider(widget.classId).notifier);
  MaterialActions get _actions =>
      ref.read(materialActionsProvider(widget.classId).notifier);
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final epoch = ref.read(sessionEpochProvider),
        picker = ref.read(mentorFilePickerProvider),
        category = _category;
    setState(() => _picking = true);
    try {
      final file = await picker.pick(category);
      if (!mounted || ref.read(sessionEpochProvider) != epoch || file == null) {
        return;
      }
      setState(() {
        _file = file;
        _title.text = file.name;
        _validate = false;
      });
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        showStaffToast(context, ref.read(trProvider)(materialErrorKey(error)));
      }
    } finally {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _capture() async {
    final epoch = ref.read(sessionEpochProvider),
        picker = ref.read(mentorFilePickerProvider);
    setState(() => _picking = true);
    try {
      final file = await picker.captureDocument();
      if (!mounted || ref.read(sessionEpochProvider) != epoch || file == null) {
        return;
      }
      setState(() {
        _category = UploadCategory.image;
        _file = file;
        _title.text = file.name;
        _validate = false;
      });
      await MindyHaptics.success();
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        showStaffToast(context, ref.read(trProvider)(materialErrorKey(error)));
      }
    } finally {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _picking = false);
      }
    }
  }

  Future<bool> _confirm(
    String title,
    String description,
    String confirm,
  ) async {
    if (_confirming) {
      return false;
    }
    _confirming = true;
    final t = ref.read(trProvider), epoch = ref.read(sessionEpochProvider);
    final yes = await showStaffSheet<bool>(
      context,
      title: title,
      builder: (ctx) {
        _confirmationContext = ctx;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: StaffText.body),
            const SizedBox(height: 16),
            StaffButton(
              label: confirm,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            StaffButton(
              label: t('mentor.materials.cancel'),
              outlined: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return false;
    }
    _confirmationContext = null;
    _confirming = false;
    return ref.read(sessionEpochProvider) == epoch && yes == true;
  }

  void _back() {
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.mentorPage('upload'));
        }
      }
    });
  }

  Future<void> _leave() async {
    final value = ref.read(mentorUploadProvider(widget.classId));
    final unsent =
        _file != null && !value.hasWork && value.step != UploadStep.done;
    if (!value.hasWork && !unsent) {
      _back();
      return;
    }
    final t = ref.read(trProvider), epoch = ref.read(sessionEpochProvider);
    if (!await _confirm(
      t('mentor.materials.leaveTitle'),
      t(
        unsent
            ? 'mentor.materials.leaveUnsent'
            : 'mentor.materials.leaveDescription',
      ),
      t(
        unsent
            ? 'mentor.materials.leaveUnsentConfirm'
            : 'mentor.materials.leave',
      ),
    )) {
      return;
    }
    if (!mounted || ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    if (value.busy) {
      await _upload.cancel();
    }
    if (mounted && ref.read(sessionEpochProvider) == epoch) {
      _back();
    }
  }

  Future<void> _reset() async {
    final value = ref.read(mentorUploadProvider(widget.classId)),
        t = ref.read(trProvider),
        epoch = ref.read(sessionEpochProvider);
    if (value.hasWork &&
        !await _confirm(
          t('mentor.materials.abandonTitle'),
          t(
            value.requiresVerification
                ? 'mentor.materials.abandonUnconfirmed'
                : 'mentor.materials.abandonDescription',
          ),
          t('mentor.materials.chooseAnother'),
        )) {
      return;
    }
    if (!mounted || ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    if (_upload.reset(abandonUnconfirmed: value.requiresVerification)) {
      setState(() {
        _file = null;
        _title.clear();
        _description.clear();
        _validate = false;
      });
    }
  }

  Future<void> _uploaded(Future<bool> Function() action) async {
    final epoch = ref.read(sessionEpochProvider), t = ref.read(trProvider);
    final job = action();
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    final success = await job;
    if (!mounted || ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    if (success) {
      await MindyHaptics.success();
      if (!mounted) return;
      showStaffToast(context, t('mentor.materials.uploaded'));
    } else {
      final error = ref.read(mentorUploadProvider(widget.classId)).error;
      if (error != null) {
        await MindyHaptics.error();
        if (!mounted) return;
        showStaffToast(context, t(materialErrorKey(error)));
      }
    }
  }

  Future<void> _action(Future<bool> Function() action) async {
    final epoch = ref.read(sessionEpochProvider),
        t = ref.read(trProvider),
        success = await action();
    if (!mounted || ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    final state = ref.read(materialActionsProvider(widget.classId));
    showStaffToast(
      context,
      success
          ? t('mentor.materials.actionDone', {'count': state.changed})
          : t(materialErrorKey(state.error ?? Object())),
    );
    if (success) {
      await MindyHaptics.success();
    } else {
      await MindyHaptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        provider = mentorMaterialsProvider(widget.classId),
        value = ref.watch(provider),
        upload = ref.watch(mentorUploadProvider(widget.classId)),
        action = ref.watch(materialActionsProvider(widget.classId));
    final actor = ref.watch(sessionProvider).user;
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        final sheet = _confirmationContext;
        if (sheet != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (sheet.mounted && ModalRoute.of(sheet)?.isCurrent == true) {
              Navigator.of(sheet).pop(false);
            }
          });
        }
        _file = null;
        _title.clear();
        _description.clear();
        _picking = false;
        _validate = false;
      }
    });
    final locked = upload.busy || action.locked || _picking;
    return PopScope(
      canPop:
          _allowPop ||
          (!upload.hasWork &&
              (_file == null || upload.step == UploadStep.done)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: StaffPage(
        title: t('mentor.materials.uploadTitle'),
        subtitle: t('mentor.materials.uploadSubtitle'),
        onBack: _leave,
        body: RefreshIndicator(
          onRefresh: () async {
            if (upload.busy || action.busy) {
              return;
            }
            ref.invalidate(mentorPrimaryWorkspaceProvider(widget.classId));
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (upload.hasWork || upload.step == UploadStep.done) ...[
                _progress(upload),
                const SizedBox(height: 20),
              ],
              MaterialActionNotice(classId: widget.classId),
              ...value.when(
                skipLoadingOnRefresh: false,
                loading: () => [const Skeleton(height: 250)],
                error: (error, _) => [
                  StaffDataState(
                    title: t('mentor.materials.loadError'),
                    description: t(materialErrorKey(error)),
                    error: error,
                    onRetry: () {
                      ref.invalidate(
                        mentorPrimaryWorkspaceProvider(widget.classId),
                      );
                      ref.invalidate(provider);
                    },
                  ),
                ],
                data: (data) {
                  final writable =
                      !data.workspace.readonly &&
                      data.workspace.authorMaterials;
                  final own = [
                    for (final group in data.groups)
                      for (final material in group.items)
                        if (material.classId == widget.classId &&
                            material.createdBy == actor?.id)
                          (group.unit, material),
                  ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
                  final filtered = own
                      .where(
                        (row) =>
                            _filter == null || row.$2.reviewStatus == _filter,
                      )
                      .toList();
                  final drafts = own
                      .map((row) => row.$2)
                      .where(
                        (m) =>
                            m.reviewStatus == MaterialReviewStatus.DRAFT &&
                            m.ownEditable(actor?.id ?? '', widget.classId),
                      )
                      .toList();
                  return [
                    Text(data.workspace.name, style: StaffText.section),
                    const SizedBox(height: 16),
                    if (!writable)
                      Text(
                        t('mentor.classes.readonly'),
                        style: StaffText.caption,
                      )
                    else if (!upload.hasWork && upload.step != UploadStep.done)
                      _form(data, locked),
                    const SizedBox(height: 24),
                    Text(
                      t('mentor.materials.mySubmissions'),
                      style: StaffText.section,
                    ),
                    const SizedBox(height: 12),
                    FilterChipsBar<MaterialReviewStatus?>(
                      items: [
                        (null, '${t('mentor.materials.all')} (${own.length})'),
                        for (final status in MaterialReviewStatus.values)
                          (
                            status,
                            '${t('mentor.materials.status.${status.name}')} (${own.where((row) => row.$2.reviewStatus == status).length})',
                          ),
                      ],
                      selected: _filter,
                      onSelected: (status) => setState(() => _filter = status),
                    ),
                    const SizedBox(height: 12),
                    if (writable && drafts.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: StaffButton(
                          label: t('mentor.materials.submitAll', {
                            'count': drafts.length,
                          }),
                          outlined: true,
                          onPressed: locked
                              ? null
                              : () async {
                                  if (await _confirm(
                                    t('mentor.materials.submitAllTitle'),
                                    t('mentor.materials.submitAllDescription', {
                                      'count': drafts.length,
                                    }),
                                    t('mentor.materials.submit'),
                                  )) {
                                    if (!mounted) {
                                      return;
                                    }
                                    await _action(
                                      () => _actions.submit(drafts),
                                    );
                                  }
                                },
                        ),
                      ),
                    if (filtered.isEmpty)
                      StaffDataState(
                        title: t('mentor.materials.noSubmissions'),
                        description: t(
                          'mentor.materials.noSubmissionsDescription',
                        ),
                      ),
                    for (final (unit, material) in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MaterialCard(
                          material: material,
                          unitTitle: unit.title,
                          onOpen: () => showMentorMaterial(
                            context,
                            ref,
                            widget.classId,
                            material,
                          ),
                          onEdit:
                              !locked &&
                                  writable &&
                                  material.ownEditable(
                                    actor?.id ?? '',
                                    widget.classId,
                                  )
                              ? () => showMaterialEditor(
                                  context,
                                  ref,
                                  widget.classId,
                                  material,
                                )
                              : null,
                          onDelete:
                              !locked &&
                                  writable &&
                                  material.ownEditable(
                                    actor?.id ?? '',
                                    widget.classId,
                                  )
                              ? () async {
                                  if (await _confirm(
                                    t('mentor.materials.deleteTitle'),
                                    t('mentor.materials.deleteDescription', {
                                      'title': material.title,
                                    }),
                                    t('mentor.materials.delete'),
                                  )) {
                                    if (!mounted) {
                                      return;
                                    }
                                    await _action(
                                      () => _actions.delete(material),
                                    );
                                  }
                                }
                              : null,
                          onSubmit:
                              !locked &&
                                  writable &&
                                  material.reviewStatus ==
                                      MaterialReviewStatus.DRAFT &&
                                  material.ownEditable(
                                    actor?.id ?? '',
                                    widget.classId,
                                  )
                              ? () => _action(() => _actions.submit([material]))
                              : null,
                        ),
                      ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(MentorMaterials data, bool locked) {
    final t = ref.watch(trProvider),
        units = data.groups.map((g) => g.unit).toList();
    final unit =
        units.where((u) => u.id == _unitId).firstOrNull ?? units.firstOrNull;
    if (unit == null) {
      return StaffDataState(
        title: t('mentor.materials.noUnits'),
        description: t('mentor.materials.noUnitsDescription'),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('mentor.materials.unit'), style: StaffText.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey(unit.id),
            // Giữ mức Flutter 3.32 của pubspec; initialValue có từ sau 3.33.
            // ignore: deprecated_member_use
            value: unit.id,
            isExpanded: true,
            icon: const RotatedBox(
              quarterTurns: 1,
              child: Icon(Sym.chevronRight, color: StaffColors.teal700),
            ),
            style: StaffText.body,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final u in units)
                DropdownMenuItem(
                  value: u.id,
                  child: Text(
                    u.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: locked ? null : (id) => setState(() => _unitId = id),
          ),
          const SizedBox(height: 16),
          FilterChipsBar<UploadCategory>(
            enabled: !locked,
            items: [
              for (final category in UploadCategory.values)
                (category, t('mentor.materials.category.${category.name}')),
            ],
            selected: _category,
            onSelected: (category) {
              if (!locked) {
                setState(() {
                  _category = category;
                  _file = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Text(t('mentor.materials.fileLimits'), style: StaffText.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StaffButton(
                  label: t(
                    _file == null
                        ? 'mentor.materials.chooseFile'
                        : 'mentor.materials.changeFile',
                  ),
                  icon: Sym.uploadFile,
                  outlined: true,
                  loading: _picking,
                  onPressed: locked ? null : _pick,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StaffButton(
                  key: const Key('mentor-capture-document'),
                  label: t('mentor.materials.captureDocument'),
                  icon: Sym.cameraAlt,
                  outlined: true,
                  loading: _picking,
                  onPressed: locked ? null : _capture,
                ),
              ),
            ],
          ),
          if (_file != null) ...[
            const SizedBox(height: 10),
            if (_file!.localPath != null && _category == UploadCategory.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_file!.localPath!),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (_file!.localPath != null && _category == UploadCategory.image)
              const SizedBox(height: 10),
            Text(
              '${_file!.name} · ${formatBytes(_file!.size, t.locale.languageCode)}',
              style: StaffText.caption,
            ),
          ],
          if (_file != null) ...[
            const SizedBox(height: 16),
            StaffInput(
              label: t('mentor.materials.titleLabel'),
              controller: _title,
              enabled: !locked,
              onChanged: (_) {
                if (_validate) {
                  setState(() {});
                }
              },
              error:
                  _validate &&
                      (_title.text.trim().isEmpty ||
                          _title.text.trim().length > 250)
                  ? t('mentor.materials.errors.metadata')
                  : null,
            ),
            StaffTextArea(
              label: t('mentor.materials.description'),
              controller: _description,
              enabled: !locked,
            ),
            StaffButton(
              label: t('mentor.materials.startUpload'),
              onPressed: locked || _file == null
                  ? null
                  : () {
                      setState(() => _validate = true);
                      if (_title.text.trim().isEmpty ||
                          _title.text.trim().length > 250 ||
                          _description.text.length > 5000) {
                        if (_description.text.length > 5000) {
                          showStaffToast(
                            context,
                            t('mentor.materials.errors.metadata'),
                          );
                        }
                        return;
                      }
                      _uploaded(
                        () => _upload.start(
                          file: _file!,
                          unit: unit,
                          title: _title.text,
                          description: _description.text.isEmpty
                              ? null
                              : _description.text,
                        ),
                      );
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _progress(UploadState upload) {
    final t = ref.watch(trProvider), done = upload.step == UploadStep.done;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(upload.title ?? upload.fileName ?? '', style: StaffText.title),
          const SizedBox(height: 6),
          Text(
            '${upload.unitTitle ?? ''} · ${upload.size == null ? '' : formatBytes(upload.size!, t.locale.languageCode)}',
            style: StaffText.caption,
          ),
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              t('mentor.materials.step.${upload.step.name}'),
              style: StaffText.bodyStrong,
            ),
          ),
          if (upload.busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: upload.step == UploadStep.transfer
                  ? upload.progress
                  : null,
              color: StaffColors.teal700,
            ),
            if (upload.step == UploadStep.transfer)
              Text(
                formatPercent(upload.progress * 100, t.locale.languageCode),
                style: StaffText.caption,
              ),
          ],
          if (upload.error != null) ...[
            const SizedBox(height: 12),
            StaffDataState(
              title: t('mentor.materials.uploadIssue'),
              description: t(materialErrorKey(upload.error!)),
              error: upload.error,
              retryLabel: t(
                upload.requiresVerification
                    ? 'mentor.materials.checkResult'
                    : 'common.retry',
              ),
              onRetry: upload.canRetry && !upload.busy
                  ? () => _uploaded(_upload.retry)
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          if (upload.busy)
            StaffButton(
              label: t('mentor.materials.stopUpload'),
              outlined: true,
              onPressed: () async {
                await _upload.cancel();
              },
            )
          else
            StaffButton(
              label: t(
                done
                    ? 'mentor.materials.uploadAnother'
                    : 'mentor.materials.chooseAnother',
              ),
              outlined: true,
              onPressed: _reset,
            ),
        ],
      ),
    );
  }
}
