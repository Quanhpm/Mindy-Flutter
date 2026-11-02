import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/receipt_controller.dart';
import '../../../core/session/session_controller.dart';
import 'materials_api.dart';

final managerMaterialsProvider = FutureProvider.autoDispose.family<List<MentorMaterial>, ManagerMaterialFilter>((
  ref,
  f,
) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerMaterialsApiProvider).list(f, cancel: c);
});
final managerMaterialProvider = FutureProvider.autoDispose.family<ManagerMaterialSnapshot, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerMaterialsApiProvider).detail(id, cancel: c);
});
final managerMaterialCountProvider = FutureProvider.autoDispose.family<int, MaterialReviewStatus>((ref, status) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerMaterialsApiProvider).count(status, cancel: c);
});

class MaterialMutationResult {
  const MaterialMutationResult(this.snapshot, {this.deleted = false});
  final ManagerMaterialSnapshot? snapshot;
  final bool deleted;
}

typedef MaterialCommandTarget = ({String id, bool create});
final managerMaterialCommandProvider = NotifierProvider.autoDispose
    .family<ManagerMaterialCommand, CommandState<MaterialMutationResult>, MaterialCommandTarget>(
      ManagerMaterialCommand.new,
    );

class ManagerMaterialCommand extends Notifier<CommandState<MaterialMutationResult>> {
  ManagerMaterialCommand(this.target);
  final MaterialCommandTarget target;
  void Function()? _release;
  bool _readValidated = false;
  @override
  CommandState<MaterialMutationResult> build() {
    ref.watch(sessionEpochProvider);
    _release?.call();
    _release = null;
    _readValidated = false;
    return const CommandState();
  }

  void reviewed() {
    if (state.busy || !_readValidated) return;
    _readValidated = false;
    _release?.call();
    _release = null;
    state = const CommandState();
  }

  Future<ManagerMaterialSnapshot?> readLatest() async {
    if (target.create || state.busy) return null;
    final epoch = ref.read(sessionEpochProvider);
    final snapshot = await ref.read(managerMaterialsApiProvider).detail(target.id);
    if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
    _readValidated = true;
    return snapshot; // UI phải hiển thị rồi xác nhận trước reviewed().
  }

  Future<void> adoptExisting(ManagerMaterialSnapshot snapshot) async {
    final actor = ref.read(sessionProvider).user;
    if (!target.create ||
        state.busy ||
        actor == null ||
        snapshot.detail.material.courseUnitId != target.id ||
        snapshot.detail.material.createdBy != actor.id) {
      throw ApiError(status: 409, code: 'MANAGER_READ_FIRST');
    }
    _readValidated = true;
    reviewed();
    state = CommandState(result: MaterialMutationResult(snapshot));
  }

  Future<MaterialMutationResult?> run(String action, Map<String, Object?> input) async {
    if (state.locked || state.conflict) return null;
    final body = IdempotentCall(input).body, epoch = ref.read(sessionEpochProvider);
    _release ??= ref.keepAlive().close;
    state = const CommandState(busy: true);
    try {
      final api = ref.read(managerMaterialsApiProvider);
      ManagerMaterialSnapshot? result;
      if (target.create) {
        result = await api.create(target.id, body);
      } else if (action == 'patch') {
        result = await api.patch(target.id, body);
      } else if (action == 'delete') {
        await api.delete(target.id, body['expectedRevision']! as int);
      } else {
        result = await api.review(target.id, action, body);
      }
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      final output = MaterialMutationResult(result, deleted: action == 'delete');
      state = CommandState(result: output);
      _release?.call();
      _release = null;
      ref.invalidate(managerMaterialsProvider);
      ref.invalidate(managerMaterialCountProvider);
      if (!target.create) ref.invalidate(managerMaterialProvider(target.id));
      return output;
    } catch (error) {
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      final unknown = error is! ApiError || error.status == 0 || error.status >= 500 || error.status == 408;
      final conflict = error is ApiError && error.status == 409;
      state = CommandState(error: error, retryPending: unknown, conflict: conflict);
      if (!unknown && !conflict) {
        _release?.call();
        _release = null;
      }
      return null;
    }
  }
}
