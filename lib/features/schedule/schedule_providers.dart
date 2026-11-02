import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/utils/format.dart';
import 'schedule_api.dart';
import 'schedule_models.dart';

final learningTimeZoneProvider = FutureProvider<String>((ref) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(scheduleApiProvider).timeZone(cancel: cancel);
});

/// Múi giờ dùng để tính tuần. Chỉ tính ngày thật khi nhận `timeZone` của server.
final scheduleZoneProvider = NotifierProvider<ScheduleZone, String>(ScheduleZone.new);

class ScheduleZone extends Notifier<String> {
  @override
  String build() {
    ref.watch(sessionEpochProvider);
    return 'UTC';
  }

  void set(String zone) => state = zone;
}

/// Ngày đang neo (tuần đang xem), dạng YYYY-MM-DD. Mặc định hôm nay.
final scheduleAnchorProvider = NotifierProvider<ScheduleAnchor, String>(ScheduleAnchor.new);

class ScheduleAnchor extends Notifier<String> {
  @override
  String build() {
    ref.watch(sessionEpochProvider);
    return Dates.localDay(DateTime.now(), ref.watch(learningTimeZoneProvider).value ?? 'UTC');
  }

  void set(String day) => state = day;
  void today() => state = Dates.localDay(
    DateTime.now(),
    ref.read(learningTimeZoneProvider).value ?? ref.read(scheduleZoneProvider),
  );
  void shiftWeek(int weeks) => state = Dates.shiftDay(state, weeks * 7);
}

/// Lịch tuần đang xem (có cả buổi đã huỷ, như RN).
final scheduleWeekProvider = FutureProvider.autoDispose<ScheduleWeek>((ref) async {
  ref.watch(sessionEpochProvider);
  final day = ref.watch(scheduleAnchorProvider);
  final zone = await ref.watch(learningTimeZoneProvider.future);
  final r = Dates.weekRange(day, zone);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(scheduleApiProvider).range(r.from, r.to, cancel: cancel);
});
