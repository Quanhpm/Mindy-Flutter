import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/receipt_controller.dart';
export '../../../core/network/receipt_controller.dart' show CommandState, ReceiptController;
import '../../../core/network/idempotency.dart';
import '../../../core/session/session_controller.dart';
import '../schedule/schedule_providers.dart';
import '../session/session_context_api.dart';
import 'operations_api.dart';
import 'operations_models.dart';

final mentorLeavesProvider = FutureProvider.autoDispose.family<List<LeaveRequest>, LeaveStatus?>((ref, status) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorOperationsApiProvider).requests(status, cancel: cancel);
});
final mentorLeaveDetailProvider = FutureProvider.autoDispose.family<LeaveDetail, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorOperationsApiProvider).detail(id, cancel: cancel);
});
final mentorLeavePreviewProvider = FutureProvider.autoDispose.family<LeavePreview, LeaveQuery>((ref, query) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorOperationsApiProvider).preview(query, cancel: cancel);
});
final mentorLeaveSlotsProvider = FutureProvider.autoDispose.family<LeaveSlots, SlotQuery>((ref, query) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorOperationsApiProvider).slots(query, cancel: cancel);
});
final mentorNoteProvider = FutureProvider.autoDispose.family<TeachingNote, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorOperationsApiProvider).note(id, cancel: cancel);
});

final mentorLeaveCommandProvider = NotifierProvider.autoDispose<LeaveCommandController, CommandState<LeaveRequest>>(
  LeaveCommandController.new,
);

class LeaveCommandController extends ReceiptController<LeaveRequest> {
  String? _requestId;
  @override
  void resetTarget() => _requestId = null;
  Future<LeaveRequest?> create(LeaveDraft draft) {
    if (state.locked || state.conflict) return Future.value(null);
    if (draft.reason.trim().isEmpty ||
        draft.reason.trim().length > 1000 ||
        !draft.preview.eligible ||
        draft.mappings.isEmpty ||
        draft.mappings.length != draft.preview.sessions.length ||
        draft.mappings.map((m) => m.sessionId).toSet().length != draft.mappings.length ||
        draft.mappings.any((m) => !draft.preview.versions.any((v) => v.sessionId == m.sessionId))) {
      throw ApiError(status: 422, code: 'LEAVE_MAPPING_INVALID');
    }
    _requestId = null;
    return execute(draft.toJson());
  }

  Future<LeaveRequest?> withdraw(LeaveRequest request, String reason) {
    if (state.locked || state.conflict) return Future.value(null);
    if (request.status != LeaveStatus.PENDING || reason.trim().isEmpty || reason.trim().length > 1000) {
      throw ApiError(status: 422, code: 'LEAVE_REASON_INVALID');
    }
    _requestId = request.id;
    return execute({'expectedVersion': request.version, 'reason': reason.trim()});
  }

  @override
  Future<LeaveRequest> send(IdempotentCall call) =>
      ref.read(mentorOperationsApiProvider).leaveCommand(call, requestId: _requestId);
  @override
  void invalidate(LeaveRequest result) {
    ref.invalidate(mentorLeavesProvider);
    ref.invalidate(mentorLeaveDetailProvider(result.id));
    ref.invalidate(mentorScheduleProvider);
  }
}

final mentorNoteSaveProvider = NotifierProvider.autoDispose
    .family<NoteSaveController, CommandState<TeachingNote>, String>(NoteSaveController.new);

class NoteSaveController extends ReceiptController<TeachingNote> {
  NoteSaveController(this.sessionId);
  final String sessionId;
  Future<TeachingNote?> save(int version, String content, String nextSteps) {
    if (content.length > 10000 || nextSteps.length > 5000 || version < 0) {
      throw ApiError(status: 422, code: 'TEACHING_NOTE_INVALID');
    }
    return execute({'expectedVersion': version, 'content': content, 'nextSteps': nextSteps});
  }

  @override
  Future<TeachingNote> send(IdempotentCall call) => ref.read(mentorOperationsApiProvider).saveNote(sessionId, call);
  @override
  void invalidate(TeachingNote result) {
    ref.invalidate(mentorNoteProvider(sessionId));
    ref.invalidate(mentorRoomProvider(sessionId));
  }
}

final mentorMeetingSaveProvider = NotifierProvider.autoDispose
    .family<MeetingSaveController, CommandState<MeetingUpdate>, String>(MeetingSaveController.new);

/// PATCH meeting không có receipt: kết quả chưa rõ chỉ đọc lại, không replay.
class MeetingSaveController extends Notifier<CommandState<MeetingUpdate>> {
  MeetingSaveController(this.sessionId);
  final String sessionId;
  void Function()? _release;
  @override
  CommandState<MeetingUpdate> build() {
    ref.watch(sessionEpochProvider);
    _release?.call();
    _release = null;
    return const CommandState();
  }

  void reviewed() {
    if (!state.busy) {
      _release?.call();
      _release = null;
      state = const CommandState();
    }
  }

  Future<MeetingUpdate?> save(int version, String? url) async {
    if (state.locked || state.conflict) return null;
    final epoch = ref.read(sessionEpochProvider);
    _release ??= ref.keepAlive().close;
    state = const CommandState(busy: true);
    try {
      final result = await ref.read(mentorOperationsApiProvider).meeting(sessionId, version: version, url: url);
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      _release?.call();
      _release = null;
      state = CommandState(result: result);
      ref.invalidate(mentorRoomProvider(sessionId));
      ref.invalidate(mentorScheduleProvider);
      return result;
    } catch (error) {
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      final unknown = error is! ApiError || error.status == 0 || error.status >= 500 || error.status == 408;
      state = CommandState(error: error, retryPending: unknown, conflict: error is ApiError && error.status == 409);
      if (!unknown && !state.conflict) {
        _release?.call();
        _release = null;
      }
      return null;
    }
  }
}
