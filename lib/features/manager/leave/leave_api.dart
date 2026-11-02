import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/json.dart';
import '../manager_api.dart';
import '../../mentor/operations/operations_models.dart';
import '../manager_models.dart';
import 'leave_models.dart';

final managerLeaveApiProvider = Provider((ref) => ManagerLeaveApi(ref.watch(managerApiProvider)));

class ManagerLeaveApi {
  ManagerLeaveApi(this.api);
  final ManagerApi api;
  static const base = 'management/mentor-leave-requests';
  Future<List<ManagerLeave>> list(ManagerLeaveFilter f, {CancelToken? cancel}) => api.all(
    base,
    ManagerLeave.fromJson,
    id: (r) => r.request.id,
    query: {'status': f.status?.name, 'mentorId': f.mentorId},
    cancel: cancel,
  );
  Future<int> pendingCount({CancelToken? cancel}) async => (await api.page(
    base,
    ManagerLeave.fromJson,
    query: {'page': 1, 'pageSize': 1, 'status': 'PENDING'},
    cancel: cancel,
  )).total;
  Future<ManagerLeaveDetail> detail(String id, {CancelToken? cancel}) async {
    ManagerLeaveDetail? first;
    final items = <LeaveItem>[], ids = <String>{};
    final epoch = api.client.sessionEpoch;
    for (var n = 1; ; n++) {
      if (api.client.sessionEpoch != epoch) throw ApiError(status: 401, code: 'SESSION_CHANGED');
      final j = Json(
        await api.read('$base/$id', query: {'page': n, 'pageSize': 100}, cancel: cancel),
        managerErrorCode,
      );
      final d = ManagerLeaveDetail.fromJson(j), r = d.header.request;
      if (r.id != id || r.page != n || d.conflicts.length > d.conflictCount) j.fail();
      if (first != null &&
          (first.header.request.version != r.version ||
              first.header.request.count != r.count ||
              first.header.request.pageSize != r.pageSize ||
              first.conflictCount != d.conflictCount ||
              first.sourcesCurrent != d.sourcesCurrent)) {
        throw ApiError(status: 409, code: 'LEAVE_VERSION_CONFLICT');
      }
      first ??= d;
      for (final item in d.items) {
        if (!ids.add(item.sessionId)) j.fail();
        items.add(item);
      }
      if (items.length > r.count || (d.items.isEmpty && items.length < r.count)) j.fail();
      if (items.length == r.count) {
        return ManagerLeaveDetail(
          first.header,
          List.unmodifiable(items),
          first.conflicts,
          first.sourcesCurrent,
          first.conflictCount,
        );
      }
    }
  }

  Future<ManagerLeaveDecision> decide(String id, String action, IdempotentCall call) async {
    if (!['approve', 'reject'].contains(action)) throw ArgumentError.value(action);
    final j = Json(
      await api.client.post('$base/$id/$action', body: call.body, headers: call.headers),
      managerErrorCode,
    );
    final result = ManagerLeaveDecision.fromJson(j);
    if (result.request.id != id ||
        result.request.version != (call.body['expectedVersion']! as int) + 1 ||
        result.request.status.name != (action == 'approve' ? 'APPROVED' : 'REJECTED')) {
      j.fail();
    }
    return result;
  }
}
