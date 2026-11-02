import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/i18n.dart';
import '../../core/network/api_error.dart';
import '../../core/router/routes.dart';
import '../../core/ui/session_sheet_guard.dart';
import '../../core/ui/staff/staff_data_state.dart';
import '../../core/ui/staff/staff_theme.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../../core/ui/staff/staff_input.dart';
import '../../core/ui/states.dart';

export '../../core/i18n/i18n.dart';
export '../../core/router/routes.dart';
export '../../core/ui/session_sheet_guard.dart';
export '../../core/ui/staff/staff_data_state.dart';
export '../../core/ui/staff/staff_theme.dart';
export '../../core/ui/staff/staff_widgets.dart';
export '../../core/ui/staff/staff_input.dart';
export '../../core/ui/staff/staff_text_area.dart';
export '../../core/ui/staff/draft_guard.dart';
export '../../core/utils/format.dart';

String managerErrorKey(Object error) {
  if (error is! ApiError) return errorKey(error);
  const codes = {
    'MANAGER_VALIDATION',
    'LEAVE_FORBIDDEN',
    'LEAVE_REQUEST_STALE',
    'LEAVE_VERSION_CONFLICT',
    'LEAVE_STATE_CONFLICT',
    'LEAVE_REQUEST_EXPIRED',
    'LEAVE_STUDENT_CONFLICT_ACK_REQUIRED',
    'LEAVE_STUDENT_CONFLICT',
    'LEAVE_TARGET_CONFLICT',
    'SESSION_HAS_MAKEUP_PLACEMENTS',
    'LEAVE_MENTOR_INACTIVE',
    'IDEMPOTENCY_KEY_REUSED',
    'CASH_CONFIRMATION_INVALID',
    'CASH_ORDER_CLOSED',
    'CASH_HOLD_INVALID',
    'MANAGER_UNKNOWN',
    'MANAGER_READ_FIRST',
    'MATERIAL_REVISION_CONFLICT',
    'MATERIAL_REVIEW_CONFLICT',
    'MATERIAL_CONTENT_INVALID',
    'MATERIAL_CONTENT_TOO_LARGE',
    'MATERIAL_ACCESS_DENIED',
    'MATERIAL_SCOPE_MISMATCH',
    'SESSION_VERSION_CONFLICT',
    'CLASS_ASSIGNMENT_VERSION_CONFLICT',
    'MAKEUP_VERSION_CONFLICT',
    'MAKEUP_ALREADY_ASSIGNED',
    'MAKEUP_TARGET_UNAVAILABLE',
    'MAKEUP_TARGET_ENROLLED',
    'MENTOR_SCHEDULE_CONFLICT',
  };
  return codes.contains(error.code) ? 'manager.errors.${error.code}' : errorKey(error);
}

class ManagerData<T> extends ConsumerWidget {
  const ManagerData({super.key, required this.value, required this.onRetry, required this.data});
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 120)),
      error: (e, _) =>
          StaffDataState(title: t('manager.failed'), description: t(managerErrorKey(e)), error: e, onRetry: onRetry),
      data: data,
    );
  }
}

class ManagerEmpty extends ConsumerWidget {
  const ManagerEmpty({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => StaffDataState(
    title: ref.watch(trProvider)('manager.empty'),
    description: ref.watch(trProvider)('manager.emptyDescription'),
  );
}

Widget managerFailure(Translator t, Object error) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: StaffDataState(title: t('manager.failed'), description: t(managerErrorKey(error)), error: error),
);
void managerBack(BuildContext context) => context.canPop() ? context.pop() : context.go(Routes.manager);

class ManagerReason {
  const ManagerReason(this.reason, this.acknowledge);
  final String reason;
  final bool acknowledge;
}

Future<ManagerReason?> managerConfirm(
  BuildContext context, {
  required String title,
  required String description,
  String? acknowledgement,
  bool reason = true,
  int reasonMax = 1000,
}) => showStaffSheet<ManagerReason>(
  context,
  title: title,
  builder: (_) => SessionSheetGuard(
    child: SessionBoundView(
      child: _Confirm(description: description, ack: acknowledgement, reason: reason, max: reasonMax),
    ),
  ),
);

class _Confirm extends ConsumerStatefulWidget {
  const _Confirm({required this.description, this.ack, required this.reason, this.max = 1000});
  final String description;
  final String? ack;
  final bool reason;
  final int max;
  @override
  ConsumerState<_Confirm> createState() => _ConfirmState();
}

class _ConfirmState extends ConsumerState<_Confirm> {
  final _reason = TextEditingController();
  bool _ack = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.description, style: StaffText.body),
        const SizedBox(height: 12),
        if (widget.reason)
          StaffInput(label: t('manager.reason'), controller: _reason, onChanged: (_) => setState(() {})),
        if (widget.ack != null)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _ack,
              title: Text(widget.ack!, style: StaffText.body),
              onChanged: (v) => setState(() => _ack = v ?? false),
            ),
          ),
        StaffButton(
          label: t('manager.confirm'),
          onPressed:
              (widget.reason && (_reason.text.trim().isEmpty || _reason.text.trim().length > widget.max)) ||
                  (widget.ack != null && !_ack)
              ? null
              : () => Navigator.pop(context, ManagerReason(_reason.text.trim(), _ack)),
        ),
      ],
    );
  }
}

class ManagerSearch extends ConsumerStatefulWidget {
  const ManagerSearch({super.key, required this.onSearch, this.initial = ''});
  final ValueChanged<String> onSearch;
  final String initial;
  @override
  ConsumerState<ManagerSearch> createState() => _ManagerSearchState();
}

class _ManagerSearchState extends ConsumerState<ManagerSearch> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: StaffInput(label: ref.watch(trProvider)('manager.search'), controller: _c, onSubmitted: widget.onSearch),
      ),
      IconButton(
        tooltip: ref.watch(trProvider)('manager.search'),
        onPressed: () => widget.onSearch(_c.text.trim()),
        icon: const Icon(Icons.search),
      ),
    ],
  );
}
