import 'api_error.dart';

/// Đọc JSON có kiểm tra kiểu - thay cho Zod bên RN.
/// Sai kiểu/thiếu field => ném [ApiError.invalidResponse].
///
/// Ví dụ:
///   final j = Json(response);
///   Course(id: j.uuid('id'), title: j.str('title'), price: j.amount('priceAmount'));
class Json {
  Json(Object? value, [this.errorCode = 'INVALID_RESPONSE'])
    : _map = value is Map<String, dynamic>
          ? value
          : (value is Map ? Map<String, dynamic>.from(value) : _fail(errorCode));

  final Map<String, dynamic> _map;
  final String errorCode;

  static Never _fail(String code) => throw ApiError.invalidResponse(code);
  Never fail() => _fail(errorCode);

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
  static final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  // Timestamp bắt buộc có offset (Z hoặc +07:00)
  static final _offset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  bool has(String key) => _map[key] != null;

  String str(String key) => _map[key] is String ? _map[key] as String : fail();
  String? strOrNull(String key) => _map[key] == null ? null : str(key);
  String nonEmpty(String key) => str(key).isNotEmpty ? str(key) : fail();

  String uuid(String key) => _uuid.hasMatch(str(key)) ? str(key) : fail();
  String? uuidOrNull(String key) => _map[key] == null ? null : uuid(key);

  int integer(String key) => _map[key] is int ? _map[key] as int : fail();
  double number(String key) {
    final value = _map[key];
    return value is num && value.isFinite ? value.toDouble() : fail();
  }

  bool boolean(String key) => _map[key] is bool ? _map[key] as bool : fail();

  /// Số tiền nguyên VND, 0..1e12
  int amount(String key) {
    final v = integer(key);
    return v >= 0 && v <= 1000000000000 ? v : fail();
  }

  /// Ngày thuần `YYYY-MM-DD` - giữ nguyên chuỗi, không đổi sang UTC.
  String day(String key) {
    final v = str(key);
    return _day.hasMatch(v) && DateTime.tryParse(v) != null ? v : fail();
  }

  /// Timestamp ISO có offset.
  DateTime dateTime(String key) {
    final v = str(key);
    if (!_offset.hasMatch(v)) fail();
    return DateTime.tryParse(v) ?? fail();
  }

  DateTime? dateTimeOrNull(String key) => _map[key] == null ? null : dateTime(key);

  T enumOf<T extends Enum>(String key, List<T> values) {
    final v = str(key);
    for (final e in values) {
      if (e.name == v) return e;
    }
    return fail();
  }

  Json obj(String key) => Json(_map[key], errorCode);
  Json? objOrNull(String key) => _map[key] == null ? null : obj(key);

  Map<String, String> stringMap(String key) {
    final value = _map[key];
    if (value is! Map<String, dynamic>) fail();
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.value is! String) fail();
      result[entry.key] = entry.value as String;
    }
    return Map.unmodifiable(result);
  }

  List<T> list<T>(String key, T Function(Json j) parse) {
    final v = _map[key];
    if (v is! List) fail();
    return v.map((e) => parse(Json(e, errorCode))).toList();
  }

  List<String> uuidList(String key) {
    final value = _map[key];
    if (value is! List) fail();
    final result = <String>[];
    for (final item in value) {
      if (item is! String || !_uuid.hasMatch(item)) fail();
      result.add(item);
    }
    if (result.toSet().length != result.length) fail();
    return List.unmodifiable(result);
  }
}

/// Trang dữ liệu `{ items, page, pageSize, total }`.
class Paged<T> {
  Paged({required this.items, required this.page, required this.pageSize, required this.total});

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  factory Paged.fromJson(Json j, T Function(Json) parse) => Paged(
    items: j.list('items', parse),
    page: j.integer('page'),
    pageSize: j.integer('pageSize'),
    total: j.integer('total'),
  );

  /// Kiểm tra metadata giống `checkPage` bên RN.
  /// [count] = tổng số item đã đọc tính đến trang này.
  void check(int expectedPage, int count, String errorCode) {
    if (page != expectedPage || items.length > pageSize || count > total || (items.isEmpty && count < total)) {
      throw ApiError.invalidResponse(errorCode);
    }
  }
}
