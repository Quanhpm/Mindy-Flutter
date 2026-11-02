import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/receipt_controller.dart';
import '../../../core/session/session_controller.dart';
import '../manager_providers.dart';
import 'operations_api.dart';
import 'operations_models.dart';

final managerTimetableProvider = FutureProvider.autoDispose.family<ManagedTimetable, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).timetable(id, cancel: c);
});
final managerCandidatesProvider = FutureProvider.autoDispose.family<AvailableMentors, AssignmentTarget>((ref, t) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).candidates(t, cancel: c);
});
final managerIncompleteProvider = FutureProvider.autoDispose
    .family<List<IncompleteTeaching>, ({String? classId, String? issue})>((ref, q) {
      ref.watch(sessionEpochProvider);
      final c = CancelToken();
      ref.onDispose(c.cancel);
      return ref.watch(managerOperationsApiProvider).incomplete(classId: q.classId, issue: q.issue, cancel: c);
    });
final managerReportProvider = FutureProvider.autoDispose.family<List<ManagerAttendanceRow>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).report(id, cancel: c);
});
final managerAuditsProvider = FutureProvider.autoDispose.family<List<ManagerAttendanceAudit>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).audits(id, cancel: c);
});
final managerConflictsProvider = FutureProvider.autoDispose.family<List<MakeupConflict>, MakeupConflictStatus?>((
  ref,
  s,
) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).conflicts(status: s, cancel: c);
});
final managerConflictProvider = FutureProvider.autoDispose.family<MakeupConflict, String>((ref, id) async {
  final rows = await ref.watch(managerConflictsProvider(null).future);
  return rows.firstWhere((r) => r.id == id, orElse: () => throw ApiError(status: 404, code: 'CONFLICT_NOT_FOUND'));
});
final managerMakeupCandidatesProvider = FutureProvider.autoDispose.family<List<MakeupCandidate>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerOperationsApiProvider).makeupCandidates(id, cancel: c);
});
final managerAssignmentProvider = NotifierProvider.autoDispose
    .family<ManagerAssignmentCommand, CommandState<AssignmentResult>, AssignmentTarget>(ManagerAssignmentCommand.new);

class ManagerAssignmentCommand extends ReceiptController<AssignmentResult> {
  ManagerAssignmentCommand(this.target);
  final AssignmentTarget target;
  Future<AssignmentResult?> assign({required int version, required String? mentorId, required String reason}) {
    if (reason.trim().isEmpty || reason.trim().length > 1000 || version < 1 || (!target.session && mentorId == null)) {
      throw ApiError(status: 422, code: 'MANAGER_VALIDATION');
    }
    return execute({'expectedVersion': version, 'mentorId': mentorId, 'reason': reason.trim()});
  }

  @override
  Future<AssignmentResult> send(IdempotentCall c) => ref.read(managerOperationsApiProvider).assign(target, c);
  @override
  void invalidate(AssignmentResult r) {
    ref.invalidate(managerCandidatesProvider(target));
    ref.invalidate(managerTimetableProvider);
    ref.invalidate(managerClassesProvider);
    ref.invalidate(managerClassDetailProvider);
  }
}

final managerMakeupCommandProvider = NotifierProvider.autoDispose
    .family<ManagerMakeupCommand, CommandState<MakeupDecision>, String>(ManagerMakeupCommand.new);

class ManagerMakeupCommand extends ReceiptController<MakeupDecision> {
  ManagerMakeupCommand(this.id);
  final String id;
  String? _placement;
  @override
  void resetTarget() => _placement = null;
  Future<MakeupDecision?> place(MakeupConflict conflict, MakeupCandidate candidate, String reason) {
    if (state.locked || state.conflict) return Future.value(null);
    if (conflict.id != id ||
        conflict.status != MakeupConflictStatus.OPEN ||
        candidate.capacity < 1 ||
        reason.trim().isEmpty ||
        reason.trim().length > 1000) {
      throw ApiError(status: 422, code: 'MANAGER_VALIDATION');
    }
    _placement = null;
    return execute({
      'expectedVersion': conflict.version,
      'targetSessionId': candidate.session.id,
      'expectedTargetVersion': candidate.session.version,
      'contentMatchConfirmed': true,
      'reason': reason.trim(),
    });
  }

  Future<MakeupDecision?> cancel(MakeupConflict conflict, String reason) {
    if (state.locked || state.conflict) return Future.value(null);
    if (conflict.id != id ||
        conflict.placementId == null ||
        conflict.placementVersion == null ||
        reason.trim().isEmpty ||
        reason.trim().length > 1000) {
      throw ApiError(status: 422, code: 'MANAGER_VALIDATION');
    }
    _placement = conflict.placementId;
    return execute({'expectedVersion': conflict.placementVersion, 'reason': reason.trim()});
  }

  @override
  Future<MakeupDecision> send(IdempotentCall c) =>
      ref.read(managerOperationsApiProvider).place(id, c, placementId: _placement);
  @override
  void invalidate(MakeupDecision r) {
    ref.invalidate(managerConflictsProvider);
    ref.invalidate(managerConflictProvider(id));
    ref.invalidate(managerMakeupCandidatesProvider);
    ref.invalidate(managerTimetableProvider);
  }
}
