import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/json.dart';
import '../../core/session/session_controller.dart';
import 'courses_api.dart';
import 'courses_models.dart';

const catalogPageSize = 6;

/// Bộ lọc danh mục - state cục bộ của CoursesRoute bên RN.
class CatalogFilter {
  const CatalogFilter({this.page = 1, this.categoryId, this.deliveryMode});
  final int page;
  final String? categoryId;
  final DeliveryMode? deliveryMode;
}

final catalogFilterProvider = NotifierProvider<CatalogFilterController, CatalogFilter>(CatalogFilterController.new);

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() {
    ref.watch(sessionEpochProvider); // đổi phiên -> reset
    return const CatalogFilter();
  }

  void page(int page) =>
      state = CatalogFilter(page: page, categoryId: state.categoryId, deliveryMode: state.deliveryMode);
  void category(String? id) => state = CatalogFilter(categoryId: id, deliveryMode: state.deliveryMode);
  void mode(DeliveryMode? mode) => state = CatalogFilter(categoryId: state.categoryId, deliveryMode: mode);
}

final categoriesProvider = FutureProvider.autoDispose<List<CourseCategory>>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(coursesApiProvider).categories();
});

/// Trang khoá học hiện tại (6 khoá/trang).
final catalogPageProvider = FutureProvider.autoDispose<Paged<Course>>((ref) {
  ref.watch(sessionEpochProvider);
  final f = ref.watch(catalogFilterProvider);
  return ref.watch(coursesApiProvider).courses(
        page: f.page,
        pageSize: catalogPageSize,
        categoryId: f.categoryId,
        deliveryMode: f.deliveryMode,
      );
});

/// Gợi ý = 3 khoá đầu theo thứ tự server (chưa có API xếp hạng).
final recommendationsProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  ref.watch(sessionEpochProvider);
  final p = await ref.watch(coursesApiProvider).courses(page: 1, pageSize: catalogPageSize);
  return p.items.take(3).toList();
});

/// Đếm số khoá khi đang chọn bộ lọc trong FilterSheet ("Xem N khoá học").
final filterCountProvider = FutureProvider.autoDispose.family<int, DeliveryMode?>((ref, mode) async {
  final f = ref.watch(catalogFilterProvider);
  final p = await ref.watch(coursesApiProvider).courses(
        page: 1,
        pageSize: 1,
        categoryId: f.categoryId,
        deliveryMode: mode,
      );
  return p.total;
});

/// Lớp khai giảng sớm nhất của 1 khoá. Lỗi -> null (thẻ khoá học vẫn hiện bình thường).
final nextClassProvider = FutureProvider.autoDispose.family<OpenClass?, String>((ref, courseId) async {
  ref.watch(sessionEpochProvider);
  ref.keepAlive(); // RN: staleTime 5 phút
  try {
    return await ref.watch(coursesApiProvider).nextClass(courseId);
  } catch (_) {
    return null;
  }
});

final courseDetailProvider = FutureProvider.autoDispose.family<Course, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(coursesApiProvider).course(id);
});

final courseClassesProvider = FutureProvider.autoDispose.family<List<CourseClass>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(coursesApiProvider).classes(id);
});

/// Lịch buổi học của 1 lớp (không bắt buộc - lỗi thì hiện khoảng ngày).
final classSessionsProvider = FutureProvider.autoDispose.family<List<DateTime>?, String>((ref, classId) async {
  try {
    return await ref.watch(coursesApiProvider).classSessions(classId);
  } catch (_) {
    return null;
  }
});
