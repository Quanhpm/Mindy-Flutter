import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import 'session_context_models.dart';

final mentorSessionApiProvider = Provider((ref) => MentorSessionApi(ref.watch(apiClientProvider)));

class MentorSessionApi {
  MentorSessionApi(this._api);
  final ApiClient _api;
  Future<TeachingRoom> room(String sessionId, {CancelToken? cancel}) async => TeachingRoom.fromJson(
    Json(await _api.get('class-sessions/$sessionId/context', cancel: cancel), 'INVALID_MENTOR_CONTEXT_RESPONSE'),
    sessionId: sessionId,
  );
}

final mentorRoomProvider = FutureProvider.autoDispose.family<TeachingRoom, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorSessionApiProvider).room(id, cancel: cancel);
});
