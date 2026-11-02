import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import 'students_models.dart';

final mentorStudentsApiProvider = Provider((ref) => MentorStudentsApi(ref.watch(apiClientProvider)));

class MentorStudentsApi {
  MentorStudentsApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_STUDENTS_RESPONSE';
  Future<List<MentorStudent>> all(String id, {CancelToken? cancel}) => readAllPages(
    (page) async => Paged.fromJson(
      Json(
        await _api.get('mentor/classes/$id/students', query: {'page': page, 'pageSize': 100}, cancel: cancel),
        errorCode,
      ),
      MentorStudent.fromJson,
    ),
    idOf: (row) => row.enrollmentId,
    errorCode: errorCode,
  );
  Future<int> count(String id, {CancelToken? cancel}) async {
    final j = Json(
      await _api.get('mentor/classes/$id/students', query: {'page': 1, 'pageSize': 1}, cancel: cancel),
      errorCode,
    );
    final page = Paged.fromJson(j, MentorStudent.fromJson);
    page.check(1, page.items.length, errorCode);
    if (page.pageSize != 1 || page.total < 0) j.fail();
    return page.total;
  }

  Future<StudentStoredProgress> progress(String classId, String studentId, {CancelToken? cancel}) async {
    String? zone;
    final items = await readAllPages(
      (page) async {
        final j = Json(
          await _api.get(
            'mentor/classes/$classId/students/$studentId/progress',
            query: {'page': page, 'pageSize': 100},
            cancel: cancel,
          ),
          errorCode,
        );
        final current = StudentStoredProgress.metadata(j);
        if (zone != null && zone != current) j.fail();
        zone = current;
        return Paged.fromJson(j, StudentStoredUnit.fromJson);
      },
      idOf: (row) => row.key,
      errorCode: errorCode,
    );
    return StudentStoredProgress(timeZone: zone!, items: items);
  }
}
