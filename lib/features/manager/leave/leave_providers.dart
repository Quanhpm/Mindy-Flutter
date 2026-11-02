import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/receipt_controller.dart';
import '../../../core/session/session_controller.dart';
import 'leave_api.dart';
import 'leave_models.dart';

final managerLeavesProvider = FutureProvider.autoDispose.family<List<ManagerLeave>, ManagerLeaveFilter>((ref, f) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerLeaveApiProvider).list(f, cancel: c);
});
final managerLeaveDetailProvider = FutureProvider.autoDispose.family<ManagerLeaveDetail, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerLeaveApiProvider).detail(id, cancel: c);
});
final managerLeaveCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerLeaveApiProvider).pendingCount(cancel: c);
});
final managerLeaveCommandProvider = NotifierProvider.autoDispose
    .family<ManagerLeaveCommand, CommandState<ManagerLeaveDecision>, String>(ManagerLeaveCommand.new);

class ManagerLeaveCommand extends ReceiptController<ManagerLeaveDecision> {
  ManagerLeaveCommand(this.id);
  final String id;
  String? _action;
  @override
  void resetTarget() => _action = null;
  Future<ManagerLeaveDecision?> decide(
    ManagerLeaveDetail detail, {
    required bool approve,
    required String reason,
    required bool acknowledge,
  }) {
    if (state.locked || state.conflict) return Future.value(null);
    if (detail.header.request.id != id ||
        reason.trim().isEmpty ||
        reason.trim().length > 1000 ||
        (approve && (!detail.canApprove || (detail.conflictCount > 0 && !acknowledge)))) {
      throw ApiError(status: 422, code: 'MANAGER_VALIDATION');
    }
    _action = approve ? 'approve' : 'reject';
    return execute({
      'expectedVersion': detail.header.request.version,
      'reason': reason.trim(),
      if (approve) 'acknowledgeStudentConflicts': acknowledge,
    });
  }

  @override
  Future<ManagerLeaveDecision> send(IdempotentCall call) =>
      ref.read(managerLeaveApiProvider).decide(id, _action!, call);
  @override
  void invalidate(ManagerLeaveDecision r) {
    ref.invalidate(managerLeavesProvider);
    ref.invalidate(managerLeaveDetailProvider(id));
    ref.invalidate(managerLeaveCountProvider);
  }
}
