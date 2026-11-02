import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';
import '../../../core/session/session_controller.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'materials_api.dart';
import 'materials_providers.dart';

class ManagerMaterialsScreen extends ConsumerStatefulWidget {
  const ManagerMaterialsScreen({super.key, this.initialStatus, this.unitId, this.selectExisting = false});
  final MaterialReviewStatus? initialStatus;
  final String? unitId;
  final bool selectExisting;
  @override
  ConsumerState<ManagerMaterialsScreen> createState() => _MaterialsState();
}

class _MaterialsState extends ConsumerState<ManagerMaterialsScreen> {
  late MaterialReviewStatus? _status = widget.initialStatus;
  late String? _unitId = widget.unitId;
  String? _courseId;
  MaterialContentType? _type;
  Future<void> _open(MentorMaterial m) async {
    if (!widget.selectExisting) {
      context.push(Routes.managerMaterial(m.id));
      return;
    }
    try {
      final d = await ref.read(managerMaterialsApiProvider).detail(m.id);
      if (mounted) context.pop(d);
    } catch (e) {
      if (mounted) showStaffToast(context, ref.read(trProvider)(managerErrorKey(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), p = managerMaterialsProvider((unitId: _unitId, status: _status, type: _type));
    final courses = ref.watch(managerCoursesProvider);
    return StaffPage(
      title: t('manager.utility.materials'),
      onBack: () => managerBack(context),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(p),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            if (!widget.selectExisting)
              StaffButton(
                label: t('manager.createMaterial'),
                onPressed: _unitId == null ? null : () => context.push('${Routes.managerMaterialNew}?unitId=$_unitId'),
              ),
            const SizedBox(height: 12),
            ManagerData(
              value: courses,
              onRetry: () => ref.invalidate(managerCoursesProvider),
              data: (rows) => DropdownButton<String>(
                value: _courseId,
                isExpanded: true,
                hint: Text(t('manager.chooseCourse')),
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(t('manager.allCourses'))),
                  for (final c in rows)
                    DropdownMenuItem(
                      value: c.course.id,
                      child: Text(c.course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _courseId = v;
                  _unitId = null;
                }),
              ),
            ),
            if (_courseId != null)
              ManagerData(
                value: ref.watch(managerCourseProvider(_courseId!)),
                onRetry: () => ref.invalidate(managerCourseProvider(_courseId!)),
                data: (c) => DropdownButton<String>(
                  value: _unitId,
                  isExpanded: true,
                  hint: Text(t('manager.chooseUnit')),
                  items: [
                    DropdownMenuItem<String>(value: null, child: Text(t('manager.allUnits'))),
                    for (final u in c.units)
                      DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.number}. ${u.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _unitId = v),
                ),
              ),
            if (_unitId == null && !widget.selectExisting)
              Text(t('manager.chooseUnitForCreate'), style: StaffText.caption),
            const SizedBox(height: 12),
            FilterChipsBar<MaterialReviewStatus?>(
              items: [
                (null, t('manager.all')),
                for (final status in MaterialReviewStatus.values) (status, t('manager.materialStatus.${status.name}')),
              ],
              selected: _status,
              onSelected: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 8),
            FilterChipsBar<MaterialContentType?>(
              items: [
                (null, t('manager.allTypes')),
                for (final type in MaterialContentType.values) (type, t('manager.materialType.${type.name}')),
              ],
              selected: _type,
              onSelected: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(p),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final m in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        onTap: () => _open(m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title, style: StaffText.bodyStrong),
                            StatusChip(t('manager.materialStatus.${m.reviewStatus.name}')),
                            Text(t('manager.materialType.${m.type.name}'), style: StaffText.caption),
                            if (m.published) Text(t('manager.published'), style: StaffText.caption),
                            if (m.description != null)
                              Text(m.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: StaffText.body),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerMaterialScreen extends ConsumerStatefulWidget {
  const ManagerMaterialScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ManagerMaterialScreen> createState() => _MaterialState();
}

class _MaterialState extends ConsumerState<ManagerMaterialScreen> {
  Object? _error;
  String? _opening;
  CancelToken? _cancel;
  ManagerMaterialSnapshot? _latest;
  MaterialCommandTarget get _target => (id: widget.id, create: false);
  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _open(MentorMaterial m, BinaryFileSummary f) async {
    if (_opening != null) return;
    final epoch = ref.read(sessionEpochProvider), cancel = _cancel = CancelToken();
    setState(() {
      _opening = f.id;
      _error = null;
    });
    try {
      final access = await ref.read(managerMaterialsApiProvider).access(m, f.id, cancel: cancel);
      if (!mounted || ref.read(sessionEpochProvider) != epoch) return;
      if (!DateTime.now().isBefore(access.expiresAt)) throw ApiError(status: 409, code: 'MATERIAL_LINK_EXPIRED');
      if (!await launchUrl(access.url, mode: LaunchMode.inAppBrowserView)) {
        throw ApiError(status: 0, code: 'MATERIAL_OPEN_FAILED');
      }
    } catch (e) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) setState(() => _error = e);
    } finally {
      if (mounted && ref.read(sessionEpochProvider) == epoch) setState(() => _opening = null);
    }
  }

  Future<void> _action(MentorMaterial m, String action) async {
    final t = ref.read(trProvider),
        answer = await managerConfirm(
          context,
          title: t('manager.materialAction.$action'),
          description: t(
            action == 'approve'
                ? 'manager.approveAndPublish'
                : action == 'delete'
                ? 'manager.deleteMaterialDescription'
                : 'manager.materialActionDescription',
          ),
          reason: action == 'reject',
          reasonMax: 2000,
        );
    if (!mounted || answer == null) return;
    final result = await ref.read(managerMaterialCommandProvider(_target).notifier).run(action, {
      'expectedRevision': m.revision,
      if (action == 'reject') 'reason': answer.reason,
    });
    if (mounted && result?.deleted == true) managerBack(context);
  }

  Future<void> _readLatest() async {
    try {
      final d = await ref.read(managerMaterialCommandProvider(_target).notifier).readLatest();
      if (mounted) setState(() => _latest = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        p = managerMaterialProvider(widget.id),
        command = ref.watch(managerMaterialCommandProvider(_target)),
        actor = ref.watch(sessionProvider).user;
    return StaffPage(
      title: t('manager.materialDetail'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (s) {
              final m = s.detail.material;
              final approve =
                  m.reviewStatus == MaterialReviewStatus.PENDING_REVIEW ||
                  (m.reviewStatus == MaterialReviewStatus.DRAFT &&
                      ((m.createdBy == actor?.id && m.classId == null) || m.firstApprovedAt != null));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(m.title, style: StaffText.title),
                  StatusChip(t('manager.materialStatus.${m.reviewStatus.name}')),
                  Text(t('manager.revision', {'version': m.revision}), style: StaffText.caption),
                  Text(t(m.published ? 'manager.published' : 'manager.unpublished'), style: StaffText.caption),
                  if (m.description != null) Text(m.description!, style: StaffText.body),
                  if (m.rejectionReason != null) Text(m.rejectionReason!, style: StaffText.bodyStrong),
                  const SizedBox(height: 12),
                  if (s.detail.html != null)
                    SelectionArea(
                      child: HtmlWidget(
                        s.detail.html!,
                        textStyle: StaffText.body,
                        customWidgetBuilder: (element) {
                          if (element.localName != 'img') return null;
                          final file = s.detail.inlineImages
                              .where((f) => f.id == element.attributes['data-file-id'])
                              .firstOrNull;
                          return file == null
                              ? Text(t('mentor.materials.imageUnavailable'))
                              : ManagerMaterialImage(material: m, file: file);
                        },
                        onTapUrl: (url) async {
                          final uri = Uri.tryParse(url);
                          if (uri == null ||
                              !['https', 'http'].contains(uri.scheme) ||
                              uri.host.isEmpty ||
                              uri.userInfo.isNotEmpty) {
                            return false;
                          }
                          return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                        },
                      ),
                    ),
                  if (m.file != null) ...[
                    Text(m.file!.name, style: StaffText.body),
                    StaffButton(
                      label: t('mentor.materials.openFile'),
                      loading: _opening == m.file!.id,
                      onPressed: _opening != null ? null : () => _open(m, m.file!),
                    ),
                  ],
                  for (final f in s.detail.attachments)
                    TextButton(
                      onPressed: _opening != null ? null : () => _open(m, f),
                      child: Text('${f.name} · ${formatBytes(f.size, t.locale.languageCode)}'),
                    ),
                  if (_error != null) managerFailure(t, _error!),
                  if (command.error != null) managerFailure(t, command.error!),
                  if (command.retryPending || command.conflict) ...[
                    Text(t('manager.materialUnknown'), style: StaffText.caption),
                    StaffButton(
                      label: t('mentor.operations.readLatest'),
                      loading: command.busy,
                      onPressed: _readLatest,
                    ),
                    if (_latest != null) ...[
                      Text(
                        '${_latest!.detail.material.title}\n${t('manager.materialStatus.${_latest!.detail.material.reviewStatus.name}')} · ${t('manager.revision', {'version': _latest!.detail.material.revision})}',
                        style: StaffText.bodyStrong,
                      ),
                      StaffButton(
                        label: t('mentor.operations.adoptVersion'),
                        onPressed: () {
                          ref.read(managerMaterialCommandProvider(_target).notifier).reviewed();
                          ref.invalidate(p);
                          setState(() => _latest = null);
                        },
                      ),
                    ],
                  ] else ...[
                    if (approve)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: StaffButton(
                          label: t('manager.materialAction.approve'),
                          loading: command.busy,
                          onPressed: command.locked ? null : () => _action(m, 'approve'),
                        ),
                      ),
                    if (m.reviewStatus == MaterialReviewStatus.PENDING_REVIEW)
                      TextButton(
                        onPressed: command.locked ? null : () => _action(m, 'reject'),
                        child: Text(t('manager.materialAction.reject')),
                      ),
                    if (m.reviewStatus == MaterialReviewStatus.APPROVED && m.approvedRevision == m.revision)
                      TextButton(
                        onPressed: command.locked ? null : () => _action(m, m.published ? 'unpublish' : 'publish'),
                        child: Text(t('manager.materialAction.${m.published ? 'unpublish' : 'publish'}')),
                      ),
                    if (m.canEdit) ...[
                      TextButton(
                        onPressed: command.locked ? null : () => context.push(Routes.managerMaterialEdit(m.id)),
                        child: Text(t('manager.edit')),
                      ),
                      TextButton(
                        onPressed: command.locked ? null : () => _action(m, 'delete'),
                        child: Text(t('manager.materialAction.delete')),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

final _imageAccessProvider = FutureProvider.autoDispose
    .family<MaterialFileAccess, ({MentorMaterial material, String fileId})>((ref, q) {
      ref.watch(sessionEpochProvider);
      final c = CancelToken();
      ref.onDispose(c.cancel);
      return ref.watch(managerMaterialsApiProvider).access(q.material, q.fileId, cancel: c);
    });

class ManagerMaterialImage extends ConsumerWidget {
  const ManagerMaterialImage({super.key, required this.material, required this.file});
  final MentorMaterial material;
  final BinaryFileSummary file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _imageAccessProvider((material: material, fileId: file.id));
    return ManagerData(
      value: ref.watch(p),
      onRetry: () => ref.invalidate(p),
      data: (access) => DateTime.now().isBefore(access.expiresAt)
          ? Image.network(
              access.url.toString(),
              fit: BoxFit.contain,
              semanticLabel: file.name,
              errorBuilder: (_, _, _) =>
                  TextButton(onPressed: () => ref.invalidate(p), child: Text(ref.watch(trProvider)('common.retry'))),
            )
          : TextButton(onPressed: () => ref.invalidate(p), child: Text(ref.watch(trProvider)('common.retry'))),
    );
  }
}
