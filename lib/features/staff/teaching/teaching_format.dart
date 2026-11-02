import 'package:intl/intl.dart';

import 'teaching_models.dart';

/// Clone `modules/teaching/format.ts`. Việt Nam cố định UTC+7 (không DST) nên tính offset trực tiếp.
const vietnamOffset = Duration(hours: 7);

DateTime _vn(DateTime instant) => instant.toUtc().add(vietnamOffset);

String _two(int v) => v.toString().padLeft(2, '0');

/// `YYYY-MM-DD` theo giờ Việt Nam.
String vietnamDate([DateTime? instant]) {
  final v = _vn(instant ?? DateTime.now());
  return '${v.year}-${_two(v.month)}-${_two(v.day)}';
}

/// `YYYY-MM-DD` -> `DD/MM/YYYY`, null -> `—`.
String calendarDate(String? date) => date == null ? '—' : date.split('-').reversed.join('/');

DateTime _noonUtc(String date) => DateTime.parse('${date}T12:00:00Z');

String _isoDay(DateTime utc) => '${utc.year}-${_two(utc.month)}-${_two(utc.day)}';

String addDays(String date, int days) => _isoDay(_noonUtc(date).add(Duration(days: days)));

/// 7 ngày Thứ Hai -> Chủ Nhật của tuần chứa [date].
List<String> weekDates(String date) {
  final day = _noonUtc(date).weekday; // 1 = Monday
  final monday = addDays(date, -(day - 1));
  return [for (var i = 0; i < 7; i++) addDays(monday, i)];
}

({String from, String to}) weekRange(String date) {
  final first = weekDates(date).first;
  return (from: '${first}T00:00:00+07:00', to: '${addDays(first, 7)}T00:00:00+07:00');
}

/// `YYYY-MM-DD` -> `DD/MM`.
String shortDate(String? date) => date == null ? '—' : date.substring(5).split('-').reversed.join('/');

List<String> weekdayLabels(String language) =>
    language == 'en' ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] : const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _locale(String language) => language == 'en' ? 'en_GB' : 'vi';

String weekdayName(DateTime instant, String language) => DateFormat('EEEE', _locale(language)).format(_vn(instant));

String monthLabel(String date, String language) =>
    language == 'en' ? DateFormat('MMM', 'en_GB').format(_noonUtc(date)) : 'Th${int.parse(date.substring(5, 7))}';

/// `HH:mm` giờ Việt Nam.
String time(DateTime instant) {
  final v = _vn(instant);
  return '${_two(v.hour)}:${_two(v.minute)}';
}

String fullDate(DateTime instant, String language) =>
    DateFormat('EEEE, dd/MM/yyyy', _locale(language)).format(_vn(instant));

/// Máy không ở UTC+7 (RN `differentTimezone`).
bool differentTimezone() => DateTime.now().timeZoneOffset != vietnamOffset;

/// Chỉ nhận http(s) có host, không kèm user/password.
({String url, String host})? safeMeetingLink(String? value) {
  if (value == null || !RegExp(r'^https?://[^\s/]+', caseSensitive: false).hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.userInfo.isNotEmpty) {
    return null;
  }
  return (url: value, host: uri.host);
}

/// Buổi hiện ra ở thẻ "Hôm nay": đang dạy > sắp dạy sớm nhất > đã xong muộn nhất.
TeachingSession? selectTodaySession(List<TeachingSession> sessions, String date) {
  final today = sessions.where((s) => s.status != SessionStatus.CANCELLED && vietnamDate(s.startsAt) == date).toList();
  int asc(TeachingSession a, TeachingSession b) => a.startsAt.compareTo(b.startsAt);
  TeachingSession? first(SessionStatus status, {bool latest = false}) {
    final list = today.where((s) => s.status == status).toList()..sort(asc);
    if (list.isEmpty) return null;
    return latest ? list.last : list.first;
  }

  return first(SessionStatus.IN_PROGRESS) ?? first(SessionStatus.SCHEDULED) ?? first(SessionStatus.COMPLETED, latest: true);
}

/// Clone `services/classSessionSummary.ts`. Chỉ gọi khi đã có đủ mọi trang buổi học.
({int sessionCount, int elapsedSessions, List<int> scheduleDays, String? scheduleTime, DateTime? nextSessionAt})
classSessionSummary(List<TeachingSession> sessions, [DateTime? now]) {
  final at = now ?? DateTime.now();
  final active = sessions.where((s) => s.status != SessionStatus.CANCELLED).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  DateTime end(TeachingSession s) => s.actualEnd ?? s.endsAt;
  final elapsed = active.where((s) => !end(s).isAfter(at)).length;
  final upcoming = active.where((s) => s.status != SessionStatus.COMPLETED && end(s).isAfter(at)).toList();
  final schedule = upcoming.isNotEmpty ? upcoming : active;
  final days = <int>{for (final s in schedule) _noonUtc(vietnamDate(s.startsAt)).weekday - 1}.toList()..sort();
  final times = <String>{for (final s in schedule) time(s.startsAt)};
  return (
    sessionCount: active.length,
    elapsedSessions: elapsed,
    scheduleDays: days,
    scheduleTime: times.isEmpty ? null : times.join(' / '),
    nextSessionAt: upcoming.isEmpty ? null : upcoming.first.startsAt,
  );
}
