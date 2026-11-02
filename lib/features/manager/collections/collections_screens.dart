import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/await_provider.dart';
import '../../../core/session/session_controller.dart';
import '../../payment/payment_models.dart';
import '../manager_providers.dart';
import '../manager_widgets.dart';
import 'collections_models.dart';
import 'collections_providers.dart';

class ManagerCollectionsScreen extends ConsumerStatefulWidget {
  const ManagerCollectionsScreen({super.key});
  @override
  ConsumerState<ManagerCollectionsScreen> createState() => _CollectionsState();
}

class _CollectionsState extends ConsumerState<ManagerCollectionsScreen> {
  OrderStatus? _status = OrderStatus.PENDING;
  String _code = '';
  String? _classId;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        q = (status: _status, code: _code, classId: _classId),
        p = managerCollectionsProvider((status: _status, code: _code, classId: _classId));
    final cp = managerClassesProvider((mentorId: null, search: ''));
    final classes = ref.watch(cp);
    return StaffPage(
      title: t('manager.utility.collections'),
      onBack: () => managerBack(context),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(p),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            ManagerSearch(onSearch: (v) => setState(() => _code = v)),
            FilterChipsBar<OrderStatus?>(
              items: [
                (null, t('manager.all')),
                for (final s in OrderStatus.values) (s, t('manager.orderStatus.${s.name}')),
              ],
              selected: _status,
              onSelected: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 12),
            ManagerData(
              value: classes,
              onRetry: () => ref.invalidate(cp),
              data: (rows) => DropdownButton<String>(
                value: _classId,
                isExpanded: true,
                hint: Text(t('manager.allClasses')),
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(t('manager.allClasses'))),
                  for (final c in rows)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
            ),
            ManagerData(
              value: ref.watch(p),
              onRetry: () => ref.invalidate(managerCollectionsProvider(q)),
              data: (rows) => Column(
                children: [
                  if (rows.isEmpty) const ManagerEmpty(),
                  for (final order in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GlassCard(
                        onTap: () => context.push(Routes.managerOrder(order.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.code, style: StaffText.bodyStrong),
                            Text(order.studentName, style: StaffText.body),
                            Text(formatVnd(order.amount), style: StaffText.title),
                            StatusChip(t('manager.orderStatus.${order.status.name}')),
                          ],
                        ),
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

class ManagerOrderScreen extends ConsumerStatefulWidget {
  const ManagerOrderScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ManagerOrderScreen> createState() => _OrderState();
}

class _OrderState extends ConsumerState<ManagerOrderScreen> {
  Future<void> _confirm() async {
    final t = ref.read(trProvider), epoch = ref.read(sessionEpochProvider);
    ref.invalidate(managerOrderProvider(widget.id));
    try {
      final fresh = await awaitWidgetProvider(ref, managerOrderProvider(widget.id).future);
      if (!mounted || ref.read(sessionEpochProvider) != epoch || !fresh.canConfirm) return;
      final amount = await showStaffSheet<int>(
        context,
        title: t('manager.cashConfirm'),
        builder: (_) => SessionSheetGuard(
          child: SessionBoundView(child: _CashConfirm(order: fresh)),
        ),
      );
      if (!mounted || ref.read(sessionEpochProvider) != epoch || amount == null) return;
      await ref.read(managerCashCommandProvider(widget.id).notifier).confirm(amount);
    } catch (e) {
      if (mounted) showStaffToast(context, t(managerErrorKey(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        p = managerOrderProvider(widget.id),
        command = ref.watch(managerCashCommandProvider(widget.id));
    return StaffPage(
      title: t('manager.orderDetail'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          ManagerData(
            value: ref.watch(p),
            onRetry: () => ref.invalidate(p),
            data: (o) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(o.code, style: StaffText.title),
                Text(o.studentName, style: StaffText.bodyStrong),
                StatusChip(t('manager.orderStatus.${o.status.name}')),
                Text(o.type.name, style: StaffText.caption),
                Text(formatVnd(o.amount), style: StaffText.title),
                for (final item in o.details)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GlassCard(
                      child: Text(
                        '${item.courseTitle}\n${item.className}\n${formatVnd(item.amount)}',
                        style: StaffText.body,
                      ),
                    ),
                  ),
                if (o.collector != null) Text(t('manager.collectedBy', {'name': o.collector}), style: StaffText.body),
                if (o.review != null) Text(t('manager.paymentReview'), style: StaffText.bodyStrong),
                if (command.error != null) managerFailure(t, command.error!),
                if (command.result?.status == OrderStatus.PAID)
                  Text(t('manager.cashConfirmed'), style: StaffText.bodyStrong),
                if (command.retryPending || command.conflict) ...[
                  Text(t('manager.cashUnknown'), style: StaffText.caption),
                  StaffButton(
                    label: t('mentor.operations.readLatest'),
                    loading: command.busy,
                    onPressed: () => ref.read(managerCashCommandProvider(widget.id).notifier).check(),
                  ),
                ] else if (o.canConfirm)
                  StaffButton(
                    label: t('manager.cashConfirm'),
                    loading: command.busy,
                    onPressed: command.locked ? null : _confirm,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashConfirm extends ConsumerStatefulWidget {
  const _CashConfirm({required this.order});
  final CollectionOrder order;
  @override
  ConsumerState<_CashConfirm> createState() => _CashConfirmState();
}

class _CashConfirmState extends ConsumerState<_CashConfirm> {
  final _amount = TextEditingController();
  bool _received = false;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), number = int.tryParse(_amount.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.order.code}\n${widget.order.studentName}\n${formatVnd(widget.order.amount)}',
          style: StaffText.bodyStrong,
        ),
        StaffInput(
          label: t('manager.receivedAmount'),
          controller: _amount,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: _received,
            title: Text(t('manager.receivedAcknowledgement'), style: StaffText.body),
            onChanged: (v) => setState(() => _received = v ?? false),
          ),
        ),
        StaffButton(
          label: t('manager.confirm'),
          onPressed: !_received || number != widget.order.amount || number == null || number < 1
              ? null
              : () => Navigator.pop(context, number),
        ),
      ],
    );
  }
}
