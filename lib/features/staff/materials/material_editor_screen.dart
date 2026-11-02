import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/files_api.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import 'materials_models.dart';
import 'materials_query.dart';
import 'materials_screens.dart';
import 'materials_service.dart';
import 'materials_widgets.dart';

class StaffMaterialEditorScreen extends ConsumerStatefulWidget {
  const StaffMaterialEditorScreen({
    super.key,
    required this.classId,
    required this.classUnitId,
    required this.courseUnitId,
    this.id,
    this.unitTitle,
  });
  final String classId, classUnitId, courseUnitId;
  final String? id, unitTitle;
  @override
  ConsumerState<StaffMaterialEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<StaffMaterialEditorScreen> {
  StaffMaterial? _base, _conflict;
  StaffMaterialType? _type;
  FileUploadStatus? _file;
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _article = TextEditingController();
  String _fileName = '', _stage = '';
  int _percent = 0, _sequence = 0;
  bool _busy = false, _dirty = false, _initialized = false, _allowLeave = false;
  MaterialFailure? _error;
  Map<String, Object?>? _unknown;
  CancelToken? _cancel;
  Timer? _timer;
  MaterialDetailRequest get _request =>
      (manager: false, classId: widget.classId, id: widget.id ?? '');
  @override
  void dispose() {
    _sequence++;
    _cancel?.cancel();
    _timer?.cancel();
    _title.dispose();
    _description.dispose();
    _article.dispose();
    super.dispose();
  }

  void _accept(StaffMaterial m) {
    _base = m;
    _type = m.type;
    _title.text = m.title;
    _description.text = m.description ?? '';
    _article.clear();
    _dirty = false;
  }

  Future<void> _pick(StaffMaterialType type) async {
    if (_busy) return;
    final sequence = ++_sequence;
    _cancel?.cancel();
    _timer?.cancel();
    try {
      final picked = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      if (!mounted || sequence != _sequence || picked == null) return;
      final f = picked.files.single;
      if (f.path == null) {
        throw const MaterialFailure('error', code: 'unreadable');
      }
      final source = File(f.path!), size = await File(f.path!).length();
      final validation = materialFileError(f.name, size, type);
      if (validation != null) throw MaterialFailure('error', code: validation);
      if (!mounted || sequence != _sequence) return;
      setState(() {
        _type = type;
        _dirty = true;
        _file = null;
        _fileName = f.name;
        _stage = 'preparing';
        _busy = true;
        _error = null;
        if (_title.text.isEmpty) {
          _title.text = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        }
      });
      final files = ref.read(filesApiProvider),
          service = ref.read(staffMaterialServiceProvider),
          cancel = CancelToken();
      _cancel = cancel;
      final intent = await files.intent(
        classId: widget.classId,
        unitId: widget.classUnitId,
        courseUnitId: widget.courseUnitId,
        name: f.name,
        mimeType: materialMimes[f.name.split('.').last.toLowerCase()]!,
        size: size,
        cancel: cancel,
      );
      if (!mounted || sequence != _sequence) return;
      final url = service.storageUrl(intent.url.toString());
      setState(() {
        _stage = 'uploading';
        _percent = 0;
      });
      final storage = Dio(
        BaseOptions(
          followRedirects: false,
          connectTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      try {
        await storage.putUri<void>(
          url,
          data: source.openRead(),
          cancelToken: cancel,
          options: Options(
            headers: {...intent.headers, Headers.contentLengthHeader: size},
          ),
          onSendProgress: (sent, total) {
            if (mounted && sequence == _sequence) {
              setState(
                () => _percent = total > 0 ? (sent * 100 / total).round() : 0,
              );
            }
          },
        );
      } finally {
        storage.close(force: true);
      }
      if (!mounted || sequence != _sequence) return;
      setState(() => _stage = 'complete');
      final next = await files.complete(intent.fileId, cancel: cancel);
      if (!mounted || sequence != _sequence) return;
      if (next.courseUnitId != widget.courseUnitId) {
        throw const MaterialFailure('error', code: 'RESOURCE_MISMATCH');
      }
      setState(() {
        _file = next;
        _stage = next.status == FileStatus.READY
            ? 'ready'
            : next.status == FileStatus.PROCESSING
            ? 'processing'
            : 'fileFailed';
      });
      _poll(DateTime.now());
    } catch (e) {
      if (mounted && sequence == _sequence) {
        setState(() {
          _stage = '';
          _error = MaterialFailure.from(e);
        });
      }
    } finally {
      if (mounted && sequence == _sequence) setState(() => _busy = false);
    }
  }

  void _poll(DateTime started) {
    _timer?.cancel();
    if (_file == null ||
        ![
          FileStatus.PENDING_UPLOAD,
          FileStatus.PROCESSING,
        ].contains(_file!.status)) {
      return;
    }
    _timer = Timer(
      Duration(
        seconds: DateTime.now().difference(started).inSeconds < 30 ? 2 : 5,
      ),
      () async {
        if (!mounted) return;
        if (DateTime.now().difference(started).inSeconds > 180) {
          setState(() => _stage = 'slow');
          return;
        }
        if (ModalRoute.of(context)?.isCurrent != true ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused ||
            ref.read(staffOfflineProvider)) {
          _poll(started);
          return;
        }
        await _checkFile();
        if (mounted) _poll(started);
      },
    );
  }

  Future<void> _checkFile() async {
    final file = _file;
    if (file == null) return;
    try {
      final next = await ref.read(filesApiProvider).status(file.id);
      if (!mounted) return;
      if (next.courseUnitId != widget.courseUnitId) {
        throw const MaterialFailure('error', code: 'RESOURCE_MISMATCH');
      }
      setState(() {
        _file = next;
        _stage = next.status == FileStatus.READY
            ? 'ready'
            : next.status == FileStatus.PROCESSING
            ? 'processing'
            : 'fileFailed';
      });
    } catch (e) {
      if (mounted) setState(() => _error = MaterialFailure.from(e));
    }
  }

  void _finish(StaffMaterial m) {
    setState(() {
      _unknown = null;
      _dirty = false;
      _allowLeave = true;
    });
    ref.read(materialRevisionProvider.notifier).bump();
    ref
        .read(mdyToastProvider.notifier)
        .show(ref.read(trProvider)(mat('saved')));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.pushReplacement(
          StaffMaterialRoutes.detail(widget.classId, m.id),
        );
      }
    });
  }

  Future<void> _save() async {
    if (_busy || _unknown != null) return;
    final body = <String, Object?>{
      'title': _title.text.trim(),
      'description': _description.text.isEmpty ? null : _description.text,
      if (_base != null)
        'expectedRevision': _base!.revision
      else
        'contentType': _type!.name,
      if (_type != StaffMaterialType.ARTICLE && _file?.status == FileStatus.READY)
        'fileId': _file!.id,
      if (_type == StaffMaterialType.ARTICLE &&
          (_base == null || _article.text.isNotEmpty))
        'contentText': _article.text,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await ref
          .read(staffMaterialServiceProvider)
          .save(widget.classId, widget.classUnitId, body, id: widget.id);
      if (mounted) _finish(m);
    } catch (e) {
      if (!mounted) return;
      final error = MaterialFailure.from(e);
      setState(() {
        _error = error;
        if (error.kind == 'uncertain') _unknown = Map.unmodifiable(body);
      });
      if (error.kind == 'conflict' && widget.id != null) {
        try {
          final m = await ref
              .read(staffMaterialServiceProvider)
              .detail(false, widget.classId, widget.id!);
          if (mounted) setState(() => _conflict = m);
        } catch (_) {
          if (mounted) ref.invalidate(materialDetailProvider(_request));
        }
      }
      if (['denied', 'notFound'].contains(error.kind)) {
        _title.clear();
        _description.clear();
        _article.clear();
        _file = null;
        _sequence++;
        _cancel?.cancel();
        ref.invalidate(materialDetailProvider(_request));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final body = _unknown;
    if (_busy || body == null) return;
    setState(() => _busy = true);
    final service = ref.read(staffMaterialServiceProvider);
    bool matches(StaffMaterial m) =>
        m.title == body['title'] &&
        m.description == body['description'] &&
        (body['fileId'] == null || m.file?.id == body['fileId']) &&
        (body['contentText'] == null ||
            m.html == plainArticleHtml(body['contentText']! as String));
    try {
      if (widget.id != null) {
        final latest = await service.detail(false, widget.classId, widget.id!);
        if (!mounted) return;
        final revision = body['expectedRevision']! as int;
        if (latest.revision == revision) {
          setState(() {
            _unknown = null;
            _error = null;
          });
        } else if (latest.revision == revision + 1 && matches(latest)) {
          _finish(latest);
        } else {
          setState(() {
            _unknown = null;
            _conflict = latest;
          });
        }
      } else {
        final found = <StaffMaterial>[];
        final userId = ref.read(sessionProvider).user?.id;
        for (var page = 1; ; page++) {
          final result = await service.list(
            manager: false,
            classId: widget.classId,
            unitId: widget.classUnitId,
            status: 'DRAFT',
            page: page,
            pageSize: 100,
          );
          for (final m in result.items) {
            if (body['fileId'] != null && m.file?.id == body['fileId']) {
              found.add(await service.detail(false, widget.classId, m.id));
            } else if (body['fileId'] == null &&
                m.type == StaffMaterialType.ARTICLE &&
                m.title == body['title'] &&
                m.createdBy == userId) {
              final d = await service.detail(false, widget.classId, m.id);
              if (matches(d)) found.add(d);
            }
          }
          if (!mounted) return;
          if (page * 100 >= result.total) break;
          if (result.items.isEmpty) {
            throw const MaterialFailure('error', code: 'INVALID_PAGE');
          }
        }
        if (found.length == 1) {
          _finish(found.single);
        } else if (found.isEmpty) {
          setState(() {
            _unknown = null;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = MaterialFailure.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final initial = widget.id == null
        ? null
        : ref.watch(materialDetailProvider(_request));
    if (!_initialized) {
      if (initial?.value case final m?) {
        _initialized = true;
        _accept(m);
      }
    }
    final revoked =
        ['denied', 'notFound'].contains(_error?.kind) ||
        initial?.error is MaterialFailure &&
            [
              'denied',
              'notFound',
            ].contains((initial!.error! as MaterialFailure).kind);
    final allowed = _base?.canEdit ?? true,
        offline = ref.watch(staffOfflineProvider),
        locked = _busy || _unknown != null || !allowed;
    final articleValid =
        (_base != null && _article.text.isEmpty ||
            _article.text.trim().isNotEmpty) &&
        articleBytes(plainArticleHtml(_article.text)) <= 49152;
    final valid =
        allowed &&
        _type != null &&
        _title.text.trim().isNotEmpty &&
        _title.text.trim().runes.length <= 250 &&
        _description.text.runes.length <= 5000 &&
        (_type == StaffMaterialType.ARTICLE
            ? articleValid
            : _file?.status == FileStatus.READY ||
                  _base?.file != null && _fileName.isEmpty) &&
        (_dirty || _base?.status == ReviewStatus.REJECTED);
    return AttendancePage(
      prefix: 'editor',
      title: t(mat(widget.id == null ? 'upload' : 'edit')),
      subtitle: widget.unitTitle,
      onBack: () => staffBack(context),
      dirty: _dirty,
      busy: _busy,
      uncertain: _unknown != null,
      allowLeave: _allowLeave,
      children: [
        MaterialRead(
          hasData: !revoked && (widget.id == null || initial?.value != null),
          busy: initial?.isLoading ?? false,
          error: initial?.error == null
              ? null
              : MaterialFailure.from(initial!.error!),
          retry: () => ref.invalidate(materialDetailProvider(_request)),
          children: [
            if (_base == null)
              Row(
                spacing: MdySpace.s8,
                children: [
                  for (final type in StaffMaterialType.values)
                    Expanded(
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        selected: _type == type,
                        child: MdyButton(
                          key: Key('editor-kind-${type.name.toLowerCase()}'),
                          label: t(mat(type.name)),
                          variant: _type == type
                              ? MdyButtonVariant.primary
                              : MdyButtonVariant.secondary,
                          disabled: _busy || _unknown != null,
                          onPressed: () => setState(() {
                            _type = type;
                            _file = null;
                            _fileName = '';
                            _stage = '';
                            _dirty = true;
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            if (_type != null && _type != StaffMaterialType.ARTICLE)
              MdyButton(
                key: const Key('editor-upload-change'),
                icon: MdyIcons.uploadFile,
                variant: MdyButtonVariant.secondary,
                label: _fileName.isNotEmpty
                    ? _fileName
                    : _base?.file?.name ?? t(mat('pick')),
                disabled: locked || offline,
                onPressed: () => _pick(_type!),
              ),
            if (_stage.isNotEmpty)
              Semantics(
                value: '$_percent%',
                liveRegion: true,
                child: MdyText(
                  '${t(mat(_stage))}${_stage == 'uploading' ? ' $_percent%' : ''}',
                  key: const Key('editor-upload-status'),
                ),
              ),
            if (_busy && _stage == 'uploading')
              MdyButton(
                key: const Key('editor-upload-cancel'),
                variant: MdyButtonVariant.text,
                label: t(mat('cancel')),
                onPressed: () => setState(() {
                  _sequence++;
                  _cancel?.cancel();
                  _file = null;
                  _stage = '';
                  _busy = false;
                }),
              ),
            if (_file != null && _file!.status != FileStatus.READY && !_busy)
              MdyButton(
                label: t(mat('check')),
                disabled: offline,
                onPressed: _checkFile,
              ),
            AttendanceField(
              id: 'editor-title',
              label: t(mat('fieldTitle')),
              controller: _title,
              max: 250,
              multiline: false,
              disabled: locked,
              onChanged: (_) => setState(() => _dirty = true),
            ),
            AttendanceField(
              id: 'editor-description',
              label: t(mat('description')),
              controller: _description,
              max: 5000,
              disabled: locked,
              onChanged: (_) => setState(() => _dirty = true),
            ),
            if (_type == StaffMaterialType.ARTICLE) ...[
              if (_base?.html != null)
                MdyText('${t(mat('article'))} · ${t(mat('edit'))}'),
              AttendanceField(
                id: 'editor-article',
                label: t(mat('article')),
                controller: _article,
                disabled: locked,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              MdyText('${articleBytes(_article.text)} / 49152 bytes'),
            ],
            if (!allowed)
              MdyAlert(
                t(mat('denied')),
                warning: true,
                key: const Key('material-warning'),
              ),
            MdyButton(
              key: const Key('editor-save'),
              icon: MdyIcons.check,
              label: t(mat('save')),
              disabled: !valid || locked || _conflict != null || offline,
              busy: _busy,
              onPressed: _save,
            ),
            if (_type != StaffMaterialType.ARTICLE && !valid)
              MdyText(t(mat('pendingFile'))),
          ],
        ),
        MaterialProblem(error: _error, prefix: 'editor'),
        if (_unknown != null)
          MdyButton(
            key: const Key('editor-check'),
            disabled: _busy || offline,
            label: t(mat('check')),
            onPressed: _check,
          ),
        if (_conflict case final latest?) ...[
          MdyAlert(
            '${t(mat('conflict'))} ${latest.title}',
            warning: true,
            key: const Key('material-warning'),
          ),
          MdyButton(
            label: t(mat('useLatest')),
            onPressed: () => setState(() {
              _accept(latest);
              _conflict = null;
              _unknown = null;
              _error = null;
            }),
          ),
          if (widget.id != null && latest.canEdit)
            MdyButton(
              label: t(mat('keepMine')),
              onPressed: () => setState(() {
                _base = latest;
                _conflict = null;
                _error = null;
              }),
            ),
        ],
      ],
    );
  }
}
