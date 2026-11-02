import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_models.dart';
import 'attendance_logic.dart';
import 'attendance_models.dart';
import 'attendance_query.dart';

/// Clone `attendance/components/shared.tsx`.

String _a(String key) => 'mdy.attendance.$key';

/// `Page`: header phụ có tab, panel nền, footer cố định, chặn rời màn khi còn nháp/đang gửi/chưa chắc.
class AttendancePage extends ConsumerWidget {
  const AttendancePage({
    super.key,
    required this.prefix,
    required this.title,
    required this.onBack,
    required this.children,
    this.subtitle,
    this.footer,
    this.dirty = false,
    this.busy = false,
    this.uncertain = false,
    this.refresh,
    this.onEnd,
    this.tabs,
    this.tab,
    this.onTab,
    this.allowLeave = false,
    this.overlays = const [],
  });

  /// Sheet / hộp thoại theo state ([MdyInlineSheet], [MdyInlineDialog]).
  final List<Widget> overlays;

  final String prefix;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> children;
  final List<Widget>? footer;
  final bool dirty;
  final bool busy;
  final bool uncertain;
  final Future<void> Function()? refresh;
  final VoidCallback? onEnd;
  final List<({String value, String label})>? tabs;
  final String? tab;
  final ValueChanged<String>? onTab;

  /// `allowLeaveRef.current`: vừa lưu xong, cho rời màn không hỏi.
  final bool allowLeave;

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final t = ref.read(trProvider);
    final leave = await showMdyDialog<bool>(
      context,
      builder: (dialogContext) => MdyConfirmationDialog(
        key: Key('$prefix-leave-dialog'),
        title: t(_a('leaveTitle')),
        icon: MdyIcons.warning,
        children: [
          MdyText(t(uncertain ? _a('unknownResult') : _a('unsavedBody')), textAlign: TextAlign.center),
          MdyButton(
            key: Key('$prefix-leave-stay'),
            label: t(_a('leaveStay')),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          MdyButton(
            key: Key('$prefix-leave-discard'),
            variant: MdyButtonVariant.danger,
            label: t(uncertain ? _a('leaveAnyway') : _a('leaveDiscard')),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) onBack();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final guarded = !allowLeave && (dirty || busy || uncertain);
    final tabbed = tabs != null && tabs!.isNotEmpty;
    final firstTab = tabbed && tab == tabs!.first.value;
    void back() {
      if (busy) return;
      if (guarded) {
        _confirmLeave(context, ref);
      } else {
        onBack();
      }
    }

    final panel = Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(firstTab ? 0 : MdyRadius.r28),
          topRight: const Radius.circular(MdyRadius.r28),
        ),
      ),
      padding: const EdgeInsets.all(MdySpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: MdySpace.s20, children: children),
    );
    Widget screen = MdyScreen(
      key: Key('$prefix-screen'),
      app: true,
      flushBottom: true,
      onRefresh: refresh,
      children: [
        MdyBrandHeader(
          subpage: true,
          flush: tabbed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: MdySpace.s12,
                children: [
                  MdyButton(
                    key: Key('$prefix-back'),
                    variant: MdyButtonVariant.text,
                    semanticLabel: t(_a('back')),
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s12),
                    onPressed: back,
                    child: MdyIcon(MdyIcons.arrowBack, color: c.onBrand),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s4,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title, style: MdyType.size(18, MdyType.w600).copyWith(color: c.onBrand)),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: MdyType.size(13).copyWith(color: c.onBrandMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (tabbed)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(top: MdySpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final item in tabs!)
                          Semantics(
                            selected: item.value == tab,
                            button: true,
                            child: MdyPressed(
                              key: Key('$prefix-tab-${item.value}'),
                              onTap: () => onTab?.call(item.value),
                              builder: (context, _) {
                                final on = item.value == tab;
                                return Container(
                                  constraints: BoxConstraints(minHeight: on ? MdySpace.s48 : MdySpace.s40),
                                  padding: const EdgeInsets.symmetric(horizontal: MdySpace.s22, vertical: MdySpace.s10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: on ? c.bg : c.headerGlass,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(MdyRadius.r18)),
                                  ),
                                  child: Text(
                                    item.label,
                                    style: MdyType.size(14, MdyType.w600).copyWith(color: on ? c.ink : c.onBrand),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (tabbed) panel else MdyOverlap(by: MdySpace.s28, child: panel),
      ],
    );
    if (onEnd != null) {
      screen = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.pixels >= n.metrics.maxScrollExtent - 120) onEnd!();
          return false;
        },
        child: screen,
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !guarded && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy && guarded) _confirmLeave(context, ref);
      },
      child: Stack(
        children: [
          Column(
        children: [
          Expanded(child: screen),
          if (footer != null)
            Material(
              color: c.surface,
              child: Container(
                key: Key('$prefix-footer'),
                width: double.infinity,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
                padding: EdgeInsets.fromLTRB(MdySpace.s24, MdySpace.s12, MdySpace.s24, bottom > 12 ? bottom : 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: MdySpace.s10, children: footer!),
              ),
            ),
        ],
          ),
          ...overlays,
        ],
      ),
    );
  }
}

/// `Loading`: 1 khối lớn + 3 dòng.
class AttendanceLoading extends ConsumerWidget {
  const AttendanceLoading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    Widget block(double h) => MdySkeleton(
      label: t(_a('loading')),
      child: Container(
        height: h,
        decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(MdyRadius.r14)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s12,
      children: [block(MdySpace.s120), block(MdySpace.s64), block(MdySpace.s64), block(MdySpace.s64)],
    );
  }
}

/// `QueryBlock` của attendance.
class AttendanceQueryBlock extends ConsumerWidget {
  const AttendanceQueryBlock({super.key, required this.query, required this.prefix, required this.controller, required this.builder});
  final AttendanceQueryState query;
  final String prefix;
  final AttendanceQuery controller;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final kind = query.error?.kind;
    if (query.fatal) {
      return MdyCard(
        key: Key('$prefix-${kind?.name}'),
        margin: EdgeInsets.zero,
        children: [
          Semantics(liveRegion: true, child: MdyText(t(_a(kind!.name == 'denied' ? 'denied' : 'notFound')))),
        ],
      );
    }
    if (query.data == null) {
      if (query.offline) return MdyAlert(t(_a('offlineEmpty')), key: Key('$prefix-offline'), warning: true);
      if (query.error != null) {
        return MdyCard(
          key: Key('$prefix-error'),
          margin: EdgeInsets.zero,
          children: [
            MdyText(t(_a('error'))),
            MdyButton(key: Key('$prefix-retry'), label: t(_a('retry')), onPressed: controller.retry),
          ],
        );
      }
      return const AttendanceLoading();
    }
    final error = query.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        builder(context),
        if (query.offline)
          MdyAlert(t(_a('offline')), key: Key('$prefix-offline-banner'), warning: true)
        else if (error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s8,
            children: [
              MdyAlert(
                t(_a('stale')) + (error.requestId == null ? '' : ' · ${t(_a('support'), {'id': error.requestId})}'),
                key: Key('$prefix-stale'),
                warning: true,
              ),
              MdyButton(variant: MdyButtonVariant.text, label: t(_a('retry')), onPressed: controller.refresh),
            ],
          ),
      ],
    );
  }
}

/// `More`: Xem thêm / Thử lại trang sau.
class AttendanceMore extends ConsumerWidget {
  const AttendanceMore({
    super.key,
    required this.query,
    required this.controller,
    required this.count,
    required this.prefix,
    this.label,
    this.automatic = false,
  });
  final AttendanceQueryState query;
  final AttendanceQuery controller;
  final int count;
  final String prefix;
  final String? label;
  final bool automatic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final data = query.data;
    if (data == null || (count >= data.total && !query.footerError)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s8,
      children: [
        if (query.footerError && !query.offline) Semantics(liveRegion: true, child: MdyText(t(_a('error')))),
        MdyButton(
          key: Key('$prefix-more'),
          variant: MdyButtonVariant.text,
          disabled: query.busy || query.offline,
          busy: query.busy,
          semanticLabel: automatic ? t(_a('remaining'), {'count': data.total - count}) : null,
          label: query.footerError ? t(_a('retry')) : (label ?? t(_a('editor.more'))),
          onPressed: query.footerError ? controller.retry : controller.more,
        ),
      ],
    );
  }
}

String sessionStatusKey(SessionStatus s) => switch (s) {
  SessionStatus.SCHEDULED => _a('scheduled'),
  SessionStatus.IN_PROGRESS => _a('inProgress'),
  SessionStatus.COMPLETED => _a('completed'),
  SessionStatus.CANCELLED => _a('cancelled'),
};

/// `SessionHeading`: trạng thái + tên buổi, ngày giờ, giờ bắt đầu thực tế.
class SessionHeading extends ConsumerWidget {
  const SessionHeading({super.key, required this.session});
  final AttendanceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: MdySpace.s8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MdySpace.s8,
          runSpacing: MdySpace.s8,
          children: [
            MdyChip(
              t(sessionStatusKey(session.status)),
              variant: session.status == SessionStatus.IN_PROGRESS ? MdyChipVariant.success : MdyChipVariant.neutral,
            ),
            Text(session.title, style: MdyType.size(14, MdyType.w600).copyWith(color: c.ink)),
          ],
        ),
        Text(
          '${isoDate(session.startsAt)} · ${isoTime(session.startsAt)}–${isoTime(session.endsAt)}',
          style: MdyType.size(13).copyWith(color: c.secondary),
        ),
        if (session.actualStartedAt != null)
          Text(
            t(_a('finalize.started'), {'time': isoTime(session.actualStartedAt!), 'date': isoDate(session.actualStartedAt!)}),
            style: MdyType.size(12).copyWith(color: c.secondary),
          ),
      ],
    );
  }
}

/// `TotalsStrip`: Có mặt / Vắng / Chưa điểm danh + tổng.
class TotalsStrip extends ConsumerWidget {
  const TotalsStrip({super.key, required this.totals, required this.prefix});
  final Totals? totals;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Column(
      key: Key('$prefix-totals'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: MdySpace.s8,
      children: [
        Row(
          spacing: MdySpace.s8,
          children: [
            for (final key in const ['present', 'absent', 'unmarked'])
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(MdySpace.s10),
                  decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(MdyRadius.r14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s4,
                    children: [
                      Text(
                        totals == null ? '—' : '${totals!.of(key)}',
                        key: Key('$prefix-total-$key'),
                        style: MdyType.size(18, MdyType.w700).copyWith(color: c.ink),
                      ),
                      Text(t(_a('editor.$key')), style: MdyType.size(11).copyWith(color: c.secondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (totals != null)
          Text(t(_a('editor.totalLine'), {'count': totals!.eligible}), style: MdyType.size(12).copyWith(color: c.secondary)),
      ],
    );
  }
}

String markKey(Mark m) => _a('editor.${m.name.toLowerCase()}');

/// `AttendanceRowView`: 1 học viên với nút Có mặt / Vắng (hoặc chip trạng thái khi chỉ xem).
class AttendanceRowView extends ConsumerWidget {
  const AttendanceRowView({
    super.key,
    required this.row,
    required this.prefix,
    this.status,
    this.editable = false,
    this.onMark,
    this.dirty = false,
    this.allowUnmarked = false,
    this.disabled = false,
    this.trailing,
    this.provisional = false,
    this.hideUnmarked = false,
    this.compact = false,
  });

  final AttendanceRow row;
  final String prefix;
  final Mark? status;
  final bool editable;
  final ValueChanged<Mark>? onMark;
  final bool dirty;
  final bool allowUnmarked;
  final bool disabled;
  final Widget? trailing;
  final bool provisional;
  final bool hideUnmarked;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final current = status ?? row.status;
    final name = row.name ?? t(_a('nameMissing'));
    final width = MediaQuery.sizeOf(context).width;
    final stacked = width <= 380 || MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    if (compact) {
      final displayed = current == Mark.PRESENT ? Mark.PRESENT : Mark.ABSENT;
      final next = displayed == Mark.PRESENT ? Mark.ABSENT : Mark.PRESENT;
      final present = displayed == Mark.PRESENT;
      return Container(
        key: Key('$prefix-row-${row.id}'),
        constraints: const BoxConstraints(minHeight: MdySpace.s52),
        padding: EdgeInsets.fromLTRB(dirty ? MdySpace.s8 : 0, MdySpace.s4, 0, MdySpace.s4),
        decoration: dirty ? BoxDecoration(border: Border(left: BorderSide(color: c.warning, width: 3))) : null,
        child: Row(
          spacing: MdySpace.s12,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.muted2, shape: BoxShape.circle),
                child: Text(MdyAvatar.initials(name), style: MdyType.size(12, MdyType.w600).copyWith(color: c.ink)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s2,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
                  if (row.entryType == EntryType.MAKEUP) MdyChip(t(_a('makeup')), variant: MdyChipVariant.info),
                  if (dirty) Text(t(_a('unsavedRow')), style: MdyType.size(11).copyWith(color: c.warning)),
                ],
              ),
            ),
            Semantics(
              button: true,
              enabled: !(disabled || !editable),
              label: t(_a('correction.changeTo'), {'name': name, 'status': t(markKey(displayed)), 'next': t(markKey(next))}),
              excludeSemantics: true,
              child: MdyPressed(
                key: Key('$prefix-toggle-${row.id}'),
                enabled: !(disabled || !editable),
                onTap: () => onMark?.call(next),
                builder: (context, _) => Container(
                  constraints: const BoxConstraints(minHeight: MdySpace.s44, minWidth: 88),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: MdySpace.s28),
                    padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: present ? c.successBg : c.dangerBg,
                      borderRadius: BorderRadius.circular(MdyRadius.r99),
                    ),
                    child: Text(
                      t(markKey(displayed)),
                      style: MdyType.size(12, MdyType.w500).copyWith(color: present ? c.success : c.danger),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      key: Key('$prefix-row-${row.id}'),
      constraints: const BoxConstraints(minHeight: MdySpace.s64),
      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s10, vertical: MdySpace.s12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.divider),
          left: dirty ? BorderSide(color: c.warning, width: 3) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s8,
        children: [
          Row(
            spacing: MdySpace.s12,
            children: [
              MdyAvatar(name: name, size: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MdySpace.s4,
                  children: [
                    Text(name, style: MdyType.size(14, MdyType.w500).copyWith(color: c.ink)),
                    if (row.entryType == EntryType.MAKEUP) MdyChip(t(_a('makeup')), variant: MdyChipVariant.info),
                    if (row.checkedInAt != null)
                      Text(
                        t(_a('editor.checkedIn'), {'time': isoTime(row.checkedInAt!)}),
                        style: MdyType.size(12).copyWith(color: c.secondary),
                      ),
                    if (dirty) Text(t(_a('unsavedRow')), style: MdyType.size(12).copyWith(color: c.warning)),
                  ],
                ),
              ),
              if (!editable && !provisional && !(hideUnmarked && current == Mark.UNMARKED))
                MdyChip(
                  t(markKey(current)),
                  variant: current == Mark.PRESENT
                      ? MdyChipVariant.success
                      : current == Mark.ABSENT
                      ? MdyChipVariant.danger
                      : MdyChipVariant.neutral,
                ),
              ?trailing,
            ],
          ),
          if (editable)
            Wrap(
              alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
              spacing: MdySpace.s8,
              runSpacing: MdySpace.s8,
              children: [
                for (final mark in const [Mark.PRESENT, Mark.ABSENT])
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: current == mark,
                    enabled: !disabled,
                    label: '$name, ${t(markKey(mark))}',
                    excludeSemantics: true,
                    child: MdyPressed(
                      key: Key('$prefix-${mark.name.toLowerCase()}-${row.id}'),
                      enabled: !disabled,
                      onTap: () => onMark?.call(allowUnmarked && current == mark ? Mark.UNMARKED : mark),
                      builder: (context, _) {
                        final on = current == mark;
                        final good = mark == Mark.PRESENT;
                        return Container(
                          constraints: const BoxConstraints(minHeight: MdySpace.s44, minWidth: 80),
                          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? (good ? c.successBg : c.dangerBg) : c.surface,
                            border: Border.all(color: on ? (good ? c.success : c.danger) : c.border),
                            borderRadius: BorderRadius.circular(MdyRadius.r22),
                          ),
                          child: Text(
                            t(markKey(mark)),
                            style: MdyType.text.copyWith(color: on ? (good ? c.success : c.danger) : c.secondary),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `Field`: ô nhập nhiều dòng có bộ đếm ký tự.
class AttendanceField extends ConsumerWidget {
  const AttendanceField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    this.onChanged,
    this.max,
    this.error,
    this.multiline = true,
    this.disabled = false,
    this.trailing,
    this.compact = false,
    this.hintText,
    this.keyboardType,
    this.focusNode,
  });

  final String id;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? max;
  final String? error;
  final bool multiline;
  final bool disabled;
  final Widget? trailing;
  final bool compact;
  final String? hintText;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final count = noteLength(controller.text);
    final invalid = max != null && count > max!;
    final height = MediaQuery.sizeOf(context).height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(label, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
        Stack(
          children: [
            Semantics(
              label: max == null ? label : '$label, $max',
              hint: error,
              child: TextField(
                key: Key('$id-input'),
                controller: controller,
                focusNode: focusNode,
                enabled: !disabled,
                onChanged: onChanged,
                keyboardType: keyboardType ?? (multiline ? TextInputType.multiline : null),
                maxLines: multiline ? null : 1,
                minLines: multiline && !compact ? 4 : 1,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: c.primary,
                style: MdyType.size(14).copyWith(color: c.ink),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: disabled ? c.muted2 : c.surface,
                  hintText: hintText,
                  hintStyle: MdyType.size(14).copyWith(color: c.placeholder),
                  constraints: multiline ? BoxConstraints(maxHeight: height * .4) : null,
                  contentPadding: EdgeInsets.fromLTRB(
                    MdySpace.s12,
                    MdySpace.s12,
                    trailing != null ? MdySpace.s56 : MdySpace.s12,
                    MdySpace.s12,
                  ),
                  enabledBorder: _border(error != null || invalid ? c.dangerBorder : c.border),
                  focusedBorder: _border(error != null || invalid ? c.dangerBorder : c.primary),
                  disabledBorder: _border(c.border),
                ),
              ),
            ),
            if (trailing != null) Positioned(right: MdySpace.s4, top: 0, bottom: 0, child: Center(child: trailing)),
          ],
        ),
        if (max != null)
          Semantics(
            liveRegion: invalid,
            child: Text(
              '$count/$max',
              textAlign: TextAlign.right,
              style: MdyType.size(12).copyWith(color: invalid ? c.danger : c.secondary),
            ),
          ),
        if (error != null || invalid)
          Semantics(
            liveRegion: true,
            child: Text(
              error ?? t(_a('note.tooLong'), {'max': max}),
              key: Key('$id-error'),
              style: MdyType.size(12).copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(MdyRadius.r14), borderSide: BorderSide(color: color));
}

/// `FocusPanel`: khung cảnh báo viền vàng.
class FocusPanel extends StatelessWidget {
  const FocusPanel({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MdySpace.s16),
        decoration: BoxDecoration(
          color: c.warningBg,
          border: Border.all(color: c.warning),
          borderRadius: BorderRadius.circular(MdyRadius.r14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: MdySpace.s12, children: children),
      ),
    );
  }
}

/// `IntentBanner`: kết quả chưa chắc chắn, gửi lại cùng khoá.
class IntentBanner extends ConsumerWidget {
  const IntentBanner({super.key, required this.prefix, required this.offline, required this.busy, required this.onRetry});
  final String prefix;
  final bool offline;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return FocusPanel(
      key: Key('$prefix-intent'),
      children: [
        MdyText(t(_a('unknownResult'))),
        MdyText(t(_a('memoryOnly')), style: MdyType.size(12)),
        if (!offline)
          MdyButton(key: Key('$prefix-resend'), disabled: busy, label: t(_a('resend')), onPressed: onRetry),
      ],
    );
  }
}

/// `MutationError`: thông báo lỗi ghi theo mã backend.
class MutationError extends ConsumerWidget {
  const MutationError({super.key, required this.result, required this.prefix});
  final WriteResult? result;
  final String prefix;

  static String keyFor(String? code) {
    if (code == 'TEACHING_NOTE_WINDOW_CLOSED' || code == 'ATTENDANCE_EDIT_WINDOW_EXPIRED') return 'note.closedUnsaved';
    if (code != null && code.contains('STATE_CONFLICT')) return 'stateChanged';
    return switch (code) {
      'ATTENDANCE_RECOVERY_EVIDENCE_INVALID' => 'evidenceInvalid',
      'ATTENDANCE_RECOVERY_RECORD_EXISTS' => 'recordExists',
      'ATTENDANCE_RECOVERY_CLOCK_CONFLICT' => 'clockConflict',
      'CLASS_MENTOR_SCHEDULE_CONFLICT' => 'mentorConflict',
      'REASON_REQUIRED' => 'reasonRequired',
      _ => 'error',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    if (r == null || r.kind == WriteKind.success || r.kind == WriteKind.uncertain) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    return MdyAlert(
      t(_a(keyFor(r.code))) + (r.requestId == null ? '' : ' · ${t(_a('support'), {'id': r.requestId})}'),
      key: Key('$prefix-mutation-error'),
    );
  }
}
