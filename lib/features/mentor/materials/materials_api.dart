import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import '../classes/classes_models.dart';
import 'materials_models.dart';

final mentorMaterialsApiProvider = Provider((ref) => MentorMaterialsApi(ref.watch(apiClientProvider)));

class MentorMaterialsApi {
  MentorMaterialsApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_MATERIALS_RESPONSE';
  String _base(String id) => 'mentor/classes/$id';
  Future<List<MentorMaterial>> all(String classId, MentorUnit unit, {CancelToken? cancel}) => readAllPages(
    (page) async {
      final j = Json(
        await _api.get(
          '${_base(classId)}/units/${unit.id}/materials',
          query: {'page': page, 'pageSize': 100},
          cancel: cancel,
        ),
        errorCode,
      );
      final response = Paged.fromJson(j, MentorMaterial.fromJson);
      if (response.items.any((m) => m.courseUnitId != unit.courseUnitId)) {
        j.fail();
      }
      return response;
    },
    idOf: (m) => m.id,
    errorCode: errorCode,
  );
  MentorMaterialDetail _detail(Object? value, {String? id, String? courseUnitId}) {
    final j = Json(value, errorCode), detail = MentorMaterialDetail.fromJson(Json(value, errorCode));
    if ((id != null && detail.material.id != id) ||
        (courseUnitId != null && detail.material.courseUnitId != courseUnitId)) {
      j.fail();
    }
    return detail;
  }

  Future<MentorMaterialDetail> detail(String classId, String id, {CancelToken? cancel}) async =>
      _detail(await _api.get('${_base(classId)}/materials/$id', cancel: cancel), id: id);
  Future<MentorMaterialDetail> create(
    String classId,
    MentorUnit unit,
    Map<String, Object?> body, {
    CancelToken? cancel,
  }) async => _detail(
    await _api.post('${_base(classId)}/units/${unit.id}/materials', body: body, cancel: cancel),
    courseUnitId: unit.courseUnitId,
  );
  Future<MentorMaterialDetail> patch(
    String classId,
    MentorMaterial material, {
    required String title,
    required String? description,
  }) async => _detail(
    await _api.patch(
      '${_base(classId)}/materials/${material.id}',
      body: {'expectedRevision': material.revision, 'title': title, 'description': description},
    ),
    id: material.id,
  );
  Future<MentorMaterialDetail> submit(String classId, MentorMaterial material, {CancelToken? cancel}) async => _detail(
    await _api.post(
      '${_base(classId)}/materials/${material.id}/submit',
      body: {'expectedRevision': material.revision},
      cancel: cancel,
    ),
    id: material.id,
  );
  Future<void> delete(String classId, MentorMaterial material) async {
    await _api.delete('${_base(classId)}/materials/${material.id}', query: {'expectedRevision': material.revision});
  }

  Future<MaterialFileAccess> access(
    String classId,
    MentorMaterial material,
    String fileId, {
    CancelToken? cancel,
  }) async => MaterialFileAccess.fromJson(
    Json(
      await _api.get(
        '${_base(classId)}/materials/${material.id}/assets/$fileId/access',
        query: {'expectedRevision': material.revision},
        cancel: cancel,
      ),
      errorCode,
    ),
    materialId: material.id,
    fileId: fileId,
    revision: material.revision,
  );
}
