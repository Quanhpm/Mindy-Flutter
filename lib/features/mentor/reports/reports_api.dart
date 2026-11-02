import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/format.dart';
import 'reports_models.dart';

final mentorReportsApiProvider = Provider((ref) => MentorReportsApi(ref.watch(apiClientProvider)));

class MentorReportsApi {
  MentorReportsApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_REPORTS_RESPONSE';
  String _metadata(Json j, String classId) {
    if (j.uuid('classId') != classId) j.fail();
    final zone = j.str('timeZone');
    if (!Dates.isValidZone(zone)) j.fail();
    j.boolean('readonly');
    j.dateTime('asOf');
    return zone;
  }

  Future<ClassAttendanceSummary> classSummary(String id, {CancelToken? cancel}) async {
    String? zone;
    bool? readonly;
    DateTime? asOf;
    final items = await readAllPages(
      (page) async {
        final j = Json(
          await _api.get(
            'mentor/classes/$id/attendance-summary',
            query: {'page': page, 'pageSize': 100},
            cancel: cancel,
          ),
          errorCode,
        );
        final current = _metadata(j, id), read = j.boolean('readonly');
        if ((zone != null && zone != current) || (readonly != null && readonly != read)) {
          j.fail();
        }
        zone = current;
        readonly = read;
        asOf = j.dateTime('asOf');
        return Paged.fromJson(j, EnrollmentAttendance.fromJson);
      },
      idOf: (row) => row.enrollmentId,
      errorCode: errorCode,
    );
    return ClassAttendanceSummary(classId: id, timeZone: zone!, readonly: readonly!, asOf: asOf!, items: items);
  }

  Future<StudentAttendanceHistory> history(String classId, String studentId, {CancelToken? cancel}) async {
    String? zone;
    final items = await readAllPages(
      (page) async {
        final j = Json(
          await _api.get(
            'mentor/classes/$classId/students/$studentId/attendance',
            query: {'page': page, 'pageSize': 100},
            cancel: cancel,
          ),
          errorCode,
        );
        final current = _metadata(j, classId);
        if (zone != null && zone != current) j.fail();
        zone = current;
        return Paged.fromJson(j, StudentAttendanceHistoryRow.fromJson);
      },
      idOf: (row) => row.key,
      errorCode: errorCode,
    );
    return StudentAttendanceHistory(timeZone: zone!, items: items);
  }

  Future<StudentAttendanceSummary> studentSummary(String classId, String studentId, {CancelToken? cancel}) async {
    final j = Json(
      await _api.get('mentor/classes/$classId/students/$studentId/attendance-summary', cancel: cancel),
      errorCode,
    );
    final zone = _metadata(j, classId);
    if (j.str('aggregationScope') != 'STUDENT_CLASS_HISTORY') j.fail();
    return StudentAttendanceSummary(counts: MentorAttendanceCounts.fromJson(j), timeZone: zone);
  }
}
