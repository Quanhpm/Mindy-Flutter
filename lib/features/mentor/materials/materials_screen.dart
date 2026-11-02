import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../classes/classes_models.dart';
import '../classes/classes_providers.dart';
import 'material_reader.dart';
import 'material_widgets.dart';
import 'materials_models.dart';
import 'materials_providers.dart';

class MentorMaterialsScreen extends ConsumerWidget {
  const MentorMaterialsScreen({super.key, this.classId});
  final String? classId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), id = classId;
    if (id == null) {
      return const MaterialClassChooser();
    }
    final provider = mentorMaterialsProvider(id);
    return StaffPage(
      title: t('mentor.materials.title'),
      subtitle: t('mentor.materials.subtitle'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mentorPrimaryWorkspaceProvider(id));
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: ref
              .watch(provider)
              .when(
                skipLoadingOnRefresh: false,
                loading: () => [const Skeleton(height: 100), const SizedBox(height: 16), const Skeleton(height: 200)],
                error: (error, _) => [
                  StaffDataState(
                    title: t('mentor.materials.loadError'),
                    description: t(materialErrorKey(error)),
                    error: error,
                    onRetry: () {
                      ref.invalidate(mentorPrimaryWorkspaceProvider(id));
                      ref.invalidate(provider);
                    },
                  ),
                ],
                data: (data) {
                  final groups = [
                    for (final group in data.groups)
                      UnitMaterials(
                        unit: group.unit,
                        items: group.items.where((m) => m.published).toList()
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
                      ),
                  ].where((g) => g.items.isNotEmpty);
                  return [
                    Text(data.workspace.name, style: StaffText.section),
                    const SizedBox(height: 8),
                    Text(
                      t('mentor.materials.publishedCount', {'count': data.publishedCount}),
                      style: StaffText.caption,
                    ),
                    const SizedBox(height: 20),
                    if (groups.isEmpty)
                      StaffDataState(
                        title: t('mentor.materials.empty'),
                        description: t('mentor.materials.emptyDescription'),
                      ),
                    for (final group in groups) ...[
                      Text(group.unit.title, style: StaffText.section),
                      const SizedBox(height: 12),
                      for (final material in group.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MaterialCard(
                            material: material,
                            unitTitle: group.unit.title,
                            onOpen: () => showMentorMaterial(context, ref, id, material),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ];
                },
              ),
        ),
      ),
    );
  }
}

class MaterialClassChooser extends ConsumerWidget {
  const MaterialClassChooser({super.key, this.upload = false});
  final bool upload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), provider = mentorPrimaryClassesProvider;
    return StaffPage(
      title: t(upload ? 'mentor.materials.uploadTitle' : 'mentor.materials.title'),
      subtitle: t('mentor.materials.chooseClass'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mentorMaterialsProvider);
          ref.invalidate(mentorPrimaryWorkspaceProvider);
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: ref
              .watch(provider)
              .when(
                skipLoadingOnRefresh: false,
                loading: () => [const Skeleton(height: 180)],
                error: (error, _) => [
                  StaffDataState(
                    title: t('mentor.classes.loadError'),
                    description: t(materialErrorKey(error)),
                    error: error,
                    onRetry: () => ref.invalidate(provider),
                  ),
                ],
                data: (data) {
                  final classes = data
                      .where(
                        (c) =>
                            c.status != MentorClassStatus.CANCELLED &&
                            (!upload || c.status != MentorClassStatus.COMPLETED),
                      )
                      .toList();
                  return [
                    if (classes.isEmpty)
                      StaffDataState(
                        title: t('mentor.classes.empty'),
                        description: t('mentor.classes.emptyDescription'),
                      ),
                    for (final item in classes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _MaterialClassCard(item: item, upload: upload),
                      ),
                  ];
                },
              ),
        ),
      ),
    );
  }
}

class _MaterialClassCard extends ConsumerWidget {
  const _MaterialClassCard({required this.item, required this.upload});
  final MentorClass item;
  final bool upload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider),
        value = ref.watch(mentorMaterialsProvider(item.id)),
        actor = ref.watch(sessionProvider).user;
    return GlassCard(
      onTap: () => context.push(upload ? Routes.mentorUpload(item.id) : Routes.mentorMaterials(item.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: StaffColors.tealSoft, shape: BoxShape.circle),
                child: Icon(upload ? Sym.uploadFile : Sym.folderOpen, color: StaffColors.teal700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: StaffText.bodyStrong),
                    const SizedBox(height: 4),
                    Text(item.code, style: StaffText.small),
                  ],
                ),
              ),
              const Icon(Sym.chevronRight, color: StaffColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          ...value.when(
            skipLoadingOnRefresh: false,
            loading: () => [const Skeleton(height: 32)],
            error: (error, _) => [
              Text(t('mentor.materials.countUnavailable'), style: StaffText.caption),
              TextButton(
                onPressed: () {
                  ref.invalidate(mentorPrimaryWorkspaceProvider(item.id));
                  ref.invalidate(mentorMaterialsProvider(item.id));
                },
                child: Text(t('common.retry')),
              ),
            ],
            data: (data) {
              final own = data.groups
                  .expand((g) => g.items)
                  .where((m) => m.classId == item.id && m.createdBy == actor?.id)
                  .toList();
              return upload
                  ? [
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: [
                          for (final status in MaterialReviewStatus.values)
                            StatusChip(
                              '${t('mentor.materials.status.${status.name}')} · ${own.where((m) => m.reviewStatus == status).length}',
                              tone: materialTone(status),
                            ),
                        ],
                      ),
                    ]
                  : [
                      Text(
                        t('mentor.materials.publishedCount', {'count': data.publishedCount}),
                        style: StaffText.caption,
                      ),
                    ];
            },
          ),
        ],
      ),
    );
  }
}
