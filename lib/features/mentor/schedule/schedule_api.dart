import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/format.dart';
import 'schedule_models.dart';

final mentorScheduleApiProvider = Provider((ref) => MentorScheduleApi(ref.watch(apiClientProvider)));

class TeachingRange {
  TeachingRange({required List<TeachingSession> sessions, required this.timeZone})
    : sessions = List.unmodifiable(sessions);
  final List<TeachingSession> sessions;
  final String timeZone;
}

class MentorScheduleApi {
  MentorScheduleApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_SCHEDULE_RESPONSE';

  /// Lấy timezone từ backend trước khi tính ngày/tuần; không đoán theo timezone máy.
  Future<String> timeZone({CancelToken? cancel}) async {
    final j = Json(await _api.get('mentor/schedule', query: {'page': 1, 'pageSize': 1}, cancel: cancel), errorCode);
    final page = Paged.fromJson(j, TeachingSession.fromJson);
    page.check(1, page.items.length, errorCode);
    final zone = j.nonEmpty('timeZone');
    if (!Dates.isValidZone(zone) ||
        page.pageSize != 1 ||
        page.total < 0 ||
        !j.dateTime('to').isAfter(j.dateTime('from'))) {
      j.fail();
    }
    j.dateTime('asOf');
    return zone;
  }

  Future<TeachingRange> range(DateTime rawFrom, DateTime rawTo, {CancelToken? cancel}) async {
    DateTime ms(DateTime date) => DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch, isUtc: true);
    final from = ms(rawFrom), to = ms(rawTo);
    if (!to.isAfter(from) || to.difference(from) > const Duration(days: 93)) {
      throw ApiError(status: 0, code: 'INVALID_SCHEDULE_RANGE');
    }
    String? timeZone;
    final sessions = await readAllPages(
      (page) async {
        final j = Json(
          await _api.get(
            'mentor/schedule',
            query: {'from': from.toIso8601String(), 'to': to.toIso8601String(), 'page': page, 'pageSize': 100},
            cancel: cancel,
          ),
          errorCode,
        );
        final zone = j.nonEmpty('timeZone');
        if (!Dates.isValidZone(zone) ||
            (timeZone != null && zone != timeZone) ||
            !j.dateTime('from').isAtSameMomentAs(from) ||
            !j.dateTime('to').isAtSameMomentAs(to)) {
          j.fail();
        }
        timeZone = zone;
        j.dateTime('asOf');
        final response = Paged.fromJson(j, TeachingSession.fromJson);
        for (final session in response.items) {
          if (session.timeZone != zone || !session.startsAt.isBefore(to) || !session.endsAt.isAfter(from)) j.fail();
        }
        return response;
      },
      idOf: (item) => item.id,
      errorCode: errorCode,
    );
    return TeachingRange(sessions: sessions, timeZone: timeZone!);
  }
}
