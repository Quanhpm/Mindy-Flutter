import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/receipt_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../payment/payment_models.dart';
import 'collections_api.dart';
import 'collections_models.dart';

final managerCollectionsProvider = FutureProvider.autoDispose.family<List<CollectionOrder>, CollectionFilter>((ref, q) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerCollectionsApiProvider).list(q, cancel: c);
});
final managerOrderProvider = FutureProvider.autoDispose.family<CollectionOrder, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerCollectionsApiProvider).detail(id, cancel: c);
});
final managerCashCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerCollectionsApiProvider).count(cancel: c);
});
final managerCashCommandProvider = NotifierProvider.autoDispose
    .family<ManagerCashCommand, CommandState<CollectionOrder>, String>(ManagerCashCommand.new);

class ManagerCashCommand extends Notifier<CommandState<CollectionOrder>> {
  ManagerCashCommand(this.id);
  final String id;
  void Function()? _release;
  bool _acknowledged = false;
  @override
  CommandState<CollectionOrder> build() {
    ref.watch(sessionEpochProvider);
    _release?.call();
    _release = null;
    _acknowledged = false;
    return const CommandState();
  }

  Future<CollectionOrder?> check() async {
    if (state.busy) return null;
    final epoch = ref.read(sessionEpochProvider);
    state = const CommandState(busy: true);
    _release ??= ref.keepAlive().close;
    try {
      final order = await ref.read(managerCollectionsApiProvider).detail(id);
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      if (_acknowledged && order.status != OrderStatus.PAID) throw ApiError.invalidResponse();
      state = CommandState(result: order);
      _release?.call();
      _release = null;
      _invalidate();
      return order;
    } catch (e) {
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) state = CommandState(error: e, retryPending: true);
      return null;
    }
  }

  Future<CollectionOrder?> confirm(int amount) async {
    if (state.locked || state.conflict || _acknowledged) return null;
    final epoch = ref.read(sessionEpochProvider);
    _release ??= ref.keepAlive().close;
    state = const CommandState(busy: true);
    bool valid() => ref.mounted && ref.read(sessionEpochProvider) == epoch;
    try {
      final api = ref.read(managerCollectionsApiProvider), fresh = await api.detail(id);
      if (!valid()) return null;
      if (!fresh.canConfirm || amount != fresh.amount || amount < 1) {
        throw ApiError(status: 422, code: 'CASH_CONFIRMATION_INVALID');
      }
      await api.confirm(id, amount);
      if (!valid()) return null;
      _acknowledged = true;
      final order = await api.detail(id);
      if (!valid()) return null;
      if (order.status != OrderStatus.PAID) throw ApiError.invalidResponse();
      state = CommandState(result: order);
      _release?.call();
      _release = null;
      _invalidate();
      return order;
    } catch (e) {
      if (!valid()) return null;
      final uncertain = _acknowledged || e is! ApiError || e.status == 0 || e.status >= 500 || e.status == 408;
      state = CommandState(error: e, retryPending: uncertain, conflict: e is ApiError && e.status == 409);
      if (!uncertain && !state.conflict) {
        _release?.call();
        _release = null;
      }
      return null;
    }
  }

  void _invalidate() {
    ref.invalidate(managerOrderProvider(id));
    ref.invalidate(managerCollectionsProvider);
    ref.invalidate(managerCashCountProvider);
  }
}
