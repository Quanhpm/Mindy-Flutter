import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import 'materials_models.dart';

class MaterialFailure implements Exception {
  const MaterialFailure(this.kind, {this.code = '', this.requestId});
  final String kind, code;
  final String? requestId;
  static MaterialFailure from(Object error, {bool write = false}) {
    if (error is MaterialFailure) return error;
    if (error is ApiError) {
      return MaterialFailure(
        error.code == 'SESSION_CHANGED' ||
                error.status == 401 ||
                (error.status == 403 && error.code != 'ORIGIN_NOT_ALLOWED')
            ? 'denied'
            : error.status == 404
            ? 'notFound'
            : error.status == 409 && error.code == 'MATERIAL_REVIEW_CONFLICT'
            ? 'conflict'
            : write && (error.isNetwork || error.status >= 500)
            ? 'uncertain'
            : error.isNetwork
            ? 'offline'
            : 'error',
        code: error.code,
        requestId: error.requestId,
      );
    }
    return MaterialFailure(write ? 'uncertain' : 'error');
  }
}

final staffMaterialServiceProvider = Provider((ref) {
  final epoch = ref.watch(sessionEpochProvider);
  return StaffMaterialService(
    ref.watch(apiClientProvider),
    () => ref.mounted && ref.read(sessionEpochProvider) == epoch,
  );
});

class StaffMaterialService {
  StaffMaterialService(this.api, this.active);
  final ApiClient api;
  final bool Function() active;
  String prefix(bool manager, String? classId) => manager
      ? 'manager/materials'
      : 'mentor/classes/${resourceId(classId)}/materials';
  Future<T> _read<T>(
    Future<Object?> Function() call,
    T Function(Json) parse, {
    bool write = false,
  }) async {
    if (!active()) throw const MaterialFailure('denied');
    try {
      final response = await call();
      if (!active()) throw const MaterialFailure('denied');
      return parse(Json(response, 'INVALID_MATERIAL_RESPONSE'));
    } catch (e) {
      throw MaterialFailure.from(e, write: write);
    }
  }

  Future<Paged<StaffMaterial>> list({
    required bool manager,
    String? classId,
    String? unitId,
    String status = '',
    int page = 1,
    int pageSize = 20,
  }) => _read(
    () => api.get(
      manager
          ? prefix(true, null)
          : 'mentor/classes/${resourceId(classId)}/units/${resourceId(unitId)}/materials',
      query: {
        'page': page,
        'pageSize': pageSize,
        if (status.isNotEmpty) 'reviewStatus': status,
      },
    ),
    (j) {
      final p = Paged.fromJson(j, StaffMaterial.new);
      if (p.page < 1 ||
          p.pageSize < 1 ||
          p.pageSize > 100 ||
          p.items.length > p.total ||
          p.items.length > p.pageSize) {
        j.fail();
      }
      return p;
    },
  );
  Future<StaffMaterial> detail(bool manager, String? classId, String id) =>
      _read(() => api.get('${prefix(manager, classId)}/${resourceId(id)}'), (
        j,
      ) {
        final m = StaffMaterial(j, detail: true);
        if (m.id != id) j.fail();
        return m;
      });
  Future<StaffMaterial> save(
    String classId,
    String unitId,
    Map<String, Object?> body, {
    String? id,
  }) => _read(
    () => id == null
        ? api.post(
            'mentor/classes/${resourceId(classId)}/units/${resourceId(unitId)}/materials',
            body: body,
          )
        : api.patch('${prefix(false, classId)}/${resourceId(id)}', body: body),
    (j) => StaffMaterial(j, detail: true),
    write: true,
  );
  Future<StaffMaterial> command(
    bool manager,
    String? classId,
    String id,
    String action,
    int revision, {
    String? reason,
  }) {
    if ((manager && action == 'submit') ||
        (!manager && action != 'submit') ||
        revision < 1 ||
        (action == 'reject' &&
            (reason == null ||
                reason.trim().isEmpty ||
                reason.trim().runes.length > 2000))) {
      throw const MaterialFailure('denied');
    }
    return _read(
      () => api.post(
        '${prefix(manager, classId)}/${resourceId(id)}/$action',
        body: {
          'expectedRevision': revision,
          if (action == 'reject') 'reason': reason!.trim(),
        },
      ),
      (j) => StaffMaterial(j, detail: true),
      write: true,
    );
  }

  Uri storageUrl(String value) {
    final uri = Uri.tryParse(value), base = Uri.parse(Env.apiUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.host == base.host ||
        (base.scheme == 'https' && uri.scheme != 'https')) {
      throw const MaterialFailure('error', code: 'STORAGE_HOST_UNSAFE');
    }
    return uri;
  }

  Future<({Uri url, DateTime expiresAt})> access(
    bool manager,
    String? classId,
    String id,
    int revision, {
    String? fileId,
  }) => _read(
    () => api.get(
      '${prefix(manager, classId)}/${resourceId(id)}/${fileId == null ? 'preview' : 'assets/${resourceId(fileId)}/access'}',
      query: {'expectedRevision': revision},
    ),
    (j) {
      final returnedFile = j.uuid('fileId');
      if (j.uuid('materialId') != id ||
          j.integer('revision') != revision ||
          (fileId != null && returnedFile != fileId)) {
        throw const MaterialFailure('conflict');
      }
      if (!['PRIMARY', 'INLINE_IMAGE', 'ATTACHMENT'].contains(j.str('role'))) {
        j.fail();
      }
      return (
        url: storageUrl(j.str('url')),
        expiresAt: j.dateTime('expiresAt'),
      );
    },
  );
  Future<({Map<String, String> classes, Map<String, String> mentors})>
  names() async {
    Future<Map<String, String>> collect(String path, String label) async {
      final result = <String, String>{};
      for (var page = 1; ; page++) {
        final data = Json(
          await api.get(path, query: {'page': page, 'pageSize': 100}),
        );
        final rows = data.list(
          'items',
          (j) => (id: j.uuid('id'), name: j.strOrNull(label)),
        );
        for (final row in rows) {
          if (row.name != null) result[row.id] = row.name!;
        }
        if (page * 100 >= data.integer('total')) return result;
        if (rows.isEmpty) {
          throw const MaterialFailure('error', code: 'INVALID_PAGE');
        }
      }
    }

    Future<Map<String, String>> safe(String path, String label) async {
      try {
        return await collect(path, label);
      } catch (_) {
        return {};
      }
    }

    final values = await Future.wait([
      safe('manager/classes', 'name'),
      safe('manager/mentors', 'displayName'),
    ]);
    return (classes: values[0], mentors: values[1]);
  }
}
