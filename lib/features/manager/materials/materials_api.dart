import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json.dart';
import '../../mentor/materials/materials_models.dart';
import '../manager_api.dart';
import '../manager_models.dart';

export '../../mentor/materials/materials_models.dart'
    show MentorMaterial, MentorMaterialDetail, MaterialContentType, MaterialReviewStatus, MaterialFileAccess;

typedef ManagerMaterialFilter = ({String? unitId, MaterialReviewStatus? status, MaterialContentType? type});

class ManagerMaterialSnapshot {
  const ManagerMaterialSnapshot(this.detail, this.sortOrder, this.availableAt, this.sessionId);
  final MentorMaterialDetail detail;
  final int sortOrder;
  final DateTime? availableAt;
  final String? sessionId;
  factory ManagerMaterialSnapshot.fromJson(Json j) => ManagerMaterialSnapshot(
    MentorMaterialDetail.fromJson(j),
    countValue(j, 'sortOrder'),
    j.dateTimeOrNull('availableAt'),
    j.uuidOrNull('sessionId'),
  );
}

final managerMaterialsApiProvider = Provider((ref) => ManagerMaterialsApi(ref.watch(managerApiProvider)));

class ManagerMaterialsApi {
  ManagerMaterialsApi(this.api);
  final ManagerApi api;
  Map<String, Object?> _query(ManagerMaterialFilter f) => {
    'courseUnitId': f.unitId,
    'reviewStatus': f.status?.name,
    'contentType': f.type?.name,
  };
  Future<List<MentorMaterial>> list(ManagerMaterialFilter f, {CancelToken? cancel}) =>
      api.all('manager/materials', MentorMaterial.fromJson, id: (m) => m.id, query: _query(f), cancel: cancel);
  Future<int> count(MaterialReviewStatus status, {CancelToken? cancel}) async => (await api.page(
    'manager/materials',
    MentorMaterial.fromJson,
    query: {'page': 1, 'pageSize': 1, 'reviewStatus': status.name},
    cancel: cancel,
  )).total;
  ManagerMaterialSnapshot parse(Object? data, {String? id, String? unitId}) {
    final j = Json(data, managerErrorCode), s = ManagerMaterialSnapshot.fromJson(Json(data, managerErrorCode));
    if ((id != null && s.detail.material.id != id) || (unitId != null && s.detail.material.courseUnitId != unitId)) {
      j.fail();
    }
    return s;
  }

  Future<ManagerMaterialSnapshot> detail(String id, {CancelToken? cancel}) async =>
      parse(await api.read('manager/materials/$id', cancel: cancel), id: id);
  Future<ManagerMaterialSnapshot> create(String unitId, Map<String, Object?> body) async =>
      parse(await api.client.post('manager/course-units/$unitId/materials', body: body), unitId: unitId);
  Future<ManagerMaterialSnapshot> patch(String id, Map<String, Object?> body) async =>
      parse(await api.client.patch('manager/materials/$id', body: body), id: id);
  Future<ManagerMaterialSnapshot> review(String id, String action, Map<String, Object?> body) async {
    if (!['approve', 'reject', 'publish', 'unpublish'].contains(action)) throw ArgumentError.value(action);
    return parse(await api.client.post('manager/materials/$id/$action', body: body), id: id);
  }

  Future<void> delete(String id, int revision) =>
      api.client.delete('manager/materials/$id', query: {'expectedRevision': revision});
  Future<MaterialFileAccess> access(MentorMaterial m, String fileId, {CancelToken? cancel}) async {
    final j = Json(
      await api.client.post('manager/materials/${m.id}/files/$fileId/access', cancel: cancel),
      managerErrorCode,
    );
    return MaterialFileAccess.fromJson(j, materialId: m.id, fileId: fileId, revision: m.revision);
  }
}
