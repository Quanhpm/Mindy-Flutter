import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/await_provider.dart';
import '../schedule/schedule_providers.dart' show mentorClockProvider;
import 'materials_models.dart';
import 'materials_providers.dart';
import 'material_widgets.dart';

Future<void> launchMaterialUri(Uri uri) async {
  final web = ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty;
  final email = uri.scheme == 'mailto' && uri.path.contains('@');
  if ((!web && !email) ||
      !await launchUrl(uri, mode: web ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication)) {
    throw ApiError(status: 0, code: 'MATERIAL_OPEN_FAILED');
  }
}

final materialLauncherProvider = Provider<Future<void> Function(Uri)>((ref) => launchMaterialUri);

Future<void> showMentorMaterial(BuildContext context, WidgetRef ref, String classId, MentorMaterial material) {
  final query = (classId: classId, materialId: material.id);
  ref.invalidate(mentorMaterialDetailProvider(query));
  return showStaffSheet<void>(
    context,
    title: material.title,
    builder: (_) => MaterialReaderContent(query: query),
  );
}

class MaterialReaderContent extends ConsumerStatefulWidget {
  const MaterialReaderContent({super.key, required this.query});
  final MaterialQuery query;
  @override
  ConsumerState<MaterialReaderContent> createState() => _MaterialReaderContentState();
}

class _MaterialReaderContentState extends ConsumerState<MaterialReaderContent> {
  String? _opening;
  Object? _error;
  Future<void> _open(MentorMaterial material, BinaryFileSummary file) async {
    if (_opening != null) {
      return;
    }
    final epoch = ref.read(sessionEpochProvider),
        launch = ref.read(materialLauncherProvider),
        clock = ref.read(mentorClockProvider);
    setState(() {
      _opening = file.id;
      _error = null;
    });
    try {
      final query = (classId: widget.query.classId, material: material, fileId: file.id);
      ref.invalidate(mentorMaterialAccessProvider(query));
      final access = await awaitWidgetProvider(ref, mentorMaterialAccessProvider(query).future);
      if (!mounted || ref.read(sessionEpochProvider) != epoch) {
        return;
      }
      if (!clock().isBefore(access.expiresAt)) {
        throw ApiError(status: 409, code: 'MATERIAL_LINK_EXPIRED');
      }
      await launch(access.url);
    } catch (error) {
      if (!mounted || ref.read(sessionEpochProvider) != epoch) {
        return;
      }
      setState(() => _error = error);
      if (error is ApiError && (error.status == 403 || error.status == 409)) {
        ref.invalidate(mentorMaterialDetailProvider(widget.query));
        ref.invalidate(mentorMaterialsProvider(widget.query.classId));
      }
    } finally {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        setState(() => _opening = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), provider = mentorMaterialDetailProvider(widget.query);
    ref.listen(sessionEpochProvider, (before, after) {
      if (before != after) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          StaffDataState(
            title: t('mentor.materials.openError'),
            description: t(materialErrorKey(_error!)),
            error: _error,
          ),
          const SizedBox(height: 12),
        ],
        ...ref
            .watch(provider)
            .when(
              skipLoadingOnRefresh: false,
              loading: () => [const Skeleton(height: 200)],
              error: (error, _) => [
                StaffDataState(
                  title: t('mentor.materials.loadError'),
                  description: t(materialErrorKey(error)),
                  error: error,
                  onRetry: () => ref.invalidate(provider),
                ),
              ],
              data: (detail) {
                final material = detail.material;
                final actor = ref.watch(sessionProvider).user;
                final preview =
                    material.published ||
                    (actor != null &&
                        material.createdBy == actor.id &&
                        material.classId == widget.query.classId &&
                        material.firstApprovedAt == null);
                return [
                  if (material.description?.isNotEmpty == true) ...[
                    Text(material.description!, style: StaffText.body),
                    const SizedBox(height: 16),
                  ],
                  if (material.type == MaterialContentType.ARTICLE)
                    SelectionArea(
                      child: HtmlWidget(
                        detail.html!,
                        textStyle: StaffText.body,
                        customWidgetBuilder: (element) {
                          if (element.localName != 'img') {
                            return null;
                          }
                          final id = element.attributes['data-file-id'];
                          final image = detail.inlineImages.where((file) => file.id == id).firstOrNull;
                          if (image == null || !preview) {
                            return Text(t('mentor.materials.imageUnavailable'), style: StaffText.caption);
                          }
                          return _MaterialImage(
                            classId: widget.query.classId,
                            material: material,
                            file: image,
                            alt: element.attributes['alt'],
                          );
                        },
                        onTapUrl: (url) async {
                          final uri = Uri.tryParse(url);
                          if (uri == null || url.startsWith('#')) {
                            return false;
                          }
                          final epoch = ref.read(sessionEpochProvider), launch = ref.read(materialLauncherProvider);
                          try {
                            await launch(uri);
                          } catch (error) {
                            if (mounted && ref.read(sessionEpochProvider) == epoch) {
                              setState(() => _error = error);
                            }
                          }
                          return true;
                        },
                      ),
                    ),
                  if (material.file != null) ...[
                    Text(
                      '${material.file!.name} · ${formatBytes(material.file!.size, t.locale.languageCode)}',
                      style: StaffText.caption,
                    ),
                    const SizedBox(height: 12),
                    if (preview)
                      StaffButton(
                        label: t('mentor.materials.openFile'),
                        loading: _opening == material.file!.id,
                        onPressed: _opening == null ? () => _open(material, material.file!) : null,
                      )
                    else
                      Text(t('mentor.materials.previewUnavailable'), style: StaffText.caption),
                  ],
                  if (detail.attachments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(t('mentor.materials.attachments'), style: StaffText.section),
                    const SizedBox(height: 8),
                    for (final file in detail.attachments)
                      TextButton(
                        onPressed: preview && _opening == null ? () => _open(material, file) : null,
                        child: Text('${file.name} · ${formatBytes(file.size, t.locale.languageCode)}'),
                      ),
                  ],
                ];
              },
            ),
      ],
    );
  }
}

class _MaterialImage extends ConsumerWidget {
  const _MaterialImage({required this.classId, required this.material, required this.file, this.alt});
  final String classId;
  final MentorMaterial material;
  final BinaryFileSummary file;
  final String? alt;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider),
        provider = mentorMaterialAccessProvider((classId: classId, material: material, fileId: file.id));
    Widget retry() =>
        TextButton(onPressed: () => ref.invalidate(provider), child: Text(t('mentor.materials.reloadImage')));
    return ref
        .watch(provider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Skeleton(height: 140),
          error: (error, _) => Column(
            children: [
              Text(t('mentor.materials.imageUnavailable'), style: StaffText.caption),
              retry(),
            ],
          ),
          data: (access) => Image.network(
            access.url.toString(),
            semanticLabel: alt ?? file.name,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Column(
              children: [
                Text(t('mentor.materials.imageUnavailable'), style: StaffText.caption),
                retry(),
              ],
            ),
          ),
        );
  }
}
