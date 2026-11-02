import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import '../../core/utils/format.dart';
import '../my_classes/my_classes_models.dart';
import 'schedule_models.dart';

final scheduleApiProvider = Provider((ref) => ScheduleApi(ref.watch(apiClientProvider)));

/// `schedule/services/schedule.service.ts` (và phần schedule của home.service.ts)
class ScheduleApi {
  ScheduleApi(this._api);
  final ApiClient _api;

  Future<String> timeZone({CancelToken? cancel}) async {
    final now = DateTime.now().toUtc();
    final j = Json(
      await _api.get(
        'me/schedule',
        query: {
          'from': now.toIso8601String(),
          'to': now.add(const Duration(seconds: 1)).toIso8601String(),
          'page': 1,
          'pageSize': 1,
        },
        cancel: cancel,
      ),
      learningError,
    );
    final zone = j.nonEmpty('timeZone');
    if (!Dates.isValidZone(zone)) j.fail();
    return zone;
  }

  /// Đọc hết các trang trong khoảng [from, to) (tối đa 31 ngày), kiểm tra metadata,
  /// báo lỗi ID trùng, sort ổn định. Bỏ SESSION_MAKEUP.
  Future<ScheduleWeek> range(
    DateTime rawFrom,
    DateTime rawTo, {
    bool includeCancelled = true,
    CancelToken? cancel,
  }) async {
    // Cắt về mili-giây như `toISOString()` của JS, để so khớp `from`/`to` server trả về
    DateTime ms(DateTime d) => DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch, isUtc: true);
    final from = ms(rawFrom), to = ms(rawTo);
    final span = to.difference(from);
    if (span <= Duration.zero || span > const Duration(days: 31)) {
      throw ApiError(status: 0, code: 'INVALID_SCHEDULE_RANGE', message: 'Invalid schedule range');
    }
    final items = <String, ScheduleSession>{};
    var page = 1, count = 0;
    int? total, size;
    final epoch = _api.sessionEpoch;
    var timeZone = '';
    var asOf = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    while (true) {
      if (_api.sessionEpoch != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
      final j = Json(
        await _api.get(
          'me/schedule',
          query: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
            'page': page,
            'pageSize': 100,
            'includeCancelled': includeCancelled,
          },
          cancel: cancel,
        ),
        learningError,
      );
      final p = Paged.fromJson(j, ScheduleSession.fromJson);
      if ((total != null && p.total != total) || (size != null && p.pageSize != size)) j.fail();
      total = p.total;
      size = p.pageSize;
      count += p.items.length;
      p.check(page, count, learningError);
      final zone = j.str('timeZone');
      if (!Dates.isValidZone(zone) ||
          !j.dateTime('from').isAtSameMomentAs(from) ||
          !j.dateTime('to').isAtSameMomentAs(to) ||
          (timeZone.isNotEmpty && timeZone != zone)) {
        throw ApiError.invalidResponse(learningError);
      }
      timeZone = zone;
      final pageAsOf = j.dateTime('asOf');
      if (pageAsOf.isAfter(asOf)) asOf = pageAsOf;
      for (final s in p.items) {
        if (items.containsKey(s.sessionId)) j.fail();
        items[s.sessionId] = s;
      }
      if (count >= p.total) break;
      page++;
    }
    final sorted = items.values.where((s) => s.access != ScheduleAccess.SESSION_MAKEUP).toList()
      ..sort((a, b) {
        final c = a.startsAt.compareTo(b.startsAt);
        return c != 0 ? c : a.sessionId.compareTo(b.sessionId);
      });
    return ScheduleWeek(items: sorted, timeZone: timeZone, asOf: asOf);
  }
}
