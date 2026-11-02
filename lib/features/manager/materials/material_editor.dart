import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';
import '../../mentor/materials/upload_policy.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'materials_api.dart';
import 'materials_providers.dart';
import 'materials_screens.dart';
import 'upload_controller.dart';
import 'upload_widget.dart';

class ManagerMaterialEditor extends ConsumerStatefulWidget {
  const ManagerMaterialEditor({super.key, this.id, this.unitId});
  final String? id, unitId;
  @override
  ConsumerState<ManagerMaterialEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<ManagerMaterialEditor> with OperationsBack<ManagerMaterialEditor> {
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _content = TextEditingController(),
      _sort = TextEditingController(text: '0');
  MaterialContentType _type = MaterialContentType.ARTICLE;
  String? _unit;
  bool _initialized = false, _initializing = false, _dirty = false, _htmlMode = false, _preview = false;
  DateTime? _available;
  BinaryFileSummary? _primary;
  final _attachments = <BinaryFileSummary>[];
  ManagerMaterialSnapshot? _latest;
  Object? _error;
  @override
  String get fallback => Routes.managerMaterials;
  MaterialCommandTarget get _target => (id: widget.id ?? _unit ?? '', create: widget.id == null);
  ManagerUploadKey _key(String slot) => (unitId: _unit!, slot: '${widget.id ?? 'create'}:$slot');
  @override
  bool get hasDraft =>
      _dirty ||
      (_unit != null && ref.read(managerMaterialCommandProvider(_target)).locked) ||
      (_unit != null && ['primary', 'attachment', 'inline'].any((s) => ref.read(managerUploadProvider(_key(s))).busy));
  @override
  void initState() {
    super.initState();
    _unit = widget.unitId;
    for (final c in [_title, _description, _content, _sort]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (!_initializing) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _content, _sort]) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }

  void _initialize(ManagerMaterialSnapshot s) {
    if (_initialized) return;
    _initializing = true;
    final m = s.detail.material;
    _unit = m.courseUnitId;
    _type = m.type;
    _title.text = m.title;
    _description.text = m.description ?? '';
    _content.text = s.detail.html ?? '';
    _htmlMode = true;
    _sort.text = '${s.sortOrder}';
    _available = s.availableAt;
    _primary = m.file;
    _attachments.addAll(s.detail.attachments);
    _initialized = true;
    _initializing = false;
  }

  Future<void> _availability() async {
    final zone = await ref.read(managerZoneProvider.future);
    if (!mounted) return;
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (!mounted || time == null) return;
    setState(() {
      _available = tz.TZDateTime(tz.getLocation(zone), day.year, day.month, day.day, time.hour, time.minute).toUtc();
      _dirty = true;
    });
  }

  Future<void> _save(ManagerMaterialSnapshot? initial) async {
    final sort = int.tryParse(_sort.text), title = _title.text.trim();
    if (title.isEmpty ||
        title.length > 250 ||
        _description.text.length > 5000 ||
        sort == null ||
        sort < 0 ||
        sort > 2147483647 ||
        (_type == MaterialContentType.ARTICLE &&
            (_content.text.trim().isEmpty || utf8.encode(_content.text).length > 49152)) ||
        (_type != MaterialContentType.ARTICLE && _primary == null) ||
        _attachments.length > 50) {
      setState(() => _error = ApiError(status: 422, code: 'MANAGER_VALIDATION'));
      return;
    }
    final body = <String, Object?>{
      'title': title,
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'sortOrder': sort,
      'availableAt': _available?.toUtc().toIso8601String(),
      'attachmentFileIds': _attachments.map((f) => f.id).toList(),
      if (widget.id == null) 'contentType': _type.name,
      if (widget.id != null) 'expectedRevision': initial!.detail.material.revision,
      if (_type == MaterialContentType.ARTICLE) (_htmlMode ? 'contentHtml' : 'contentText'): _content.text,
      if (_type != MaterialContentType.ARTICLE) 'fileId': _primary!.id,
    };
    final result = await ref.read(managerMaterialCommandProvider(_target).notifier).run('patch', body);
    if (mounted && result?.snapshot != null) context.go(Routes.managerMaterial(result!.snapshot!.detail.material.id));
  }

  Future<void> _readLatest() async {
    try {
      final d = await ref.read(managerMaterialCommandProvider(_target).notifier).readLatest();
      if (mounted) setState(() => _latest = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _findExisting() async {
    final chosen = await Navigator.of(context).push<ManagerMaterialSnapshot>(
      MaterialPageRoute(
        builder: (_) => SessionBoundView(child: ManagerMaterialsScreen(unitId: _unit, selectExisting: true)),
      ),
    );
    if (!mounted || chosen == null) return;
    try {
      await ref.read(managerMaterialCommandProvider(_target).notifier).adoptExisting(chosen);
      if (mounted) context.go(Routes.managerMaterialEdit(chosen.detail.material.id));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _form(ManagerMaterialSnapshot? initial) {
    final t = ref.watch(trProvider),
        command = ref.watch(managerMaterialCommandProvider(_target)),
        zone = ref.watch(managerZoneProvider);
    final blocked = command.locked || command.conflict || initial?.detail.material.canEdit == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (initial?.detail.material.canEdit == false) Text(t('manager.readonly'), style: StaffText.bodyStrong),
        if (initial?.detail.material.published == true)
          Text(t('manager.editPublishedWarning'), style: StaffText.bodyStrong),
        if (widget.id == null)
          DropdownButton<MaterialContentType>(
            value: _type,
            isExpanded: true,
            items: [
              for (final type in MaterialContentType.values)
                DropdownMenuItem(value: type, child: Text(t('manager.materialType.${type.name}'))),
            ],
            onChanged: blocked
                ? null
                : (v) => setState(() {
                    _type = v!;
                    _dirty = true;
                    _primary = null;
                  }),
          ),
        StaffInput(label: t('manager.materialTitle'), controller: _title, enabled: !blocked),
        StaffTextArea(label: t('manager.description'), controller: _description, maxLength: 5000, enabled: !blocked),
        StaffInput(
          label: t('manager.sortOrder'),
          controller: _sort,
          keyboardType: TextInputType.number,
          enabled: !blocked,
        ),
        if (zone.value != null)
          Text(
            _available == null ? t('manager.availableNow') : Dates.instant(_available!, zone.value!),
            style: StaffText.caption,
          ),
        if (zone.hasError) managerFailure(t, zone.error!),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: blocked || zone.value == null ? null : _availability,
              child: Text(t('manager.chooseAvailable')),
            ),
            TextButton(
              onPressed: blocked
                  ? null
                  : () => setState(() {
                      _available = null;
                      _dirty = true;
                    }),
              child: Text(t('manager.clearAvailable')),
            ),
          ],
        ),
        if (_type == MaterialContentType.ARTICLE) ...[
          if (widget.id == null)
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: Text(t('manager.htmlMode'), style: StaffText.body),
                value: _htmlMode,
                onChanged: blocked
                    ? null
                    : (v) => setState(() {
                        if (v && !_htmlMode) {
                          _content.text =
                              '<p>${const HtmlEscape().convert(_content.text).replaceAll('\n', '<br>')}</p>';
                        }
                        _htmlMode = v;
                        _dirty = true;
                      }),
              ),
            ),
          Text(_htmlMode ? t('manager.preserveHtml') : t('manager.plainText'), style: StaffText.caption),
          StaffTextArea(label: t('manager.content'), controller: _content, maxLength: 49152, enabled: !blocked),
          TextButton(onPressed: () => setState(() => _preview = !_preview), child: Text(t('manager.preview'))),
          if (_preview)
            GlassCard(
              child: _htmlMode
                  ? HtmlWidget(
                      _content.text,
                      customWidgetBuilder: (el) =>
                          el.localName == 'img' ? Text(el.attributes['alt'] ?? t('manager.imageAfterSave')) : null,
                    )
                  : Text(_content.text, style: StaffText.body),
            ),
          if (!blocked)
            ManagerUploadBlock(
              uploadKey: _key('inline'),
              categories: const [UploadCategory.image],
              onUse: (f) => setState(() {
                if (!_htmlMode) {
                  _content.text = '<p>${const HtmlEscape().convert(_content.text).replaceAll('\n', '<br>')}</p>';
                  _htmlMode = true;
                }
                _content.text +=
                    '\n<img data-file-id="${f.id}" alt="${const HtmlEscape(HtmlEscapeMode.attribute).convert(f.name)}">';
                _dirty = true;
              }),
            ),
        ] else ...[
          if (_primary != null) Text(_primary!.name, style: StaffText.bodyStrong),
          if (!blocked)
            ManagerUploadBlock(
              uploadKey: _key('primary'),
              categories: _type == MaterialContentType.VIDEO
                  ? const [UploadCategory.video]
                  : const [UploadCategory.document, UploadCategory.image],
              onUse: (f) => setState(() {
                _primary = f;
                _dirty = true;
              }),
            ),
        ],
        const SizedBox(height: 16),
        Text(t('mentor.materials.attachments'), style: StaffText.section),
        for (final file in _attachments)
          Row(
            children: [
              Expanded(child: Text(file.name, style: StaffText.body)),
              IconButton(
                tooltip: t('manager.remove'),
                onPressed: blocked
                    ? null
                    : () => setState(() {
                        _attachments.remove(file);
                        _dirty = true;
                      }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        if (!blocked && _attachments.length < 50)
          ManagerUploadBlock(
            uploadKey: _key('attachment'),
            onUse: (f) => setState(() {
              if (!_attachments.any((x) => x.id == f.id) && f.id != _primary?.id) _attachments.add(f);
              _dirty = true;
            }),
          ),
        if (_error != null) managerFailure(t, _error!),
        if (command.error != null) managerFailure(t, command.error!),
        if (command.retryPending || command.conflict) ...[
          Text(t('manager.materialUnknown'), style: StaffText.bodyStrong),
          if (widget.id == null)
            StaffButton(label: t('manager.selectExistingDraft'), onPressed: command.busy ? null : _findExisting)
          else ...[
            StaffButton(label: t('mentor.operations.readLatest'), loading: command.busy, onPressed: _readLatest),
            if (_latest != null) ...[
              Text(
                '${_latest!.detail.material.title}\n${_latest!.detail.material.description ?? ''}\n${_latest!.detail.html ?? ''}\n${t('manager.revision', {'version': _latest!.detail.material.revision})}',
                style: StaffText.bodyStrong,
              ),
              Text(t('manager.keepDraftConflict'), style: StaffText.caption),
              StaffButton(
                label: t('mentor.operations.adoptVersion'),
                onPressed: () {
                  ref.read(managerMaterialCommandProvider(_target).notifier).reviewed();
                  ref.invalidate(managerMaterialProvider(widget.id!));
                  setState(() => _latest = null);
                },
              ),
            ],
          ],
        ] else
          StaffButton(
            label: t('manager.saveDraft'),
            loading: command.busy,
            onPressed: blocked ? null : () => _save(initial),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return protect(
      StaffPage(
        title: t(widget.id == null ? 'manager.createMaterial' : 'manager.edit'),
        onBack: back,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            if (widget.id != null)
              ManagerData(
                value: ref.watch(managerMaterialProvider(widget.id!)),
                onRetry: () => ref.invalidate(managerMaterialProvider(widget.id!)),
                data: (s) {
                  _initialize(s);
                  return _form(s);
                },
              )
            else if (_unit == null)
              Text(t('manager.chooseUnitForCreate'), style: StaffText.body)
            else
              _form(null),
          ],
        ),
      ),
    );
  }
}
