import 'api_error.dart';
import 'json.dart';

/// Không nối hai danh sách khác snapshot (total/pageSize/ID trùng thay đổi).
Future<List<T>> readAllPages<T>(
  Future<Paged<T>> Function(int page) load, {
  required String Function(T) idOf,
  required String errorCode,
}) async {
  final result = <T>[];
  final ids = <String>{};
  int? total, size;
  for (var page = 1; ; page++) {
    final response = await load(page);
    response.check(page, result.length + response.items.length, errorCode);
    if (response.pageSize < 1 ||
        response.total < 0 ||
        (total != null && response.total != total) ||
        (size != null && response.pageSize != size)) {
      throw ApiError.invalidResponse(errorCode);
    }
    total = response.total;
    size = response.pageSize;
    for (final item in response.items) {
      if (!ids.add(idOf(item))) throw ApiError.invalidResponse(errorCode);
      result.add(item);
    }
    if (result.length == total) return List.unmodifiable(result);
  }
}
