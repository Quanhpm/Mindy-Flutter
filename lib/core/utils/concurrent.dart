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
