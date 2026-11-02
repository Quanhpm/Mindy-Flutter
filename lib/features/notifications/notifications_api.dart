import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/json.dart';
import 'notifications_models.dart';

final notificationsApiProvider = Provider((ref) => NotificationsApi(ref.watch(apiClientProvider)));

class NotificationsApi {
  NotificationsApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_NOTIFICATIONS_RESPONSE';

  Future<NotificationPage> page({String? cursor, CancelToken? cancel}) async => NotificationPage.fromJson(
    Json(
      await _api.get('notifications', query: {'limit': 30, 'cursor': cursor, 'unreadOnly': false}, cancel: cancel),
      errorCode,
    ),
  );
  Future<int> count({CancelToken? cancel}) async {
    final j = Json(await _api.get('notifications/unread-count', cancel: cancel), errorCode);
    final count = j.integer('unreadCount');
    if (count < 0) j.fail();
    return count;
  }

  Future<MindyNotification> read(String id) async {
    final j = Json(await _api.patch('notifications/$id/read'), errorCode);
    final result = MindyNotification.fromJson(j);
    if (result.id != id || result.readAt == null) j.fail();
    return result;
  }

  Future<void> readAll() async {
    final j = Json(await _api.post('notifications/read-all'), errorCode);
    j.dateTime('readAt');
    if (!j.boolean('resyncRequired')) j.fail();
  }
}
