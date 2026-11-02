import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/concurrent.dart';
import '../classes/classes_models.dart';
import '../classes/classes_providers.dart';
import 'materials_api.dart';
import 'materials_models.dart';

final mentorMaterialsProvider = FutureProvider.autoDispose.family<MentorMaterials, String>((ref, classId) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorMaterialsApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(classId).future);
  if (workspace.status == MentorClassStatus.CANCELLED) {
    throw ApiError(status: 403, code: 'MATERIAL_CLASS_CANCELLED');
  }
  if (!ref.mounted) {
    throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  }
  final units = await ref.watch(mentorClassUnitsProvider(classId).future);
  final groups = await mapConcurrent(
    units,
    (unit) async => UnitMaterials(
      unit: unit,
      items: await api.all(classId, unit, cancel: cancel),
    ),
  );
  return MentorMaterials(workspace: workspace, groups: groups);
});

typedef MaterialQuery = ({String classId, String materialId});
final mentorMaterialDetailProvider = FutureProvider.autoDispose.family<MentorMaterialDetail, MaterialQuery>((
  ref,
  query,
) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final api = ref.watch(mentorMaterialsApiProvider);
  final workspace = await ref.watch(mentorPrimaryWorkspaceProvider(query.classId).future);
  if (workspace.status == MentorClassStatus.CANCELLED) {
    throw ApiError(status: 403, code: 'MATERIAL_CLASS_CANCELLED');
  }
  return api.detail(query.classId, query.materialId, cancel: cancel);
});

typedef MaterialAccessQuery = ({String classId, MentorMaterial material, String fileId});
final mentorMaterialAccessProvider = FutureProvider.autoDispose.family<MaterialFileAccess, MaterialAccessQuery>((
  ref,
  query,
) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorMaterialsApiProvider).access(query.classId, query.material, query.fileId, cancel: cancel);
});
