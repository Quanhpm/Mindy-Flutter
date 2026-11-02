import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_logic.dart';
import '../attendance/attendance_widgets.dart';
import '../teaching/classes_screens.dart';
import '../teaching/teaching_models.dart';
import 'operations_query.dart';
import 'operations_service.dart';
import 'operations_widgets.dart';
import 'session_operations.dart';

const _statuses = [OrderStatus.PENDING, OrderStatus.PAID, OrderStatus.EXPIRED, OrderStatus.CANCELLED];

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MdySpace.s10,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: MdyType.size(15, MdyType.w600).copyWith(color: context.mdy.ink)),
      ),
      child,
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MdySpace.s16,
        children: [
          Text(label, style: MdyType.size(13).copyWith(color: c.secondary)),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

class _ClassOption extends StatelessWidget {
  const _ClassOption({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: MdyPressed(
        onTap: onTap,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.8 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: MdySpace.s48),
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s10),
            decoration: BoxDecoration(
              color: selected ? c.tint2 : null,
              borderRadius: BorderRadius.circular(MdyRadius.r14),
            ),
            child: Row(
              spacing: MdySpace.s12,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MdyType.text.copyWith(
                      color: selected ? c.link : c.ink,
                      fontWeight: selected ? MdyType.w600 : null,
                    ),
                  ),
                ),
                if (selected) const MdyIcon(MdyIcons.check, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _stamp(DateTime at) => '${isoTime(at)} ${isoDate(at)}';

class _CashOrderRow extends ConsumerWidget {
  const _CashOrderRow({super.key, required this.order, required this.asOf, required this.onTap});
  final CashOrder order;
  final DateTime asOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final name = order.student.name ?? t(o('cash.noName'));
    final overdue = isOrderOverdue(order, asOf);
    final at = order.paidAt ?? order.expiresAt;
    final deadline = order.status == OrderStatus.CANCELLED
        ? ''
        : t(
            o(
              order.status == OrderStatus.PAID
                  ? (order.confirmedBy != null ? 'cash.paidBy' : 'cash.paid')
                  : order.status == OrderStatus.EXPIRED
                  ? 'cash.expiredAt'
                  : 'cash.due',
            ),
            {'time': '${isoTime(at)} ${isoDate(at).substring(0, 5)}', 'name': order.confirmedBy?.name ?? t(o('cash.noName'))},
          );
    return Semantics(
      button: true,
      label: [
        order.orderCode,
        name,
        '${order.totalAmount} đồng',
        t(o('status.${overdue ? 'overdue' : order.status.name}')),
        if (deadline.isNotEmpty) deadline,
      ].join(', '),
      excludeSemantics: true,
      child: MdyPressed(
        key: Key('cash-list-row-${order.id}'),
        onTap: onTap,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.8 : 1,
          child: MdyCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: MdySpace.s16),
            gap: MdySpace.s12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s3,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
                        ),
                        Text(order.orderCode, style: MdyType.size(12).copyWith(color: c.tertiary)),
                      ],
                    ),
                  ),
                  OrderStatusChip(key: Key('cash-list-row-${order.id}-status'), order: order, asOf: asOf),
                ],
              ),
              Container(height: 1, color: c.divider),
              Row(
                spacing: MdySpace.s12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s4,
                      children: [
                        if (deadline.isNotEmpty)
                          Row(
                            spacing: MdySpace.s6,
                            children: [
                              MdyIcon(MdyIcons.schedule, size: 14, color: overdue ? c.danger : null),
                              Flexible(
                                child: Text(
                                  deadline,
                                  key: Key('cash-list-row-${order.id}-deadline'),
                                  style: MdyType.size(13).copyWith(color: overdue ? c.danger : c.secondary),
                                ),
                              ),
                            ],
                          ),
                        Text(
                          t(o('cash.created'), {'date': isoDate(order.createdAt)}),
                          style: MdyType.size(12).copyWith(color: c.tertiary),
                        ),
                      ],
                    ),
                  ),
                  MoneyText(order.totalAmount, key: Key('cash-list-row-${order.id}-amount')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.child, this.onTap, this.enabled = true, this.selected = false}) : semantics = null;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return MdyPressed(
      enabled: enabled && onTap != null,
      onTap: onTap,
      builder: (context, pressed) => Opacity(
        opacity: pressed ? 0.8 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: MdySpace.s44),
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            border: selected ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(MdyRadius.r99),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Clone `CashOrdersScreen`: danh sách đơn tiền mặt (Quản lý).
class StaffCashOrdersScreen extends ConsumerStatefulWidget {
  const StaffCashOrdersScreen({super.key});

  @override
  ConsumerState<StaffCashOrdersScreen> createState() => _CashOrdersState();
}

class _CashOrdersState extends ConsumerState<StaffCashOrdersScreen> {
  OrderStatus _status = OrderStatus.PENDING;
  final _input = TextEditingController(), _classSearch = TextEditingController();
  String _code = '', _classTerm = '', _className = '';
  String? _classId;
  bool _sheet = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _classSearch.dispose();
    super.dispose();
  }

  void _clearClass() => setState(() {
    _classId = null;
    _className = '';
  });

  void _closeSheet() => setState(() {
    _sheet = false;
    _classSearch.clear();
    _classTerm = '';
  });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final request = _code.isNotEmpty
        ? OpsRequest(kind: OpsKind.orders, orderCode: _code)
        : OpsRequest(kind: OpsKind.orders, status: _status.name, classId: _classId);
    final query = ref.watch(opsQueryProvider(request));
    final controller = ref.read(opsQueryProvider(request).notifier);
    final classesRequest = OpsRequest(kind: OpsKind.classes, search: _classTerm);
    final classes = _sheet ? ref.watch(opsQueryProvider(classesRequest)) : null;
    final height = MediaQuery.sizeOf(context).height;
    final locked = _code.isNotEmpty;

    return AttendancePage(
      prefix: 'cash-list',
      title: t(o('cash.title')),
      onBack: () => staffBack(context, manager: true),
      refresh: () async {
        await controller.refresh();
      },
      overlays: [
        if (_sheet)
          MdyInlineSheet(
            key: const Key('cash-list-class-sheet'),
            title: t(o('cash.pickClass')),
            onClose: _closeSheet,
            children: [
              AttendanceField(
                id: 'cash-list-class-search',
                label: t(o('cash.searchClass')),
                controller: _classSearch,
                multiline: false,
                onChanged: (v) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _classTerm = v.trim());
                  });
                },
              ),
              ConstrainedBox(
                key: const Key('cash-list-class-list'),
                constraints: BoxConstraints(maxHeight: height * 0.5),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                  child: classes == null
                      ? const SizedBox.shrink()
                      : OpsQueryBlock(
                          query: classes,
                          controller: ref.read(opsQueryProvider(classesRequest).notifier),
                          prefix: 'cash-list-classes',
                          builder: (_) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: MdySpace.s4,
                            children: [
                              if (_classSearch.text.trim().isEmpty)
                                _ClassOption(
                                  key: const Key('cash-list-class-all'),
                                  label: t(o('cash.allClasses')),
                                  selected: _classId == null,
                                  onTap: () {
                                    _clearClass();
                                    _closeSheet();
                                  },
                                ),
                              for (final item in classes.data?.classes ?? const <OpsClassInfo>[])
                                _ClassOption(
                                  key: Key('cash-list-class-${item.id}'),
                                  label: item.name,
                                  selected: item.id == _classId,
                                  onTap: () {
                                    setState(() {
                                      _classId = item.id;
                                      _className = item.name;
                                    });
                                    _closeSheet();
                                  },
                                ),
                              if (classes.data?.total == 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: MdySpace.s12),
                                  child: Text(
                                    t(o('cash.noClasses')),
                                    key: const Key('cash-list-classes-empty'),
                                    textAlign: TextAlign.center,
                                    style: MdyType.size(13).copyWith(color: c.secondary),
                                  ),
                                ),
                              OpsMore(
                                query: classes,
                                controller: ref.read(opsQueryProvider(classesRequest).notifier),
                                prefix: 'cash-list-classes',
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s12,
          children: [
            Container(
              padding: const EdgeInsets.only(left: MdySpace.s16, right: MdySpace.s4),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(MdyRadius.r99),
              ),
              child: Row(
                spacing: MdySpace.s8,
                children: [
                  const MdyIcon(MdyIcons.search, size: 18),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: MdySpace.s52),
                      child: TextField(
                        key: const Key('cash-list-search'),
                        controller: _input,
                        enabled: !query.offline,
                        maxLength: 50,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        inputFormatters: [_UpperCase()],
                        style: MdyType.size(14).copyWith(color: c.ink),
                        decoration: InputDecoration(
                          hintText: t(o('cash.search')),
                          hintStyle: MdyType.size(14).copyWith(color: c.placeholder),
                          border: InputBorder.none,
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: MdySpace.s16),
                        ),
                        onChanged: (v) => setState(() {
                          if (v.isEmpty) _code = '';
                        }),
                        onSubmitted: (v) => setState(() => _code = v.trim().toUpperCase()),
                      ),
                    ),
                  ),
                  if (_input.text.isNotEmpty)
                    Semantics(
                      button: true,
                      label: t(o('cash.clearSearch')),
                      excludeSemantics: true,
                      child: MdyPressed(
                        key: const Key('cash-list-search-clear'),
                        onTap: () => setState(() {
                          _input.clear();
                          _code = '';
                        }),
                        builder: (context, _) => const SizedBox(
                          width: MdySpace.s44,
                          height: MdySpace.s44,
                          child: Center(child: MdyIcon(MdyIcons.close, size: 18)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Opacity(
                opacity: locked ? 0.5 : 1,
                child: Row(
                  spacing: MdySpace.s8,
                  children: [
                    for (final value in _statuses)
                      Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: _status == value,
                        enabled: !locked,
                        child: _Pill(
                          key: Key('cash-list-status-${value.name.toLowerCase()}'),
                          enabled: !locked,
                          selected: _status == value,
                          onTap: () => setState(() => _status = value),
                          child: Text(
                            t(o('status.${value.name}')),
                            style: _status == value
                                ? MdyType.size(13, MdyType.w600).copyWith(color: c.onBrand)
                                : MdyType.size(13).copyWith(color: c.link),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Opacity(
              opacity: locked || query.offline ? 0.5 : 1,
              child: Row(
                spacing: MdySpace.s8,
                children: [
                  Flexible(
                    child: Semantics(
                      button: true,
                      enabled: !(locked || query.offline),
                      child: _Pill(
                        key: const Key('cash-list-class'),
                        enabled: !(locked || query.offline),
                        onTap: () => setState(() => _sheet = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: MdySpace.s6,
                          children: [
                            const MdyIcon(MdyIcons.school, size: 16),
                            Flexible(
                              child: Text(
                                _className.isNotEmpty ? _className : t(o('cash.allClasses')),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MdyType.size(13).copyWith(color: c.link),
                              ),
                            ),
                            const MdyIcon(MdyIcons.expandMore, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_classId != null)
                    Semantics(
                      button: true,
                      label: t(o('cash.clearClass')),
                      excludeSemantics: true,
                      child: MdyPressed(
                        key: const Key('cash-list-class-clear'),
                        enabled: !locked,
                        onTap: _clearClass,
                        builder: (context, _) => const SizedBox(
                          width: MdySpace.s44,
                          height: MdySpace.s44,
                          child: Center(child: MdyIcon(MdyIcons.close, size: 18)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        OpsQueryBlock(
          query: query,
          controller: controller,
          prefix: 'cash-list',
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MdySpace.s12,
            children: [
              Text(
                t(o('cash.count'), {'count': query.data?.total}),
                key: const Key('cash-list-count'),
                style: MdyType.size(12, MdyType.w600).copyWith(color: c.secondary),
              ),
              for (final order in query.data?.orders ?? const <CashOrder>[])
                _CashOrderRow(
                  key: ValueKey(order.id),
                  order: order,
                  asOf: query.data!.asOf,
                  onTap: () => context.push(StaffOpsRoutes.cashOrder(order.id, code: order.orderCode)),
                ),
              if (query.data?.total == 0)
                MdyCard(
                  key: Key(_code.isNotEmpty ? 'cash-list-not-found' : 'cash-list-empty'),
                  center: true,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s24),
                  gap: MdySpace.s12,
                  children: [
                    const MdyCircleIcon(MdyIcons.receiptLong),
                    Text(
                      t(
                        o(
                          _code.isNotEmpty
                              ? 'cash.notFound'
                              : _status == OrderStatus.PENDING
                              ? 'cash.emptyPending'
                              : 'cash.empty',
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: MdyType.size(14).copyWith(color: c.secondary),
                    ),
                    if (_code.isEmpty && _classId != null)
                      MdyButton(
                        key: const Key('cash-list-empty-clear-class'),
                        variant: MdyButtonVariant.text,
                        size: MdyButtonSize.sm,
                        label: t(o('cash.clearClass')),
                        onPressed: _clearClass,
                      ),
                  ],
                ),
              OpsMore(query: query, controller: controller, prefix: 'cash-list'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Nhóm số tiền: `1234567` → `1.234.567` (tối đa 16 chữ số).
String _groupMoney(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 16) digits = digits.substring(0, 16);
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

/// Clone `CashOrderDetailScreen`: xác nhận đã thu tiền mặt.
class StaffCashOrderDetailScreen extends ConsumerStatefulWidget {
  const StaffCashOrderDetailScreen({super.key, required this.orderId, this.orderCode});
  final String orderId;
  final String? orderCode;

  @override
  ConsumerState<StaffCashOrderDetailScreen> createState() => _CashOrderDetailState();
}

class _CashOrderDetailState extends ConsumerState<StaffCashOrderDetailScreen> {
  ({CashOrder order, DateTime asOf})? _snapshot;
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  bool _sheet = false, _invalid = false, _busy = false, _unknown = false;
  bool _retryAllowed = false, _collectorUnknown = false;
  String _notice = '';
  OpsResultKind? _fatal;
  bool _pending = false;
  int? _received;

  OpsRequest get _request => OpsRequest(kind: OpsKind.order, id: widget.orderId);

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _clearDenied(OpsResult? value) {
    if (value?.kind == OpsResultKind.denied || value?.kind == OpsResultKind.notFound) {
      setState(() {
        _fatal = value!.kind;
        _snapshot = null;
        _amount.clear();
        _sheet = false;
        _unknown = false;
      });
    }
  }

  Future<({CashOrder order, DateTime asOf})?> _read() async {
    final result = await ref.read(operationsServiceProvider).read(_request);
    if (!mounted) return null;
    _clearDenied(result);
    final order = result.data?.order;
    if (result.success && order != null) {
      final value = (order: order, asOf: result.data!.asOf);
      setState(() => _snapshot = value);
      return value;
    }
    return null;
  }

  Future<void> _reconcile({CashOrder? fallback, bool fromUnknown = false}) async {
    final t = ref.read(trProvider);
    setState(() => _retryAllowed = false);
    final before = _snapshot;
    final current = await _read();
    if (!mounted) return;
    if (current == null) {
      setState(() {
        if (fallback?.status == OrderStatus.PAID) {
          _snapshot = (order: fallback!, asOf: before?.asOf ?? DateTime.now());
          _collectorUnknown = true;
          _sheet = false;
          _unknown = false;
          _amount.clear();
        } else {
          _unknown = true;
        }
      });
      return;
    }
    if (current.order.status == OrderStatus.PAID) {
      ref.read(opsRevisionProvider.notifier).bump();
      setState(() {
        _unknown = false;
        _sheet = false;
        _amount.clear();
      });
      final by = current.order.confirmedBy;
      if (by == null) {
        setState(() => _collectorUnknown = true);
      } else if (by.id == ref.read(sessionProvider).user?.id) {
        setState(() => _notice = '');
        ref
            .read(mdyToastProvider.notifier)
            .show(
              t(o(fromUnknown ? 'cashDetail.recorded' : 'cashDetail.done'), {'amount': formatMoney(current.order.totalAmount)}),
            );
      } else {
        setState(() => _notice = 'cashDetail.alreadyByOther');
      }
    } else if (canCollect(current.order, current.asOf)) {
      setState(() {
        _unknown = true;
        _retryAllowed = true;
      });
    } else {
      setState(() {
        _sheet = false;
        _unknown = false;
        _amount.clear();
      });
    }
  }

  Future<void> _open(bool offline) async {
    if (_pending || offline) return;
    _pending = true;
    setState(() {
      _busy = true;
      _notice = '';
    });
    final total = _snapshot?.order.totalAmount;
    final current = await _read();
    if (mounted) {
      setState(() {
        if (current == null) {
          _notice = 'cashDetail.notChecked';
        } else if (!canCollect(current.order, current.asOf) || current.order.totalAmount != total) {
          _notice = 'cashDetail.changed';
        } else {
          _amount.clear();
          _invalid = false;
          _sheet = true;
          _unknown = false;
        }
        _busy = false;
      });
    }
    _pending = false;
  }

  Future<void> _collect(bool offline, {bool retry = false}) async {
    final order = _snapshot?.order;
    if (order == null || _pending || offline || _fatal != null) return;
    final value = retry ? _received : moneyValue(_amount.text);
    if (value == null || value == 0 || value != order.totalAmount) {
      setState(() => _invalid = true);
      _amountFocus.requestFocus();
      return;
    }
    _pending = true;
    setState(() {
      _busy = true;
      _retryAllowed = false;
    });
    _received = value;
    final result = await ref
        .read(operationsServiceProvider)
        .write(OpsMutation(kind: OpsMutationKind.collect, id: order.id, receivedAmount: value));
    if (!mounted) {
      _pending = false;
      return;
    }
    _clearDenied(result);
    if (result.success) {
      await _reconcile(fallback: result.data?.order);
    } else if (result.kind == OpsResultKind.uncertain) {
      setState(() => _unknown = true);
      await _reconcile(fromUnknown: true);
    } else if (result.kind != OpsResultKind.denied && result.kind != OpsResultKind.notFound) {
      final current = await _read();
      if (mounted) {
        setState(() {
          if (result.code == 'CASH_CONFIRMATION_INVALID') {
            _amount.clear();
            final paid = current?.order.status == OrderStatus.PAID;
            _notice = paid ? 'cashDetail.paidMismatch' : 'cashDetail.amountInvalid';
            if (paid) _sheet = false;
          } else {
            _sheet = false;
            _amount.clear();
            _notice = switch (result.code) {
              'CASH_HOLD_INVALID' => 'cashDetail.holdInvalid',
              'CASH_ORDER_CLOSED' => 'cashDetail.closed',
              _ => 'error',
            };
          }
        });
      }
    }
    if (mounted) setState(() => _busy = false);
    _pending = false;
  }

  Future<void> _recheck(bool offline) async {
    if (_pending || offline) return;
    _pending = true;
    setState(() => _busy = true);
    await _reconcile(fromUnknown: true);
    if (mounted) setState(() => _busy = false);
    _pending = false;
  }

  void _close() {
    if (!_busy && !_unknown) {
      setState(() {
        _sheet = false;
        _amount.clear();
      });
    }
  }

  static String _noticeKey(String notice) => switch (notice) {
    'cashDetail.alreadyByOther' => 'cash-detail-by-other',
    'cashDetail.notChecked' => 'cash-detail-not-checked',
    'cashDetail.changed' => 'cash-detail-changed',
    'cashDetail.closed' => 'cash-detail-closed',
    'cashDetail.holdInvalid' => 'cash-detail-hold-invalid',
    'cashDetail.paidMismatch' => 'cash-detail-paid-mismatch',
    _ => 'cash-detail-amount-invalid',
  };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(opsQueryProvider(_request));
    final controller = ref.read(opsQueryProvider(_request).notifier);
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    ref.listen(opsQueryProvider(_request), (prev, next) {
      final order = next.data?.order;
      if (order != null && !_pending && !identical(prev?.data, next.data)) {
        setState(() => _snapshot = (order: order, asOf: next.data!.asOf));
      }
      if (prev?.result?.kind != next.result?.kind) _clearDenied(next.result);
      if (prev?.offline == true && !next.offline && _unknown) _recheck(false);
    });
    final order = _snapshot?.order ?? query.data?.order;
    final asOf = _snapshot?.asOf ?? query.data?.asOf ?? DateTime.now();
    final offline = query.offline;
    final available = order != null && canCollect(order, asOf);
    final error = const [OpsResultKind.error, OpsResultKind.denied, OpsResultKind.notFound].contains(query.result?.kind);
    final collector = order?.confirmedBy;
    final overdue = order != null && isOrderOverdue(order, asOf);
    final dangerNotice = const ['cashDetail.closed', 'cashDetail.holdInvalid', 'cashDetail.paidMismatch'].contains(_notice);
    final noName = t(o('cash.noName'));

    return AttendancePage(
      prefix: 'cash-detail',
      title: t(o('cashDetail.title')),
      subtitle: widget.orderCode ?? order?.orderCode,
      onBack: () => staffBack(context, manager: true),
      dirty: _amount.text.isNotEmpty,
      busy: _busy,
      uncertain: _unknown,
      refresh: () async {
        await controller.refresh();
      },
      footer: _fatal == null && available && !dangerNotice && !_unknown && !_sheet
          ? [
              MdyButton(
                key: const Key('cash-detail-confirm'),
                disabled: offline || error || _busy,
                busy: _busy,
                label: t(o('cashDetail.confirm')),
                onPressed: () => _open(offline),
              ),
            ]
          : null,
      overlays: [
        if (_sheet && order != null && _fatal == null)
          MdyInlineSheet(
            key: const Key('cash-detail-sheet'),
            title: t(o('cashDetail.sheetTitle')),
            busy: _busy || _unknown,
            onClose: _close,
            children: [
              MdyText(order.orderCode),
              MoneyText(order.totalAmount, key: const Key('cash-detail-sheet-amount'), large: true),
              MdyText(order.student.name ?? noName),
              MdyText(order.details.map((d) => d.className).join(', ')),
              AttendanceField(
                id: 'cash-detail-received',
                label: t(o('cashDetail.received')),
                controller: _amount,
                focusNode: _amountFocus,
                keyboardType: TextInputType.number,
                multiline: false,
                disabled: _busy || _unknown,
                onChanged: (v) {
                  final grouped = _groupMoney(v);
                  if (grouped != v) {
                    _amount.value = TextEditingValue(text: grouped, selection: TextSelection.collapsed(offset: grouped.length));
                  }
                  setState(() => _invalid = false);
                },
                error: _invalid ? t(o('cashDetail.mismatch'), {'total': formatMoney(order.totalAmount)}) : null,
              ),
              Text(t(o('cashDetail.fullOnly')), style: MdyType.size(12).copyWith(color: c.secondary)),
              if (_unknown)
                OpsAlert(
                  key: const Key('cash-detail-unknown'),
                  warning: true,
                  children: [
                    Semantics(liveRegion: true, child: MdyText(t(o('cashDetail.unknown')))),
                    if (!offline)
                      MdyButton(
                        key: Key(_retryAllowed ? 'cash-detail-resend' : 'cash-detail-recheck'),
                        disabled: _busy,
                        busy: _busy,
                        label: t(o(_retryAllowed ? 'cashDetail.resend' : 'cashDetail.recheck')),
                        onPressed: () => _retryAllowed ? _collect(offline, retry: true) : _recheck(offline),
                      ),
                  ],
                )
              else
                MdyButton(
                  key: const Key('cash-detail-submit'),
                  busy: _busy,
                  disabled: _amount.text.isEmpty || _busy || offline,
                  label: t(o('cashDetail.confirm')),
                  onPressed: () => _collect(offline),
                ),
              MdyButton(
                key: const Key('cash-detail-sheet-back'),
                variant: MdyButtonVariant.text,
                disabled: _busy || _unknown,
                label: t(o('cashDetail.back')),
                onPressed: _close,
              ),
            ],
          ),
      ],
      children: [
        if (_fatal != null)
          MdyCard(
            key: Key(_fatal == OpsResultKind.denied ? 'cash-detail-denied' : 'cash-detail-not-found'),
            margin: EdgeInsets.zero,
            children: [MdyText(t(o(_fatal!.name)))],
          )
        else
          OpsQueryBlock(
            query: query,
            controller: controller,
            prefix: 'cash-detail',
            builder: (_) {
              if (order == null) return const SizedBox.shrink();
              if (order.paymentType != PaymentMethod.CASH) {
                return MdyCard(
                  key: const Key('cash-detail-not-cash'),
                  margin: EdgeInsets.zero,
                  children: [MdyText(t(o('cashDetail.notCash')))],
                );
              }
              final at = order.paidAt ?? order.expiresAt;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s20,
                children: [
                  if (_notice.isNotEmpty)
                    OpsAlert(
                      key: Key(_noticeKey(_notice)),
                      warning: !dangerNotice,
                      children: [
                        MdyText(
                          t(o(_notice), {
                            'name': collector?.name ?? noName,
                            'time': order.paidAt == null ? '' : _stamp(order.paidAt!),
                          }),
                        ),
                        if (dangerNotice) MdyText(t(o('cashDetail.tellOwner'))),
                      ],
                    ),
                  MdyCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(MdySpace.s20),
                    gap: MdySpace.s12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: MdySpace.s4,
                        children: [
                          Row(
                            spacing: MdySpace.s12,
                            children: [
                              Expanded(
                                child: Text(
                                  t(
                                    o(
                                      order.status == OrderStatus.PAID
                                          ? 'cashDetail.collected'
                                          : available
                                          ? 'cashDetail.due'
                                          : 'cashDetail.amount',
                                    ),
                                  ),
                                  style: MdyType.size(13).copyWith(color: c.secondary),
                                ),
                              ),
                              OrderStatusChip(key: const Key('cash-detail-status'), order: order, asOf: asOf),
                            ],
                          ),
                          MoneyText(order.totalAmount, key: const Key('cash-detail-amount'), large: true),
                        ],
                      ),
                      Container(height: 1, color: c.divider),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: MdySpace.s6,
                        children: [
                          MdyIcon(MdyIcons.schedule, size: 14, color: overdue ? c.danger : null),
                          Flexible(
                            child: Text(
                              t(
                                o(switch (order.status) {
                                  OrderStatus.CANCELLED => 'cashDetail.cancelled',
                                  OrderStatus.EXPIRED => 'cashDetail.expired',
                                  OrderStatus.PAID => 'cashDetail.paidAt',
                                  _ => available ? 'cashDetail.holdUntil' : 'cashDetail.holdPassed',
                                }),
                                {'time': _stamp(at)},
                              ),
                              key: const Key('cash-detail-deadline'),
                              style: MdyType.size(13).copyWith(color: overdue ? c.danger : c.secondary),
                            ),
                          ),
                        ],
                      ),
                      if (order.status == OrderStatus.PAID && collector != null)
                        Text(
                          t(
                            o(
                              collector.source == CollectorSource.LEGACY_MENTOR
                                  ? 'cashDetail.byLegacy'
                                  : collector.id == userId
                                  ? 'cashDetail.byMe'
                                  : 'cashDetail.byOther',
                            ),
                            {'name': collector.name ?? noName},
                          ),
                          key: const Key('cash-detail-collector'),
                          style: MdyType.size(13).copyWith(color: c.ink),
                        ),
                      if (_collectorUnknown) ...[
                        Text(t(o('cashDetail.collectorUnknown')), style: MdyType.size(13).copyWith(color: c.ink)),
                        if (!offline)
                          MdyButton(
                            key: const Key('cash-detail-collector-retry'),
                            variant: MdyButtonVariant.secondary,
                            label: t(o('retry')),
                            onPressed: () async {
                              final current = await _read();
                              if (mounted && current?.order.confirmedBy != null) setState(() => _collectorUnknown = false);
                            },
                          ),
                      ],
                    ],
                  ),
                  _DetailSection(
                    title: t(o('cashDetail.student')),
                    child: MdyCard(
                      key: const Key('cash-detail-student'),
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: MdySpace.s16),
                      children: [
                        Row(
                          spacing: MdySpace.s12,
                          children: [
                            MdyAvatar(name: order.student.name ?? noName, size: 40),
                            Expanded(
                              child: Text(
                                order.student.name ?? noName,
                                style: MdyType.size(15, MdyType.w500).copyWith(color: c.ink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _DetailSection(
                    title: t(o('cashDetail.classes'), {'count': order.details.length}),
                    child: MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: MdySpace.s16),
                      gap: MdySpace.s12,
                      children: [
                        for (final (index, line) in order.details.indexed)
                          Container(
                            key: Key('cash-detail-line-${line.id}'),
                            padding: index > 0 ? const EdgeInsets.only(top: MdySpace.s12) : EdgeInsets.zero,
                            decoration: index > 0 ? BoxDecoration(border: Border(top: BorderSide(color: c.divider))) : null,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: MdySpace.s12,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: MdySpace.s3,
                                    children: [
                                      Text(line.courseTitle, style: MdyType.text.copyWith(fontWeight: MdyType.w600, color: c.ink)),
                                      Text(line.className, style: MdyType.size(13).copyWith(color: c.secondary)),
                                      if (line.quantity > 1)
                                        Text(
                                          t(o('cashDetail.lineQty'), {
                                            'quantity': line.quantity,
                                            'price': formatMoney(line.priceAmount),
                                          }),
                                          key: Key('cash-detail-line-${line.id}-qty'),
                                          style: MdyType.size(12).copyWith(color: c.tertiary),
                                        ),
                                    ],
                                  ),
                                ),
                                MoneyText(line.totalAmount, key: Key('cash-detail-line-${line.id}-amount')),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _DetailSection(
                    title: t(o('cashDetail.info')),
                    child: MdyCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: MdySpace.s16),
                      gap: MdySpace.s12,
                      children: [
                        _InfoRow(key: const Key('cash-detail-code'), label: t(o('cashDetail.code')), value: order.orderCode),
                        _InfoRow(label: t(o('cashDetail.method')), value: t(o('cashDetail.cash'))),
                        _InfoRow(
                          key: const Key('cash-detail-created'),
                          label: t(o('cashDetail.createdAt')),
                          value: _stamp(order.createdAt),
                        ),
                      ],
                    ),
                  ),
                  if (offline)
                    Text(
                      t(o('cashDetail.stale')),
                      key: const Key('cash-detail-stale'),
                      style: MdyType.size(12).copyWith(color: c.secondary),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
