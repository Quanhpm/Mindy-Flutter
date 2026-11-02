import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Gọi 1 lần trong main().
void initTimeZones() => tzdata.initializeTimeZones();

/// `1.500.000 VND` - `shared/utilities/formatVnd.ts`
String formatVnd(int amount) => '${NumberFormat.decimalPattern('vi_VN').format(amount)} VND';

String formatPercent(double? value, String language) =>
    value == null ? '—' : '${NumberFormat('0.#', language).format(value)}%';

/// Thời gian luôn hiển thị theo `timeZone` của response, KHÔNG theo múi giờ máy.
/// Port từ `modules/schedule/calendar.ts`.
class Dates {
  Dates._();

  static tz.TZDateTime inZone(DateTime instant, String timeZone) =>
      tz.TZDateTime.from(instant, tz.getLocation(timeZone));

  static bool isValidZone(String timeZone) {
    try {
      tz.getLocation(timeZone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ngày `YYYY-MM-DD` của [instant] tại [timeZone].
  static String localDay(DateTime instant, String timeZone) =>
      DateFormat('yyyy-MM-dd').format(inZone(instant, timeZone));

  /// Cộng/trừ ngày trên ngày thuần (tính bằng UTC trưa để không lệch ngày).
  static String shiftDay(String day, int amount) {
    final d = DateTime.parse('${day}T12:00:00Z').add(Duration(days: amount));
    return d.toIso8601String().substring(0, 10);
  }

  /// 7 ngày của tuần chứa [day], bắt đầu thứ Hai.
  static List<String> weekDays(String day) {
    final weekday = DateTime.parse('${day}T12:00:00Z').weekday; // 1 = Mon
    final monday = shiftDay(day, -(weekday - 1));
    return List.generate(7, (i) => shiftDay(monday, i));
  }

  /// `2026-11-02` -> `02/11/2026`
  static String displayDay(String day) => day.split('-').reversed.join('/');

  /// `2026-11-02` -> `02/11`
  static String dateOnly(String day) {
    final p = day.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : day;
  }

  /// `18:30`
  static String time(DateTime instant, String timeZone) => DateFormat('HH:mm').format(inZone(instant, timeZone));

  /// `02/11/2026 18:30`
  static String instant(DateTime instant, String timeZone) =>
      DateFormat('dd/MM/yyyy HH:mm').format(inZone(instant, timeZone));

  /// 0h ngày [day] tại [timeZone] (đúng cả múi giờ có DST) - `midnight()` bên RN.
  static DateTime startOfDay(String day, String timeZone) {
    final p = day.split('-').map(int.parse).toList();
    return tz.TZDateTime(tz.getLocation(timeZone), p[0], p[1], p[2]);
  }

  /// Khoảng [thứ Hai 0h, thứ Hai tuần sau 0h) của tuần chứa [day].
  static ({DateTime from, DateTime to}) weekRange(String day, String timeZone) {
    final monday = weekDays(day).first;
    return (from: startOfDay(monday, timeZone), to: startOfDay(shiftDay(monday, 7), timeZone));
  }
}
