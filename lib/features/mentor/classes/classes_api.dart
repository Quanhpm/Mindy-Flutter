import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import 'classes_models.dart';

final mentorClassesApiProvider = Provider((ref) => MentorClassesApi(ref.watch(apiClientProvider)));

class MentorClassesApi {
  MentorClassesApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_CLASSES_RESPONSE';

  Future<List<MentorClass>> all({MentorClassFilter? assignment, MentorClassStatus? status, CancelToken? cancel}) =>
      readAllPages(
        (page) async => Paged.fromJson(
          Json(
            await _api.get(
              'mentor/classes',
              query: {'assignment': assignment?.name ?? 'ANY', 'status': status?.name, 'page': page, 'pageSize': 100},
              cancel: cancel,
            ),
            errorCode,
          ),
          MentorClass.fromJson,
        ),
        idOf: (item) => item.id,
        errorCode: errorCode,
      );

  Future<MentorWorkspace> workspace(String id, {CancelToken? cancel}) async =>
      MentorWorkspace.fromJson(Json(await _api.get('mentor/classes/$id', cancel: cancel), errorCode), id);
  Future<List<MentorWorkspaceSession>> sessions(String id, {CancelToken? cancel}) => readAllPages(
    (page) async {
      final j = Json(
        await _api.get('mentor/classes/$id/sessions', query: {'page': page, 'pageSize': 100}, cancel: cancel),
        errorCode,
      );
      final response = Paged.fromJson(j, MentorWorkspaceSession.fromJson);
      if (response.items.any((row) => row.session.classId != id)) j.fail();
      return response;
    },
    idOf: (row) => row.session.id,
    errorCode: errorCode,
  );
  Future<List<MentorUnit>> units(String id, {CancelToken? cancel}) => readAllPages(
    (page) async {
      final j = Json(
        await _api.get('mentor/classes/$id/units', query: {'page': page, 'pageSize': 100}, cancel: cancel),
        errorCode,
      );
      final response = Paged.fromJson(j, MentorUnit.fromJson);
      if (response.items.any((unit) => unit.classId != id)) j.fail();
      return response;
    },
    idOf: (unit) => unit.id,
    errorCode: errorCode,
  );
  Future<List<MentorSessionSlot>> slots(String id, String unitId, {CancelToken? cancel}) => readAllPages(
    (page) async {
      final j = Json(
        await _api.get(
          'mentor/classes/$id/units/$unitId/sessions',
          query: {'page': page, 'pageSize': 100},
          cancel: cancel,
        ),
        errorCode,
      );
      final response = Paged.fromJson(j, MentorSessionSlot.fromJson);
      if (response.items.any((slot) => slot.unitId != unitId)) j.fail();
      return response;
    },
    idOf: (slot) => slot.id,
    errorCode: errorCode,
  );
}
