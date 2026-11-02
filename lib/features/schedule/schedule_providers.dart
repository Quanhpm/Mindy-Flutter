import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/utils/format.dart';
import 'schedule_api.dart';
import 'schedule_models.dart';

/// Múi giờ dùng để tính tuần. Mặc định VN, đổi theo `timeZone` của response.
final scheduleZoneProvider = NotifierProvider<ScheduleZone, String>(ScheduleZone.new);

class ScheduleZone extends Notifier<String> {
  @override
  String build() => 'Asia/Ho_Chi_Minh';
  void set(String zone) => state = zone;
}

/// Ngày đang neo (tuần đang xem), dạng YYYY-MM-DD. Mặc định hôm nay.
final scheduleAnchorProvider = NotifierProvider<ScheduleAnchor, String>(ScheduleAnchor.new);

class ScheduleAnchor extends Notifier<String> {
  @override
  String build() {
    ref.watch(sessionEpochProvider);
    return Dates.localDay(DateTime.now(), ref.read(scheduleZoneProvider));
  }

  void set(String day) => state = day;
  void today() => state = Dates.localDay(DateTime.now(), ref.read(scheduleZoneProvider));
  void shiftWeek(int weeks) => state = Dates.shiftDay(state, weeks * 7);
}

/// Lịch tuần đang xem (có cả buổi đã huỷ, như RN).
final scheduleWeekProvider = FutureProvider.autoDispose<ScheduleWeek>((ref) {
  ref.watch(sessionEpochProvider);
  final day = ref.watch(scheduleAnchorProvider);
  final zone = ref.watch(scheduleZoneProvider);
  final r = Dates.weekRange(day, zone);
  return ref.watch(scheduleApiProvider).range(r.from, r.to);
});
