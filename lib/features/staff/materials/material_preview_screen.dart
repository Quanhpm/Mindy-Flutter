import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../shared/connectivity.dart';
import '../teaching/classes_screens.dart';
import 'materials_models.dart';
import 'materials_service.dart';
import 'materials_widgets.dart';

Future<Uint8List> downloadMaterialBytes(Uri uri, CancelToken cancel) async {
  final http = Dio(
    BaseOptions(
      followRedirects: false,
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  try {
    final result = await http.getUri<List<int>>(
      uri,
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancel,
    );
    if (result.statusCode != 200 || result.data == null) {
      throw const MaterialFailure('error', code: 'cannotOpen');
    }
    return Uint8List.fromList(result.data!);
  } finally {
    http.close(force: true);
  }
}

class StaffMaterialPreviewScreen extends ConsumerStatefulWidget {
  const StaffMaterialPreviewScreen({
    super.key,
    required this.id,
    required this.revision,
    required this.title,
    this.classId,
    this.fileId,
    this.manager = false,
  });
  final String id, title;
  final int revision;
  final String? classId, fileId;
  final bool manager;
  @override
  ConsumerState<StaffMaterialPreviewScreen> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<StaffMaterialPreviewScreen> {
  StaffMaterial? _material;
  BinaryFileSummary? _file;
  Uint8List? _bytes;
  PdfControllerPinch? _pdf;
  VideoPlayerController? _video;
  bool _busy = true, _external = false, _failed = false, _renewing = false;
  int _sequence = 0, _attempts = 0, _page = 1, _pages = 0;
  MaterialFailure? _error;
  Uri? _link;
  CancelToken _cancel = CancelToken();
  final _transform = TransformationController();
  Timer? _focusTimer;
  late final AppLifecycleListener _life;
  Duration _position = Duration.zero;
  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onPause: () => _video?.pause(),
      onResume: () => unawaited(_load()),
    );
    Future.microtask(_load);
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (_video?.value.isPlaying ?? false) &&
          (ModalRoute.of(context)?.isCurrent != true ||
              ref.read(staffOfflineProvider))) {
        _video?.pause();
      }
    });
  }

  @override
  void dispose() {
    _sequence++;
    _cancel.cancel();
    _pdf?.dispose();
    _video?.dispose();
    _life.dispose();
    _focusTimer?.cancel();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final seq = ++_sequence;
    _cancel.cancel();
    _cancel = CancelToken();
    final oldVideo = _video;
    _video = null;
    await oldVideo?.dispose();
    _pdf?.dispose();
    _pdf = null;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
      _error = null;
      _bytes = null;
    });
    try {
      final service = ref.read(staffMaterialServiceProvider);
      final m = await service.detail(widget.manager, widget.classId, widget.id);
      if (m.revision != widget.revision) {
        throw const MaterialFailure('conflict');
      }
      final f = widget.fileId == null
          ? m.file
          : [
              ?m.file,
              ...m.attachments,
              ...m.inlineImages,
            ].where((f) => f.id == widget.fileId).firstOrNull;
      final article = m.type == StaffMaterialType.ARTICLE && widget.fileId == null;
      if (!article && f == null) throw const MaterialFailure('notFound');
      final external =
          f != null &&
          (m.attachments.any((a) => a.id == f.id) ||
              ![FileKind.PDF, FileKind.IMAGE, FileKind.VIDEO].contains(f.kind));
      Uint8List? bytes;
      Uri? videoUrl;
      if (!article && !external) {
        final access = await service.access(
          widget.manager,
          widget.classId,
          widget.id,
          widget.revision,
          fileId: f!.id,
        );
        if (f.kind == FileKind.VIDEO) {
          videoUrl = access.url;
        } else {
          bytes = await downloadMaterialBytes(access.url, _cancel);
        }
      }
      if (!mounted || seq != _sequence) return;
      if (f?.kind == FileKind.PDF && bytes != null) {
        _pdf = PdfControllerPinch(document: PdfDocument.openData(bytes));
      }
      setState(() {
        _material = m;
        _file = f;
        _external = external;
        _bytes = bytes;
        _busy = false;
      });
      if (videoUrl != null) await _openVideo(videoUrl);
    } catch (e) {
      if (mounted && seq == _sequence) {
        setState(() {
          _material = null;
          _error = MaterialFailure.from(e);
          _busy = false;
        });
      }
    }
  }

  Future<void> _openVideo(Uri uri) async {
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {},
    );
    _video = controller;
    controller.addListener(() {
      if (!mounted || _video != controller) return;
      if (controller.value.hasError) {
        unawaited(_renewVideo());
      } else {
        if (controller.value.position > _position + const Duration(seconds: 1)) {
          _attempts = 0;
        }
        _position = controller.value.position;
        setState(() {});
      }
    });
    await controller.initialize();
    if (!mounted || _video != controller) return;
    await controller.seekTo(_position);
    setState(() {});
  }

  Future<void> _renewVideo() async {
    if (_renewing) return;
    if (ref.read(staffOfflineProvider) || _attempts >= 3) {
      setState(() => _failed = true);
      return;
    }
    _renewing = true;
    _attempts++;
    try {
      final access = await ref
          .read(staffMaterialServiceProvider)
          .access(
            widget.manager,
            widget.classId,
            widget.id,
            widget.revision,
            fileId: _file?.id,
          );
      if (!mounted) return;
      await _video?.dispose();
      if (mounted) await _openVideo(access.url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _error = MaterialFailure.from(e);
        });
      }
    } finally {
      _renewing = false;
    }
  }

  Future<void> _externalOpen() async {
    try {
      final access = await ref
          .read(staffMaterialServiceProvider)
          .access(
            widget.manager,
            widget.classId,
            widget.id,
            widget.revision,
            fileId: _file!.id,
          );
      if (!mounted) return;
      if (!await launchUrl(access.url, mode: LaunchMode.externalApplication)) {
        throw const MaterialFailure('error', code: 'cannotOpen');
      }
    } catch (e) {
      if (mounted) setState(() => _error = MaterialFailure.from(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        c = context.mdy,
        video = _video,
        m = _material;
    final offline = ref.watch(staffOfflineProvider);
    return AttendancePage(
      prefix: 'preview',
      title: widget.title,
      subtitle: '${t(mat('revision'))} ${widget.revision}',
      onBack: () => staffBack(context, manager: widget.manager),
      overlays: [
        if (_link case final link?)
          MdyInlineDialog(
            key: const Key('preview-link-dialog'),
            title: t(mat('openLink')),
            onClose: () => setState(() => _link = null),
            children: [
              MdyText(link.toString()),
              MdyButton(
                label: t(mat('confirm')),
                onPressed: () async {
                  setState(() => _link = null);
                  try {
                    if (!await launchUrl(
                          link,
                          mode: LaunchMode.externalApplication,
                        ) &&
                        mounted) {
                      setState(() => _failed = true);
                    }
                  } catch (_) {
                    if (mounted) setState(() => _failed = true);
                  }
                },
              ),
              MdyButton(
                variant: MdyButtonVariant.text,
                label: t(mat('cancel')),
                onPressed: () => setState(() => _link = null),
              ),
            ],
          ),
      ],
      children: [
        MaterialRead(
          hasData: m != null,
          busy: _busy,
          error: _error,
          retry: _load,
          children: [
            if (m != null &&
                m.type == StaffMaterialType.ARTICLE &&
                widget.fileId == null)
              SizedBox(
                key: const Key('preview-article'),
                height: 480,
                child: SingleChildScrollView(
                  child: HtmlWidget(
                    m.html ?? '',
                    textStyle: MdyType.size(15).copyWith(color: c.ink),
                    customWidgetBuilder: (element) {
                      if (element.localName != 'img') return null;
                      final image = m.inlineImages
                          .where(
                            (f) => f.id == element.attributes['data-file-id'],
                          )
                          .firstOrNull;
                      if (image == null) return const SizedBox.shrink();
                      return _ArticleImage(
                        manager: widget.manager,
                        classId: widget.classId,
                        materialId: widget.id,
                        revision: widget.revision,
                        file: image,
                      );
                    },
                    onTapUrl: (url) async {
                      final link = Uri.tryParse(url);
                      if (link != null &&
                          ['http', 'https', 'mailto'].contains(link.scheme)) {
                        setState(() => _link = link);
                      }
                      return true;
                    },
                  ),
                ),
              )
            else if (_external)
              MdyButton(
                key: const Key('preview-open-external'),
                label: t(mat('external')),
                disabled: offline,
                onPressed: _externalOpen,
              )
            else if (_file?.kind == FileKind.VIDEO &&
                video != null &&
                video.value.isInitialized) ...[
              SizedBox(
                key: const Key('preview-video'),
                height: 480,
                child: Column(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: video.value.aspectRatio,
                        child: VideoPlayer(video),
                      ),
                    ),
                    VideoProgressIndicator(
                      video,
                      allowScrubbing: !offline,
                      colors: VideoProgressColors(
                        playedColor: c.primary,
                        bufferedColor: c.muted2,
                        backgroundColor: c.border,
                      ),
                    ),
                    MdyButton(
                      icon: video.value.isPlaying
                          ? MdyIcons.pause
                          : MdyIcons.playArrow,
                      label: t(mat('view')),
                      disabled: offline,
                      onPressed: () =>
                          video.value.isPlaying ? video.pause() : video.play(),
                    ),
                  ],
                ),
              ),
            ] else if (_pdf case final pdf?) ...[
              MdyText('$_page/$_pages'),
              SizedBox(
                height: 480,
                child: PdfViewPinch(
                  controller: pdf,
                  onPageChanged: (page) => setState(() => _page = page),
                  onDocumentLoaded: (document) =>
                      setState(() => _pages = document.pagesCount),
                  onDocumentError: (_) => setState(() => _failed = true),
                ),
              ),
            ] else if (_bytes case final bytes?)
              GestureDetector(
                onDoubleTap: () => _transform.value = Matrix4.identity(),
                child: SizedBox(
                  height: 440,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      semanticLabel: 'Material image',
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_failed) ...[
          MdyAlert(
            t(mat('cannotOpen')),
            warning: true,
            key: const Key('material-warning'),
          ),
          if (!offline) MdyButton(label: t(mat('retry')), onPressed: _load),
        ],
      ],
    );
  }
}

class _ArticleImage extends ConsumerStatefulWidget {
  const _ArticleImage({
    required this.manager,
    required this.classId,
    required this.materialId,
    required this.revision,
    required this.file,
  });
  final bool manager;
  final String? classId;
  final String materialId;
  final int revision;
  final BinaryFileSummary file;
  @override
  ConsumerState<_ArticleImage> createState() => _ImageState();
}

class _ImageState extends ConsumerState<_ArticleImage> {
  final _cancel = CancelToken();
  late final Future<Uint8List> _bytes = _load();
  Future<Uint8List> _load() async {
    final access = await ref
        .read(staffMaterialServiceProvider)
        .access(
          widget.manager,
          widget.classId,
          widget.materialId,
          widget.revision,
          fileId: widget.file.id,
        );
    return downloadMaterialBytes(access.url, _cancel);
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snapshot) => snapshot.hasData
        ? Image.memory(snapshot.data!, semanticLabel: widget.file.name)
        : snapshot.hasError
        ? MdyAlert(
            ref.watch(trProvider)(mat('partialImages')),
            warning: true,
            key: const Key('material-warning'),
          )
        : const SizedBox(height: 44),
  );
}
