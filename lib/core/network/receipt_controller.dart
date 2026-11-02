import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_controller.dart';
import 'api_error.dart';
import 'idempotency.dart';

class CommandState<T> {
  const CommandState({this.busy = false, this.retryPending = false, this.conflict = false, this.error, this.result});
  final bool busy, retryPending, conflict;
  final Object? error;
  final T? result;
  bool get locked => busy || retryPending;
}

/// Các lệnh có receipt giữ đúng key/body trong RAM qua đóng/mở màn. 409 không
/// replay; người dùng phải đọc phiên bản mới và tạo ý định mới.
abstract class ReceiptController<T> extends Notifier<CommandState<T>> {
  IdempotentCall? _call;
  void Function()? _release;
  @override
  CommandState<T> build() {
    ref.watch(sessionEpochProvider);
    _call = null;
    _release?.call();
    _release = null;
    resetTarget();
    return const CommandState();
  }

  void resetTarget() {}
  Future<T> send(IdempotentCall call);
  void invalidate(T result);
  bool valid(int epoch) => ref.mounted && ref.read(sessionEpochProvider) == epoch;
  Future<T?> execute(Map<String, Object?> body) async {
    if (state.locked || state.conflict) return null;
    _call = IdempotentCall(body);
    return retry();
  }

  void reviewed() {
    if (!state.locked) state = const CommandState();
  }

  Future<T?> retry() async {
    final call = _call;
    if (call == null || state.busy) return null;
    final epoch = ref.read(sessionEpochProvider);
    _release ??= ref.keepAlive().close;
    state = const CommandState(busy: true);
    try {
      final result = await send(call);
      if (!valid(epoch)) return null;
      _call = null;
      _release?.call();
      _release = null;
      state = CommandState(result: result);
      invalidate(result);
      return result;
    } catch (error) {
      if (!valid(epoch)) return null;
      final uncertain =
          error is! ApiError || error.status == 0 || error.status >= 500 || error.status == 408 || error.status == 429;
      if (!uncertain) {
        _call = null;
        _release?.call();
        _release = null;
      }
      state = CommandState(error: error, retryPending: uncertain, conflict: error is ApiError && error.status == 409);
      return null;
    }
  }
}
