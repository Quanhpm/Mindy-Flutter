import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../shared/connectivity.dart';
import 'leave_query.dart';
import 'leave_service.dart';

/// Clone `leave/components/shared.tsx`.

/// `useWords()`: khóa i18n của namespace `leave`.
String lv(String key) => 'mdy.leave.$key';

/// `leave/components/shared.tsx` › Page: footer, kéo làm mới và xác nhận bỏ nháp.
class LeavePage extends ConsumerStatefulWidget {
  const LeavePage({
    super.key,
    required this.prefix,
    required this.title,
    required this.onBack,
    required this.children,
    this.subtitle,
    this.footer,
    this.refresh,
    this.onEnd,
    this.busy = false,
    this.dirty = false,
    this.uncertain = false,
    this.allowLeave = false,
    this.overlays = const [],
    this.onOverlayBack,
  });
  final String prefix, title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> children, overlays;
  final List<Widget>? footer;
  final Future<void> Function()? refresh;
  final VoidCallback? onEnd;
  final VoidCallback? onOverlayBack;
  final bool busy, dirty, uncertain, allowLeave;

  @override
  ConsumerState<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends ConsumerState<LeavePage> {
  bool _leave = false, _leaving = false;
  bool get _guarded =>
      !_leaving &&
      !widget.allowLeave &&
      (widget.dirty || widget.busy || widget.uncertain);

  void _back() {
    if (widget.busy) return;
    if (_leave) {
      setState(() => _leave = false);
      return;
    }
    if (widget.overlays.isNotEmpty) {
      if (!widget.uncertain) widget.onOverlayBack?.call();
      return;
    }
    if (_guarded) {
      setState(() => _leave = true);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), c = context.mdy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget screen = MdyScreen(
      key: Key('${widget.prefix}-screen'),
      app: true,
      flushBottom: true,
      onRefresh: widget.refresh,
      children: [
        MdyBrandHeader(
          subpage: true,
          child: Row(
            spacing: MdySpace.s12,
            children: [
              MdyButton(
                key: Key('${widget.prefix}-back'),
                variant: MdyButtonVariant.text,
                semanticLabel: t(lv('back')),
                onPressed: _back,
                child: MdyIcon(MdyIcons.arrowBack, color: c.onBrand),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MdySpace.s4,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: MdyType.size(
                          18,
                          MdyType.w600,
                        ).copyWith(color: c.onBrand),
                      ),
                    ),
                    if (widget.subtitle case final subtitle?)
                      Text(
                        subtitle,
                        key: Key('${widget.prefix}-subtitle'),
                        style: MdyType.size(13).copyWith(color: c.onBrandMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        MdyOverlap(
          by: MdySpace.s28,
          child: Container(
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MdyRadius.r28),
              ),
            ),
            padding: const EdgeInsets.all(MdySpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s16,
              children: widget.children,
            ),
          ),
        ),
      ],
    );
    if (widget.onEnd != null) {
      screen = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 &&
              n.metrics.axis == Axis.vertical &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
            widget.onEnd!();
          }
          return false;
        },
        child: screen,
      );
    }
    return PopScope(
      canPop: !_guarded && widget.overlays.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(child: screen),
              if (widget.footer case final footer?)
                Container(
                  key: Key('${widget.prefix}-footer'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.divider)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    MdySpace.s24,
                    MdySpace.s12,
                    MdySpace.s24,
                    bottom > 12 ? bottom : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MdySpace.s10,
                    children: footer,
                  ),
                ),
            ],
          ),
          ...widget.overlays,
          if (_leave)
            MdyInlineDialog(
              key: const Key('leave-dialog'),
              title: t(lv('leaveTitle')),
              icon: MdyIcons.warning,
              onClose: () => setState(() => _leave = false),
              children: [
                MdyText(t(lv(widget.uncertain ? 'unknown' : 'leaveBody'))),
                MdyButton(
                  key: const Key('leave-stay'),
                  label: t(lv('stay')),
                  onPressed: () => setState(() => _leave = false),
                ),
                MdyButton(
                  key: const Key('leave-discard'),
                  variant: MdyButtonVariant.danger,
                  label: t(lv('discard')),
                  onPressed: () {
                    setState(() {
                      _leave = false;
                      _leaving = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onBack();
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void drainLeaveOptions(LeaveQueryState query, LeaveQuery controller) {
  if (query.data != null &&
      query.hasMore &&
      !query.busy &&
      !query.footerError &&
      !query.offline) {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.more());
  }
}

class LeaveLoading extends ConsumerWidget {
  const LeaveLoading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    key: const Key('leave-loading'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MdySpace.s12,
    children: [
      for (var i = 0; i < 3; i++)
        MdySkeleton(
          label: ref.watch(trProvider)(lv('loading')),
          child: Container(
            height: MdySpace.s120,
            decoration: BoxDecoration(
              color: context.mdy.muted2,
              borderRadius: BorderRadius.circular(MdyRadius.r14),
            ),
          ),
        ),
    ],
  );
}

/// Radio bo góc của phạm vi nghỉ / giờ học bù.
class LeaveChoice extends StatelessWidget {
  const LeaveChoice({
    super.key,
    required this.id,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.disabled = false,
  });
  final String id, label;
  final bool selected, disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final parts = label.split(' · ');
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: !disabled,
      button: true,
      label: label,
      excludeSemantics: true,
      child: MdyPressed(
        key: Key(id),
        enabled: !disabled,
        onTap: onPressed,
        builder: (context, pressed) => Opacity(
          opacity: disabled
              ? .5
              : pressed
              ? .8
              : 1,
          child: Container(
            constraints: BoxConstraints(
              minHeight: parts.length > 1 ? MdySpace.s56 : MdySpace.s44,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MdySpace.s12,
              vertical: MdySpace.s8,
            ),
            decoration: BoxDecoration(
              color: selected ? c.primary : c.surface,
              border: Border.all(color: selected ? c.primary : c.border),
              borderRadius: BorderRadius.circular(MdyRadius.r14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  parts.first,
                  textAlign: TextAlign.center,
                  style: MdyType.size(
                    14,
                    selected ? MdyType.w600 : MdyType.w500,
                  ).copyWith(color: selected ? c.onBrand : c.ink),
                ),
                if (parts.length > 1)
                  Text(
                    parts.skip(1).join(' · '),
                    textAlign: TextAlign.center,
                    style: MdyType.size(
                      11,
                    ).copyWith(color: selected ? c.onBrandMuted : c.secondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `Notice`: thông tin (info) / cảnh báo / lỗi.
class LeaveNotice extends StatelessWidget {
  const LeaveNotice(
    this.text, {
    super.key,
    this.warning = false,
    this.danger = false,
  });
  final String text;
  final bool warning;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    if (warning || danger) return MdyAlert(text, warning: warning);
    final c = context.mdy;
    return Semantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: MdySpace.s12,
          vertical: MdySpace.s10,
        ),
        decoration: BoxDecoration(
          color: c.infoBg,
          borderRadius: BorderRadius.circular(MdyRadius.r12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MdySpace.s8,
          children: [
            MdyIcon(MdyIcons.info, size: 18, color: c.info),
            Expanded(
              child: Text(text, style: MdyType.alert.copyWith(color: c.info)),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaveDivider extends StatelessWidget {
  const LeaveDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.mdy.divider);
}

/// `QueryBlock` của leave.
class LeaveQueryBlock extends ConsumerWidget {
  const LeaveQueryBlock({
    super.key,
    required this.query,
    required this.controller,
    required this.prefix,
    required this.builder,
  });
  final LeaveQueryState query;
  final LeaveQuery controller;
  final String prefix;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final kind = query.result?.kind;
    if (kind == LeaveOutcomeKind.denied || kind == LeaveOutcomeKind.notFound) {
      return MdyCard(
        key: Key(
          '$prefix-${kind == LeaveOutcomeKind.denied ? 'denied' : 'not-found'}',
        ),
        margin: EdgeInsets.zero,
        children: [
          Semantics(liveRegion: true, child: MdyText(t(lv(kind!.name)))),
        ],
      );
    }
    if (query.data == null) {
      if (query.offline) {
        return LeaveNotice(
          t(lv('leave.offlineEmpty')),
          key: Key('$prefix-offline'),
          warning: true,
        );
      }
      if (kind == LeaveOutcomeKind.error) {
        return MdyCard(
          key: Key('$prefix-error'),
          margin: EdgeInsets.zero,
          children: [
            MdyText(t(lv('error'))),
            MdyButton(
              key: Key('$prefix-retry'),
              label: t(lv('retry')),
              onPressed: controller.retry,
            ),
          ],
        );
      }
      return Column(
        key: const Key('leave-loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s12,
        children: [
          for (var i = 0; i < 3; i++)
            MdySkeleton(
              label: t(lv('loading')),
              child: Container(
                height: MdySpace.s120,
                decoration: BoxDecoration(
                  color: c.muted2,
                  borderRadius: BorderRadius.circular(MdyRadius.r14),
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s16,
      children: [
        builder(context),
        if (query.offline)
          LeaveNotice(
            t(lv('leave.stale')),
            key: Key('$prefix-offline'),
            warning: true,
          )
        else if (kind == LeaveOutcomeKind.error && !query.footerError)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s8,
            children: [
              LeaveNotice(
                t(lv('leave.stale')),
                key: Key('$prefix-refresh-alert'),
                warning: true,
              ),
              MdyButton(
                key: Key('$prefix-retry'),
                variant: MdyButtonVariant.text,
                label: t(lv('retry')),
                onPressed: controller.retry,
              ),
            ],
          ),
      ],
    );
  }
}

class LeaveMore extends ConsumerWidget {
  const LeaveMore({
    super.key,
    required this.query,
    required this.controller,
    required this.prefix,
  });
  final LeaveQueryState query;
  final LeaveQuery controller;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.data == null || !query.hasMore) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s8,
      children: [
        if (query.footerError)
          Semantics(liveRegion: true, child: MdyText(t(lv('error')))),
        MdyButton(
          key: Key('$prefix-more'),
          variant: MdyButtonVariant.text,
          busy: query.busy,
          disabled: query.offline,
          label: t(lv(query.footerError ? 'retry' : 'more')),
          onPressed: query.footerError ? controller.retry : controller.more,
        ),
      ],
    );
  }
}

/// Nút lọc dạng pill (`Filters`), có thể thêm `trailing` (nút chọn mentor/lớp).
class LeaveFilters extends StatelessWidget {
  const LeaveFilters({
    super.key,
    required this.prefix,
    required this.options,
    required this.value,
    required this.onChange,
    this.trailing = const [],
  });
  final String prefix;
  final List<({String value, String label})> options;
  final String value;
  final ValueChanged<String> onChange;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        spacing: MdySpace.s8,
        children: [
          for (final o in options)
            Semantics(
              inMutuallyExclusiveGroup: true,
              selected: value == o.value,
              button: true,
              label: o.label,
              excludeSemantics: true,
              child: MdyPressed(
                key: Key('$prefix-filter-${o.value.toLowerCase()}'),
                onTap: () => onChange(o.value),
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.8 : 1,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: MdySpace.s44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MdySpace.s16,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == o.value ? c.primary : c.surface,
                      border: value == o.value
                          ? null
                          : Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(MdyRadius.r99),
                    ),
                    child: Text(
                      o.label,
                      style: value == o.value
                          ? MdyType.size(
                              13,
                              MdyType.w600,
                            ).copyWith(color: c.onBrand)
                          : MdyType.size(13).copyWith(color: c.link),
                    ),
                  ),
                ),
              ),
            ),
          ...trailing,
        ],
      ),
    );
  }
}

/// `OutcomeError`: chưa chắc chắn (gửi lại) hoặc lỗi theo mã.
class LeaveOutcomeError extends ConsumerWidget {
  const LeaveOutcomeError({
    super.key,
    required this.result,
    required this.prefix,
    this.retry,
  });
  final LeaveOutcome? result;
  final String prefix;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final r = result;
    if (r?.kind == LeaveOutcomeKind.uncertain) {
      return Column(
        key: Key('$prefix-intent'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s8,
        children: [
          LeaveNotice(t(lv('unknown')), warning: true),
          MdyButton(
            key: Key('$prefix-resend'),
            label: t(lv('resend')),
            disabled: ref.watch(staffOfflineProvider),
            onPressed: retry,
          ),
        ],
      );
    }
    if (r != null && r.kind == LeaveOutcomeKind.error) {
      final code = r.code ?? 'SERVER';
      final text = t(lv(code)) == lv(code) ? t(lv('SERVER')) : t(lv(code));
      return LeaveNotice(
        r.requestId == null
            ? text
            : '$text · ${t(lv('leave.support'), {'id': r.requestId})}',
        key: Key('$prefix-send-error'),
        danger: true,
      );
    }
    return const SizedBox.shrink();
  }
}

/// `StatusChip`: trạng thái đơn / xung đột.
class LeaveStatusChip extends ConsumerWidget {
  const LeaveStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final variant = switch (status) {
      'PENDING' || 'NEEDS_PLACEMENT' => MdyChipVariant.warning,
      'APPROVED' || 'RESOLVED' => MdyChipVariant.success,
      'REJECTED' || 'NEEDS_REASSIGNMENT' => MdyChipVariant.danger,
      'MAKEUP_ASSIGNED' => MdyChipVariant.info,
      _ => MdyChipVariant.neutral,
    };
    return MdyChip(t(lv(status)), variant: variant);
  }
}

class LeaveDueLine extends ConsumerWidget {
  const LeaveDueLine({super.key, required this.time});
  final String time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Row(
      spacing: MdySpace.s6,
      children: [
        MdyIcon(MdyIcons.schedule, size: 16, color: c.warning),
        Expanded(
          child: Text(
            t(lv('leave.dueAt'), {'time': time}),
            style: MdyType.size(12).copyWith(color: c.warning),
          ),
        ),
      ],
    );
  }
}

/// Ô ngày rộng 44 (thứ + ngày).
class LeaveDayTile extends ConsumerWidget {
  const LeaveDayTile({super.key, required this.value});
  final DateTime value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final day = vietnamDay(value);
    final weekday = DateTime.parse('${day}T00:00:00Z').weekday % 7;
    return Container(
      width: MdySpace.s44,
      padding: const EdgeInsets.symmetric(vertical: MdySpace.s6),
      decoration: BoxDecoration(
        color: c.muted2,
        borderRadius: BorderRadius.circular(MdyRadius.r12),
      ),
      child: Column(
        children: [
          Text(
            t(lv('leave.weekday.$weekday')),
            style: MdyType.size(11).copyWith(color: c.secondary),
          ),
          Text(
            day.substring(8),
            style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
          ),
        ],
      ),
    );
  }
}

/// `DateField`: nút mở lịch chọn một ngày (`YYYY-MM-DD`, từ hôm nay).
class LeaveDateField extends ConsumerWidget {
  const LeaveDateField({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.onChange,
    this.disabled = false,
  });
  final String id;
  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(
          label,
          style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink),
        ),
        MdyButton(
          key: Key(id),
          variant: MdyButtonVariant.secondary,
          disabled: disabled,
          label: value.isNotEmpty ? dateLabel(value) : t(lv('chooseDate')),
          onPressed: () {
            final today = DateTime.parse('${vietnamDay()}T00:00:00Z');
            final current = value.isNotEmpty
                ? DateTime.tryParse('${value}T00:00:00Z') ?? today
                : today;
            showMdySheet<void>(
              context,
              builder: (sheetContext) => MdySheet(
                key: Key('$id-calendar'),
                title: label,
                children: [
                  CalendarDatePicker(
                    key: Key('$id-days'),
                    initialDate: current.isBefore(today) ? today : current,
                    firstDate: today,
                    lastDate: DateTime(9999, 12, 31),
                    onDateChanged: (d) {
                      String two(int v) => v.toString().padLeft(2, '0');
                      onChange('${d.year}-${two(d.month)}-${two(d.day)}');
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Sheet chọn mentor / lớp có ô tìm kiếm (`Picker` trong ListScreens).
class LeavePickerSheet extends ConsumerStatefulWidget {
  const LeavePickerSheet({
    super.key,
    required this.prefix,
    required this.mentor,
    required this.options,
    required this.onPick,
    required this.onClose,
    required this.error,
    required this.retry,
  });
  final String prefix;
  final bool mentor;
  final List<LeaveOption>? options;
  final ValueChanged<String> onPick;
  final VoidCallback onClose;
  final bool error;
  final VoidCallback retry;

  @override
  ConsumerState<LeavePickerSheet> createState() => _PickerState();
}

class _PickerState extends ConsumerState<LeavePickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final kind = widget.mentor ? 'mentor' : 'class';
    final q = _search.text.toLowerCase();
    return MdyInlineSheet(
      key: Key('${widget.prefix}-$kind-sheet'),
      title: t(
        lv(
          widget.mentor
              ? 'leave.queue.mentorSheet'
              : 'makeup.conflicts.classSheet',
        ),
      ),
      onClose: widget.onClose,
      children: [
        _LeaveSearchField(
          id: '${widget.prefix}-$kind-search',
          label: t(
            lv(
              widget.mentor
                  ? 'leave.queue.mentorSearch'
                  : 'makeup.conflicts.classSearch',
            ),
          ),
          controller: _search,
          onChanged: () => setState(() {}),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MdySpace.s8,
              children: [
                for (final item in widget.options ?? const <LeaveOption>[])
                  if (item.name.toLowerCase().contains(q))
                    MdyButton(
                      key: Key('${widget.prefix}-$kind-option-${item.id}'),
                      variant: MdyButtonVariant.secondary,
                      label: item.name,
                      onPressed: () {
                        widget.onPick(item.id);
                        widget.onClose();
                      },
                    ),
                if (widget.error) ...[
                  MdyText(t(lv('error'))),
                  MdyButton(label: t(lv('retry')), onPressed: widget.retry),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveSearchField extends StatelessWidget {
  const _LeaveSearchField({
    required this.id,
    required this.label,
    required this.controller,
    required this.onChanged,
  });
  final String id;
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => LeaveField(
    id: id,
    label: label,
    controller: controller,
    onChanged: (_) => onChanged(),
    multiline: false,
  );
}

/// `Field` của leave: nhãn, ô nhập viền bo 14, đếm ký tự khi có `max`, lỗi.
class LeaveField extends StatelessWidget {
  const LeaveField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.disabled = false,
    this.multiline = false,
    this.max,
    this.error,
    this.focusNode,
    this.hideLabel = false,
  });
  final String id;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool disabled;
  final bool multiline;
  final int? max;
  final String? error;
  final FocusNode? focusNode;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final length = controller.text.length;
    final over = max != null && length > max!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        if (!hideLabel)
          Text(
            label,
            style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink),
          ),
        Semantics(
          label: label,
          hint: error,
          child: TextField(
            key: Key(id),
            controller: controller,
            focusNode: focusNode,
            enabled: !disabled,
            onChanged: onChanged,
            minLines: multiline ? 4 : 1,
            maxLines: multiline ? 8 : 1,
            textAlignVertical: TextAlignVertical.top,
            style: MdyType.size(14).copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.all(MdySpace.s12),
              hintStyle: MdyType.size(14).copyWith(color: c.placeholder),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MdyRadius.r14),
                borderSide: BorderSide(
                  color: error != null || over ? c.dangerBorder : c.border,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MdyRadius.r14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MdyRadius.r14),
                borderSide: BorderSide(
                  color: error != null || over ? c.dangerBorder : c.link,
                ),
              ),
            ),
          ),
        ),
        if (max != null)
          Text(
            '$length/$max',
            textAlign: TextAlign.right,
            style: MdyType.size(
              12,
            ).copyWith(color: over ? c.danger : c.secondary),
          ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: MdyType.size(12).copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}
