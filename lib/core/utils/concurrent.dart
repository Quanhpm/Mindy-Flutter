import 'dart:async';
import 'dart:collection';

/// Giới hạn số tác vụ đang chạy; lỗi không biến thành kết quả rỗng.
Future<List<R>> mapConcurrent<T, R>(Iterable<T> values, Future<R> Function(T) action, {int limit = 3}) async {
  if (limit < 1) throw ArgumentError.value(limit, 'limit');
  final items = values.toList();
  final result = <R>[];
  for (var offset = 0; offset < items.length; offset += limit) {
    result.addAll(await Future.wait(items.skip(offset).take(limit).map(action)));
  }
  return List.unmodifiable(result);
}

/// Giới hạn chung cho các provider family, không chỉ từng batch trên một màn.
class AsyncGate {
  AsyncGate(this.limit) : assert(limit > 0);
  final int limit;
  int _active = 0;
  final _waiting = Queue<Completer<void>>();
  Future<T> run<T>(Future<T> Function() action) async {
    if (_active >= limit) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _active++;
    }
    try {
      return await action();
    } finally {
      if (_waiting.isEmpty) {
        _active--;
      } else {
        _waiting.removeFirst().complete();
      }
    }
  }
}
