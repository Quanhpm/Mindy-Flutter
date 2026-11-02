import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import '../../core/network/pagination.dart';
import 'courses_models.dart';

final coursesApiProvider = Provider((ref) => CoursesApi(ref.watch(apiClientProvider)));

/// `modules/courses/services/catalog.service.ts`
class CoursesApi {
  CoursesApi(this._api);
  final ApiClient _api;
  static const _err = 'INVALID_CATALOG_RESPONSE';

  Future<Paged<T>> _page<T>(String path, Map<String, Object?> q, T Function(Json) parse, {CancelToken? cancel}) async {
    final res = await _api.get(path, query: q, cancel: cancel);
    return Paged.fromJson(Json(res, _err), parse);
  }

  /// Chỉ danh mục đang active
  Future<List<CourseCategory>> categories({CancelToken? cancel}) async {
    final p = await _page('course-categories', {'page': 1, 'pageSize': 50}, CourseCategory.fromJson, cancel: cancel);
    return p.items.where((c) => c.isActive).toList();
  }

  Future<Paged<Course>> courses({
    required int page,
    required int pageSize,
    String? categoryId,
    DeliveryMode? deliveryMode,
    CancelToken? cancel,
  }) => _page(
    'courses',
    {'page': page, 'pageSize': pageSize, 'categoryId': categoryId, 'deliveryMode': deliveryMode?.name},
    Course.fromJson,
    cancel: cancel,
  );

  Future<Course> course(String courseId, {CancelToken? cancel}) async =>
      Course.fromJson(Json(await _api.get('courses/$courseId', cancel: cancel), _err));

  /// Lớp đang mở của khoá (sheet chi tiết) - 20 lớp đầu như RN
  Future<List<CourseClass>> classes(String courseId, {int pageSize = 20, CancelToken? cancel}) async => (await _page(
    'courses/$courseId/classes',
    {'page': 1, 'pageSize': pageSize},
    CourseClass.fromJson,
    cancel: cancel,
  )).items;

  /// Lớp khai giảng sớm nhất (contract không đảm bảo thứ tự nên tự chọn)
  Future<OpenClass?> nextClass(String courseId, {CancelToken? cancel}) async {
    // home.service.ts: thứ tự/trang đầu không bảo đảm chứa lớp mở sớm nhất.
    final items = await readAllPages(
      (page) async {
        final result = await _page(
          'courses/$courseId/classes',
          {'page': page, 'pageSize': 100},
          CourseClass.fromJson,
          cancel: cancel,
        );
        if (result.items.any((item) => item.courseId != courseId)) {
          throw ApiError.invalidResponse(_err);
        }
        return result;
      },
      idOf: (item) => item.id,
      errorCode: _err,
    );
    if (items.isEmpty) return null;
    final first = items.reduce((a, b) => a.startDate.compareTo(b.startDate) <= 0 ? a : b);
    return OpenClass(startDate: first.startDate, deliveryMode: first.deliveryMode);
  }

  /// Giờ bắt đầu các buổi của 1 lớp (tóm tắt lịch trong sheet)
  Future<List<DateTime>> classSessions(String classId, {CancelToken? cancel}) async {
    final j = Json(await _api.get('classes/$classId', cancel: cancel), _err);
    j.uuid('id');
    return [
      for (final unit in j.list('units', (u) => u))
        for (final s in unit.list('sessions', (s) => s)) s.dateTime('startsAt'),
    ];
  }
}
