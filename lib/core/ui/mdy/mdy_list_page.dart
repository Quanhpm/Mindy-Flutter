import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mdy_button.dart';
import 'mdy_icon.dart';
import 'mdy_primitives.dart';
import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';
import 'mdy_type.dart';

/// Clone `components/ui/list-page.tsx` › `SubpageHeader`: header phụ có nút back trực tiếp.
class MdySubpageHeader extends StatelessWidget {
  const MdySubpageHeader({
    super.key,
    required this.title,
    required this.backLabel,
    required this.onBack,
    this.subtitle,
    this.child,
    this.flush = false,
  });

  final String title;
  final String? subtitle;
  final String backLabel;
  final VoidCallback onBack;
  final Widget? child;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return MdyBrandHeader(
      subpage: true,
      flush: flush,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s12,
        children: [
          Row(
            spacing: MdySpace.s12,
            children: [
              MdyButton(
                key: const Key('subpage-back'),
                variant: MdyButtonVariant.text,
                size: MdyButtonSize.sm,
                padding: const EdgeInsets.symmetric(horizontal: MdySpace.s8, vertical: MdySpace.s8),
                semanticLabel: backLabel,
                onPressed: onBack,
                child: MdyIcon(MdyIcons.arrowBack, color: c.onBrand),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: MdyType.size(18, MdyType.w600).copyWith(color: c.onBrand)),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: MdyType.size(13).copyWith(color: c.onBrandMuted)),
                  ],
                ),
              ),
            ],
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Clone `ListPage<T>`: header phụ + danh sách bo 28 kéo lên 28, gap 12, px16 py28, kéo để làm mới.
class MdyListPage<T> extends StatelessWidget {
  const MdyListPage({
    super.key,
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.rows,
    required this.rowKey,
    required this.renderRow,
    this.subtitle,
    this.headerExtra,
    this.header,
    this.footer,
    this.refresh,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final String backLabel;
  final VoidCallback onBack;
  final Widget? headerExtra;
  final Widget? header;
  final List<T> rows;
  final String Function(T row) rowKey;
  final Widget Function(BuildContext context, T row, int index) renderRow;
  final Widget? footer;
  final Future<void> Function()? refresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final items = <Widget>[
      ?header,
      for (var i = 0; i < rows.length; i++) KeyedSubtree(key: ValueKey(rowKey(rows[i])), child: renderRow(context, rows[i], i)),
      ?footer,
    ];
    Widget list = ListView.separated(
      controller: controller,
      physics: refresh == null ? null : const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: EdgeInsets.fromLTRB(
        MdySpace.s16,
        MdySpace.s28,
        MdySpace.s16,
        MdySpace.s28 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: MdySpace.s12),
      itemBuilder: (_, i) => items[i],
    );
    if (refresh != null) list = RefreshIndicator(onRefresh: refresh!, color: c.primary, child: list);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MdySubpageHeader(title: title, subtitle: subtitle, backLabel: backLabel, onBack: onBack, child: headerExtra),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -MdySpace.s28,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(MdyRadius.r28)),
                      ),
                      child: MediaQuery.removePadding(context: context, removeTop: true, child: list),
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
