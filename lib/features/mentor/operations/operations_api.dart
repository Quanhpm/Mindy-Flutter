import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import 'operations_models.dart';

final mentorOperationsApiProvider = Provider((ref) => MentorOperationsApi(ref.watch(apiClientProvider)));

class MentorOperationsApi {
  MentorOperationsApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_OPERATIONS_RESPONSE';
  Future<LeavePreview> preview(LeaveQuery query, {CancelToken? cancel}) async => LeavePreview.fromJson(
    Json(
      await _api.post(
        'mentor/leave-requests/preview',
        body: {'fromDate': query.fromDate, 'toDate': query.toDate, 'period': query.period.name},
        cancel: cancel,
      ),
      errorCode,
    ),
  );
  Future<LeaveSlots> slots(SlotQuery query, {CancelToken? cancel}) async => LeaveSlots.fromJson(
    Json(
      await _api.post(
        'mentor/leave-requests/makeup-slots',
        body: {'sourceSessionId': query.sessionId, 'targetDate': query.targetDate, 'targetPeriod': query.period.name},
        cancel: cancel,
      ),
      errorCode,
    ),
  );
  Future<List<LeaveRequest>> requests(LeaveStatus? status, {CancelToken? cancel}) => readAllPages(
    (page) async => Paged.fromJson(
      Json(
        await _api.get(
          'mentor/leave-requests',
          query: {'page': page, 'pageSize': 100, 'status': status?.name},
          cancel: cancel,
        ),
        errorCode,
      ),
      LeaveRequest.fromJson,
    ),
    idOf: (r) => r.id,
    errorCode: errorCode,
  );
  Future<LeaveDetail> detail(String id, {CancelToken? cancel}) async {
    LeaveRequest? first;
    final items = <LeaveItem>[];
    final ids = <String>{};
    for (var page = 1; ; page++) {
      final current = LeaveRequest.fromJson(
        Json(
          await _api.get('mentor/leave-requests/$id', query: {'page': page, 'pageSize': 100}, cancel: cancel),
          errorCode,
        ),
      );
      if (current.id != id ||
          current.page != page ||
          (first != null &&
              (current.version != first.version ||
                  current.count != first.count ||
                  current.pageSize != first.pageSize))) {
        throw ApiError(status: 409, code: 'LEAVE_SOURCE_STALE');
      }
      first ??= current;
      for (final item in current.items) {
        if (!ids.add(item.sessionId)) throw ApiError.invalidResponse(errorCode);
        items.add(item);
      }
      if (items.length > current.count || (current.items.isEmpty && items.length < current.count)) {
        throw ApiError.invalidResponse(errorCode);
      }
      if (items.length == current.count) {
        return LeaveDetail(first, List.unmodifiable(items));
      }
    }
  }

  Future<LeaveRequest> leaveCommand(IdempotentCall call, {String? requestId}) async {
    final response = await _api.post(
      requestId == null ? 'mentor/leave-requests' : 'mentor/leave-requests/$requestId/withdraw',
      body: call.body,
      headers: call.headers,
    );
    final request = LeaveRequest.fromJson(Json(response, errorCode));
    if (requestId != null && request.id != requestId) {
      throw ApiError.invalidResponse(errorCode);
    }
    return request;
  }

  Future<TeachingNote> note(String id, {CancelToken? cancel}) async {
    final note = TeachingNote.fromJson(
      Json(await _api.get('class-sessions/$id/teaching-notes', cancel: cancel), errorCode),
    );
    if (note.sessionId != id) throw ApiError.invalidResponse(errorCode);
    return note;
  }

  Future<TeachingNote> saveNote(String id, IdempotentCall call) async {
    final note = TeachingNote.fromJson(
      Json(await _api.put('class-sessions/$id/teaching-notes', body: call.body, headers: call.headers), errorCode),
    );
    if (note.sessionId != id || note.version != (call.body['expectedVersion']! as int) + 1) {
      throw ApiError.invalidResponse(errorCode);
    }
    return note;
  }

  Future<MeetingUpdate> meeting(String id, {required int version, required String? url}) async {
    final result = MeetingUpdate.fromJson(
      Json(
        await _api.patch(
          'mentor/class-sessions/$id/meeting-url',
          body: {'expectedVersion': version, 'meetingUrl': url},
        ),
        errorCode,
      ),
    );
    if (result.sessionId != id || result.version < version || result.version > version + 1 || result.url != url) {
      throw ApiError.invalidResponse(errorCode);
    }
    return result;
  }
}
