import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import 'attendance_models.dart';

final mentorAttendanceApiProvider = Provider((ref) => MentorAttendanceApi(ref.watch(apiClientProvider)));

class MentorAttendanceApi {
  MentorAttendanceApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_ATTENDANCE_RESPONSE';

  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) async {
    AttendanceHeader? header;
    var pending = 0;
    final records = await readAllPages(
      (page) async {
        final j = Json(
          await _api.get('class-sessions/$id/attendance', query: {'page': page, 'pageSize': 100}, cancel: cancel),
          errorCode,
        );
        final current = AttendanceHeader.fromJson(j, id);
        if (header != null &&
            (header!.session.version != current.session.version || !header!.totals.sameAs(current.totals))) {
          throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
        }
        header = current;
        pending = j.integer('pendingPaymentCount');
        if (pending < 0) j.fail();
        final response = Paged.fromJson(j, AttendanceRecord.fromJson);
        if (response.total != current.totals.eligible) j.fail();
        return response;
      },
      idOf: (record) => record.key,
      errorCode: errorCode,
    );
    final actual = AttendanceTotals(
      present: records.where((record) => record.status == AttendanceStatus.PRESENT).length,
      absent: records.where((record) => record.status == AttendanceStatus.ABSENT).length,
      unmarked: records.where((record) => record.status == AttendanceStatus.UNMARKED).length,
      eligible: records.length,
    );
    if (!actual.sameAs(header!.totals)) throw ApiError.invalidResponse(errorCode);
    return AttendanceRoster(header: header!, records: records, pendingPaymentCount: pending);
  }

  Future<AttendanceWrite> execute(String id, AttendanceOperation operation, IdempotentCall call) async {
    final suffix = switch (operation) {
      AttendanceOperation.start => 'start',
      AttendanceOperation.mark => 'attendance',
      AttendanceOperation.bulk => 'attendance/bulk',
      AttendanceOperation.sync => 'attendance/sync-roster',
      AttendanceOperation.finalize => 'finalize',
    };
    final path = 'class-sessions/$id/$suffix';
    final response = operation == AttendanceOperation.mark || operation == AttendanceOperation.bulk
        ? await _api.put(path, body: call.body, headers: call.headers)
        : await _api.post(path, body: call.body, headers: call.headers);
    return AttendanceWrite.fromJson(Json(response, errorCode), id);
  }
}
