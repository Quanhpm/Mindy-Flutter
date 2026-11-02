import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/network/api_error.dart';
import '../courses/courses_api.dart';
import '../courses/courses_models.dart';
import '../my_classes/my_classes_models.dart';
import '../schedule/schedule_api.dart';
import '../schedule/schedule_models.dart';

/// `home/services/home.service.ts` + `useHomeQuery.ts`.
/// Mỗi vùng (khoá học / buổi tiếp theo) là 1 provider riêng:
/// lỗi một vùng không làm hỏng cả màn.

/// 4 khoá nổi bật, kèm lớp mở sớm nhất (lỗi lớp thì vẫn hiện khoá).
final homeCoursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(coursesApiProvider);
  final page = await api.courses(page: 1, pageSize: 4, cancel: cancel);
  page.check(1, page.items.length, 'INVALID_CATALOG_RESPONSE');
  if (page.pageSize != 4 || page.total < 0 || page.items.map((c) => c.id).toSet().length != page.items.length) {
    throw ApiError.invalidResponse('INVALID_CATALOG_RESPONSE');
  }
  return Future.wait(
    page.items.map((c) async {
      try {
        return c.withOpenClass(await api.nextClass(c.id, cancel: cancel));
      } catch (_) {
        if (cancel.isCancelled || !ref.mounted) rethrow;
        return c;
      }
    }),
  );
});

class HomeNextSession {
  const HomeNextSession({required this.session, required this.timeZone, required this.asOf});
  final ScheduleSession? session;
  final String timeZone;
  final DateTime asOf;
}

/// Buổi học tiếp theo trong 7 ngày tới (bỏ buổi huỷ, lớp huỷ, học bù).
final homeNextSessionProvider = FutureProvider.autoDispose<HomeNextSession>((ref) async {
  ref.watch(sessionEpochProvider);
  final now = DateTime.now().toUtc();
  final week = await ref
      .watch(scheduleApiProvider)
      .range(now, now.add(const Duration(days: 7)), includeCancelled: false);
  final next = week.items.where(
    (s) =>
        s.sessionStatus == SessionStatus.SCHEDULED &&
        s.classStatus != ClassStatus.CANCELLED &&
        s.access != ScheduleAccess.SESSION_MAKEUP &&
        !s.startsAt.isBefore(week.asOf),
  );
  return HomeNextSession(session: next.isEmpty ? null : next.first, timeZone: week.timeZone, asOf: week.asOf);
});
