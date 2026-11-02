import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/json.dart';
import '../manager_api.dart';
import '../manager_models.dart';
import 'collections_models.dart';

final managerCollectionsApiProvider = Provider((ref) => ManagerCollectionsApi(ref.watch(managerApiProvider)));

class ManagerCollectionsApi {
  ManagerCollectionsApi(this.api);
  final ManagerApi api;
  Future<List<CollectionOrder>> list(CollectionFilter f, {CancelToken? cancel}) => api.all(
    'manager/orders',
    CollectionOrder.fromJson,
    id: (o) => o.id,
    query: {
      'paymentType': 'CASH',
      'status': f.status?.name,
      'classId': f.classId,
      if (f.code.isNotEmpty) 'orderCode': f.code,
    },
    cancel: cancel,
  );
  Future<int> count({CancelToken? cancel}) async => (await api.page(
    'manager/orders',
    CollectionOrder.fromJson,
    query: {'page': 1, 'pageSize': 1, 'paymentType': 'CASH', 'status': 'PENDING'},
    cancel: cancel,
  )).total;
  Future<CollectionOrder> detail(String id, {CancelToken? cancel}) async {
    final j = Json(await api.read('manager/orders/$id', cancel: cancel), managerErrorCode);
    final o = CollectionOrder.fromJson(j);
    if (o.id != id) j.fail();
    return o;
  }

  Future<void> confirm(String id, int amount) async {
    final j = Json(
      await api.client.post('manager/cash-orders/$id/confirm', body: {'receivedAmount': amount}),
      managerErrorCode,
    );
    if (j.uuid('id') != id ||
        j.str('status') != 'PAID' ||
        j.str('paymentType') != 'CASH' ||
        managerMoney(j, 'totalAmount') != amount) {
      j.fail();
    }
  }
}
