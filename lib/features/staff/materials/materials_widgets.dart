import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_widgets.dart';
import 'materials_models.dart';
import 'materials_service.dart';

String mat(String key) => 'mdy.materials.$key';
String materialSize(int size, String lang) =>
    '${NumberFormat('0.#', lang).format(size / 1024 / 1024)} MB';
String materialInstant(DateTime value, String lang) => DateFormat(
  'dd/MM/yyyy HH:mm',
  lang,
).format(value.toUtc().add(const Duration(hours: 7)));

class MaterialProblem extends ConsumerWidget {
  const MaterialProblem({
    super.key,
    this.error,
    this.retry,
    this.prefix = 'materials',
  });
  final MaterialFailure? error;
  final VoidCallback? retry;
  final String prefix;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    if (e == null) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    final fallback = t(mat(e.kind == 'error' ? 'error' : e.kind)),
        message = e.code.isEmpty || t(mat(e.code)) == mat(e.code)
            ? fallback
            : t(mat(e.code));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s8,
      children: [
        MdyAlert(
          '$message${e.requestId == null ? '' : ' · ${t(mat('support'))}: ${e.requestId}'}',
          warning: true,
          key: Key('$prefix-${e.kind}'),
        ),
        if (retry != null &&
            ![
              'offline',
              'denied',
              'notFound',
              'conflict',
              'uncertain',
            ].contains(e.kind))
          MdyButton(
            key: Key('$prefix-retry'),
            variant: MdyButtonVariant.text,
            label: t(mat('retry')),
            onPressed: retry,
          ),
      ],
    );
  }
}

class MaterialRead extends StatelessWidget {
  const MaterialRead({
    super.key,
    required this.hasData,
    required this.busy,
    required this.children,
    this.error,
    this.retry,
  });
  final bool hasData, busy;
  final List<Widget> children;
  final MaterialFailure? error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MdySpace.s16,
    children: [
      if (hasData) ...children else if (busy) const SkeletonList(count: 2),
      MaterialProblem(error: error, retry: retry),
    ],
  );
}

class MaterialStatusChip extends ConsumerWidget {
  const MaterialStatusChip({super.key, required this.item});
  final StaffMaterial item;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MdyChip(
    ref.watch(trProvider)(mat(item.stateLabel)),
    variant: item.status == ReviewStatus.REJECTED
        ? MdyChipVariant.danger
        : item.status == ReviewStatus.PENDING_REVIEW
        ? MdyChipVariant.warning
        : item.publishedAt != null
        ? MdyChipVariant.success
        : MdyChipVariant.neutral,
  );
}

class MaterialTile extends StatelessWidget {
  const MaterialTile({super.key, required this.item});
  final StaffMaterial item;
  @override
  Widget build(BuildContext context) => Container(
    width: MdySpace.s44,
    height: MdySpace.s44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.mdy.tint2,
      borderRadius: BorderRadius.circular(MdyRadius.r12),
    ),
    child: item.type == StaffMaterialType.ARTICLE
        ? MdyIcon(MdyIcons.article, size: 22, color: context.mdy.primary)
        : Text(
            (item.file?.name.split('.').last ?? 'FILE')
                .toUpperCase()
                .characters
                .take(4)
                .toString(),
            style: MdyType.size(
              11,
              MdyType.w600,
            ).copyWith(color: context.mdy.link),
          ),
  );
}

class MaterialRow extends ConsumerWidget {
  const MaterialRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.prefix,
    this.classTitle,
    this.author,
  });
  final StaffMaterial item;
  final VoidCallback onTap;
  final String prefix;
  final String? classTitle, author;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), c = context.mdy;
    final lang = ref.watch(localeProvider).languageCode;
    return Semantics(
      button: true,
      child: MdyPressed(
        key: Key('$prefix-row-${item.id}'),
        onTap: onTap,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? .8 : 1,
          child: MdyCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(MdySpace.s16),
            children: [
              Row(
                spacing: MdySpace.s12,
                children: [
                  MaterialTile(item: item),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s6,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          style: MdyType.size(
                            15,
                            MdyType.w600,
                          ).copyWith(color: c.ink),
                        ),
                        if (classTitle != null) MdyText(classTitle!),
                        if (author != null) MdyText(author!),
                        Text(
                          '${t(mat(item.type.name))}${item.file == null ? '' : ' · ${materialSize(item.file!.size, lang)}'}',
                          style: MdyType.size(13).copyWith(color: c.secondary),
                        ),
                        MaterialStatusChip(
                          key: Key('$prefix-row-status-${item.id}'),
                          item: item,
                        ),
                        if (item.status == ReviewStatus.REJECTED &&
                            item.rejectionReason != null)
                          Text(
                            item.rejectionReason!,
                            key: Key('$prefix-row-reason-${item.id}'),
                            maxLines: 2,
                            style: MdyType.size(13).copyWith(color: c.danger),
                          ),
                        Text(
                          '${t(mat('updated'))} ${materialInstant(item.updatedAt, lang)}',
                          style: MdyType.size(12).copyWith(color: c.tertiary),
                        ),
                      ],
                    ),
                  ),
                  const MdyIcon(MdyIcons.chevronRight, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
