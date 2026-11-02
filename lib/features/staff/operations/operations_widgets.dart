import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_logic.dart';
import '../attendance/attendance_widgets.dart';
import '../attendance/manager_attendance_screens.dart';
import '../teaching/teaching_models.dart';
import '../teaching/teaching_widgets.dart';
import 'operations_query.dart';
import 'operations_service.dart';

/// Clone `operations/components/shared.tsx`.
String o(String key) => 'mdy.operations.$key';

/// `Alert` riêng của operations: khung viền (vàng hoặc đỏ) chứa nhiều dòng.
class OpsAlert extends StatelessWidget {
  const OpsAlert({super.key, required this.children, this.warning = false});
  final List<Widget> children;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MdySpace.s12),
        decoration: BoxDecoration(
          color: warning ? c.warningBg : c.dangerBg,
          border: Border.all(color: warning ? c.warning : c.dangerBorder),
          borderRadius: BorderRadius.circular(MdyRadius.r14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: MdySpace.s8, children: children),
      ),
    );
  }
}

/// `QueryState`: skeleton / lỗi / không quyền / nội dung + cảnh báo làm mới.
class OpsQueryBlock extends ConsumerWidget {
  const OpsQueryBlock({super.key, required this.query, required this.controller, required this.prefix, required this.builder});
  final OpsQueryState query;
  final OpsQuery controller;
  final String prefix;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final kind = query.result?.kind;
    if (kind == OpsResultKind.denied || kind == OpsResultKind.notFound) {
      return MdyCard(
        key: Key('$prefix-${kind!.name}'),
        margin: EdgeInsets.zero,
        children: [Semantics(liveRegion: true, child: MdyText(t(o(kind.name))))],
      );
    }
    if (query.data == null) {
      if (query.offline) return MdyAlert(t(o('offlineEmpty')), key: Key('$prefix-offline'), warning: true);
      if (kind == OpsResultKind.error) {
        return MdyCard(
          key: Key('$prefix-error'),
          margin: EdgeInsets.zero,
          children: [
            MdyText(t(o('error'))),
            MdyButton(key: Key('$prefix-retry'), label: t(o('retry')), onPressed: controller.retry),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s12,
        children: [
          for (var i = 0; i < 3; i++)
            MdySkeleton(
              label: t(o('loading')),
              child: Container(
                height: MdySpace.s120,
                decoration: BoxDecoration(color: c.muted2, borderRadius: BorderRadius.circular(MdyRadius.r14)),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        builder(context),
        if (query.offline)
          MdyAlert(t(o('needOnline')), key: Key('$prefix-offline-banner'), warning: true)
        else if (kind == OpsResultKind.error && !query.footerError)
          OpsAlert(
            key: Key('$prefix-refresh-error'),
            warning: true,
            children: [
              MdyText(t(o('cash.refreshFailed'))),
              MdyButton(label: t(o('retry')), onPressed: controller.refresh),
            ],
          ),
      ],
    );
  }
}

/// `More`.
class OpsMore extends ConsumerWidget {
  const OpsMore({super.key, required this.query, required this.controller, required this.prefix});
  final OpsQueryState query;
  final OpsQuery controller;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!query.hasMore) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    return MdyButton(
      key: Key('$prefix-more'),
      variant: MdyButtonVariant.secondary,
      disabled: query.busy || query.offline,
      busy: query.busy,
      label: t(query.footerError ? o('retry') : o('cash.more')),
      onPressed: query.footerError ? controller.retry : controller.more,
    );
  }
}

/// `SessionSummary`: ô ngày + tên buổi + giờ + trạng thái + mentor.
class OpsSessionSummary extends ConsumerWidget {
  const OpsSessionSummary({super.key, required this.session, required this.prefix});
  final TeachingSession session;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final date = isoDate(session.startsAt);
    return MdyCard(
      key: Key('$prefix-summary'),
      margin: EdgeInsets.zero,
      gap: MdySpace.s8,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MdySpace.s12,
          children: [
            Container(
              width: MdySpace.s52,
              padding: const EdgeInsets.all(MdySpace.s8),
              decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(MdyRadius.r14)),
              child: Column(
                children: [
                  Text(date.substring(0, 2), style: MdyType.size(18, MdyType.w600).copyWith(color: c.ink)),
                  Text(date.substring(3, 5), style: MdyType.size(12).copyWith(color: c.ink)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s6,
                children: [
                  Text(session.title, style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink)),
                  Text(
                    '$date · ${isoTime(session.startsAt)}–${isoTime(session.endsAt)}',
                    style: MdyType.size(13).copyWith(color: c.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        TeachingStatusChip(group: 'sessionStatus', value: session.status.name),
        if (session.effectiveMentor != null)
          Text(
            t(o('rescheduleScreen.teacher'), {'name': session.effectiveMentor}),
            style: MdyType.size(13).copyWith(color: c.ink),
          ),
      ],
    );
  }
}

/// `ReasonField`: lý do bắt buộc, tối đa 1000.
class OpsReasonField extends ConsumerWidget {
  const OpsReasonField({
    super.key,
    required this.prefix,
    required this.controller,
    required this.onChanged,
    required this.invalid,
    this.disabled = false,
    this.focusNode,
  });
  final String prefix;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool invalid;
  final bool disabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return AttendanceField(
      id: '$prefix-reason',
      label: '${t(o('reason'))} *',
      controller: controller,
      onChanged: (_) => onChanged(),
      max: 1000,
      error: invalid && controller.text.trim().isEmpty ? t(o('reasonRequired')) : null,
      disabled: disabled,
      focusNode: focusNode,
    );
  }
}

/// `ScheduleFields`: nút chọn ngày (lịch) + giờ bắt đầu / kết thúc.
class OpsScheduleFields extends ConsumerWidget {
  const OpsScheduleFields({
    super.key,
    required this.prefix,
    required this.date,
    required this.start,
    required this.end,
    required this.onDate,
    required this.onChanged,
    required this.disabled,
    this.invalid,
    this.readOnlyEnd = false,
    this.minDate,
    this.maxDate,
  });

  final String prefix;

  /// `DD/MM/YYYY`.
  final String date;
  final TextEditingController start;
  final TextEditingController end;
  final ValueChanged<String> onDate;
  final VoidCallback onChanged;
  final bool disabled;
  final String? invalid;
  final bool readOnlyEnd;

  /// `YYYY-MM-DD`.
  final String? minDate;
  final String? maxDate;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final t = ref.read(trProvider);
    DateTime? parse(String? iso) => iso == null ? null : DateTime.tryParse(iso);
    final current = date.isNotEmpty ? DateTime.tryParse(date.split('/').reversed.join('-')) : parse(minDate);
    final first = parse(minDate) ?? DateTime(2020);
    final last = parse(maxDate) ?? DateTime(2100);
    var initial = current ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    await showMdySheet<void>(
      context,
      builder: (sheetContext) => MdySheet(
        key: Key('$prefix-date-sheet'),
        title: t(o('rescheduleScreen.date')),
        children: [
          CalendarDatePicker(
            initialDate: initial,
            firstDate: first,
            lastDate: last,
            onDateChanged: (d) {
              String two(int v) => v.toString().padLeft(2, '0');
              onDate('${two(d.day)}/${two(d.month)}/${d.year}');
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        MdyButton(
          key: Key('$prefix-date'),
          variant: MdyButtonVariant.secondary,
          disabled: disabled,
          label: date.isEmpty ? t(o('replacement.pickDate')) : date,
          onPressed: () => _pick(context, ref),
        ),
        _OpsTimeField(id: '$prefix-start', label: t(o('rescheduleScreen.start')), controller: start, disabled: disabled, onChanged: onChanged),
        _OpsTimeField(
          id: '$prefix-end',
          label: t(o('rescheduleScreen.end')),
          controller: end,
          disabled: disabled || readOnlyEnd,
          onChanged: onChanged,
        ),
        if (invalid != null)
          Semantics(liveRegion: true, child: Text(invalid!, style: MdyType.text.copyWith(color: c.danger))),
      ],
    );
  }
}

class _OpsTimeField extends StatelessWidget {
  const _OpsTimeField({required this.id, required this.label, required this.controller, required this.disabled, required this.onChanged});
  final String id;
  final String label;
  final TextEditingController controller;
  final bool disabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    OutlineInputBorder border(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(MdyRadius.r14), borderSide: BorderSide(color: color));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(label, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
        TextField(
          key: Key('$id-input'),
          controller: controller,
          enabled: !disabled,
          keyboardType: TextInputType.datetime,
          inputFormatters: [hhmmFormatter],
          onChanged: (_) => onChanged(),
          cursorColor: c.primary,
          style: MdyType.size(14).copyWith(color: c.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: disabled ? c.muted2 : c.surface,
            contentPadding: const EdgeInsets.all(MdySpace.s12),
            enabledBorder: border(c.border),
            focusedBorder: border(c.primary),
            disabledBorder: border(c.border),
          ),
        ),
      ],
    );
  }
}

/// `MutationError`.
class OpsMutationError extends ConsumerWidget {
  const OpsMutationError({super.key, required this.result, required this.prefix});
  final OpsResult? result;
  final String prefix;

  static const _keys = {
    'SESSION_VERSION_CONFLICT': 'versionConflict',
    'SESSION_STATE_CONFLICT': 'stateChanged',
    'CLASS_NOT_EDITABLE': 'classClosed',
    'CLASS_MENTOR_SCHEDULE_CONFLICT': 'substitute.mentorBusy',
    'CLASS_SESSION_OVERLAP': 'overlap',
    'SESSION_HAS_MAKEUP_PLACEMENTS': 'placements',
    'MAKEUP_ALREADY_EXISTS': 'replacement.exists',
    'SESSION_START_NOT_FUTURE': 'startPast',
    'CLASS_SESSION_OUTSIDE_CLASS_PERIOD': 'outsidePeriod',
    'CLASS_SESSION_TIME_RANGE_INVALID': 'timeRange',
    'CLASS_SESSION_OVERNIGHT_NOT_ALLOWED': 'timeRange',
    'CLASS_MENTOR_NOT_ELIGIBLE': 'substitute.ineligible',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    if (r == null || r.success || r.kind == OpsResultKind.uncertain) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    return OpsAlert(
      key: Key('$prefix-mutation-error'),
      children: [
        MdyText(
          t(o(_keys[r.code] ?? 'error')) + (r.requestId == null ? '' : ' · ${t(o('support'), {'id': r.requestId})}'),
        ),
      ],
    );
  }
}

/// `MoneyText`.
class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.large = false});
  final int value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      label: '$value đồng',
      excludeSemantics: true,
      child: Text(
        formatMoney(value),
        style: large
            ? MdyType.size(28, MdyType.w700, 42).copyWith(color: c.link)
            : MdyType.size(15, MdyType.w700).copyWith(color: c.ink),
      ),
    );
  }
}

bool isOrderOverdue(CashOrder order, DateTime asOf) => order.status == OrderStatus.PENDING && !order.expiresAt.isAfter(asOf);

/// `OrderStatusChip`.
class OrderStatusChip extends ConsumerWidget {
  const OrderStatusChip({super.key, required this.order, required this.asOf});
  final CashOrder order;
  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final overdue = isOrderOverdue(order, asOf);
    return MdyChip(
      t(o('status.${overdue ? 'overdue' : order.status.name}')),
      variant: overdue
          ? MdyChipVariant.danger
          : order.status == OrderStatus.PAID
          ? MdyChipVariant.success
          : order.status == OrderStatus.PENDING
          ? MdyChipVariant.warning
          : MdyChipVariant.neutral,
    );
  }
}

/// Dùng lại khung trang của attendance (cùng `Page` bên RN).
typedef OpsPage = AttendancePage;
