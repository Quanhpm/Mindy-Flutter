import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
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
  final api = ref.watch(coursesApiProvider);
  final page = await api.courses(page: 1, pageSize: 4);
  // TODO(parity): RN đọc HẾT các trang lớp để tìm lớp sớm nhất; ở đây dùng trang 1 (100 lớp).
  return Future.wait(page.items.map((c) async {
    try {
      return c.withOpenClass(await api.nextClass(c.id));
    } catch (_) {
      return c;
    }
  }));
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
  final next = week.items.where((s) =>
      s.sessionStatus == SessionStatus.SCHEDULED &&
      s.classStatus != ClassStatus.CANCELLED &&
      s.access != ScheduleAccess.SESSION_MAKEUP &&
      !s.startsAt.isBefore(week.asOf));
  return HomeNextSession(session: next.isEmpty ? null : next.first, timeZone: week.timeZone, asOf: week.asOf);
});
