import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/network/api_error.dart';
import 'my_classes_api.dart';
import 'my_classes_models.dart';

/// Danh sách lớp theo view (current | history), tải từng trang 100 dòng + "Tải thêm".
class ClassesList {
  const ClassesList({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
    this.moreError,
  });
  final List<Enrollment> items;
  final int total;
  final int page;
  final bool loadingMore;
  final Object? moreError;

  bool get hasMore => items.length < total;
}

final myClassesProvider = AsyncNotifierProvider.autoDispose.family<MyClassesController, ClassesList, ClassesView>(
  MyClassesController.new,
);

class MyClassesController extends AsyncNotifier<ClassesList> {
  MyClassesController(this.view);
  final ClassesView view;

  @override
  Future<ClassesList> build() async {
    ref.watch(sessionEpochProvider);
    final r = await ref.watch(myClassesApiProvider).classesPage(view, 1);
    return ClassesList(items: r.page.items, total: r.page.total, page: 1);
  }

  Future<void> loadMore() async {
    final epoch = ref.read(sessionEpochProvider);
    bool current() => ref.mounted && ref.read(sessionEpochProvider) == epoch;
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(ClassesList(items: cur.items, total: cur.total, page: cur.page, loadingMore: true));
    try {
      final next = cur.page + 1;
      final r = await ref.read(myClassesApiProvider).classesPage(view, next);
      if (!current()) return;
      final count = cur.items.length + r.page.items.length;
      r.page.check(next, count, learningError);
      final seen = cur.items.map((e) => e.enrollmentId).toSet();
      if (r.page.total != cur.total || r.page.items.any((e) => !seen.add(e.enrollmentId))) {
        throw ApiError.invalidResponse(learningError);
      }
      state = AsyncData(ClassesList(items: [...cur.items, ...r.page.items], total: r.page.total, page: next));
    } catch (e) {
      if (!current()) return;
      state = AsyncData(ClassesList(items: cur.items, total: cur.total, page: cur.page, moreError: e));
    }
  }
}

/// Chi tiết lớp đã xác minh quyền. autoDispose => mỗi lần mở lại màn đều xác minh lại
/// (không dùng meeting URL cũ).
final classDetailProvider = FutureProvider.autoDispose.family<({ClassDetail detail, Enrollment enrollment}), String>((
  ref,
  classId,
) {
  ref.watch(sessionEpochProvider);
  return ref.watch(myClassesApiProvider).verifiedDetail(classId);
});
