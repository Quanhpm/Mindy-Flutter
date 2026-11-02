import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/network/idempotency.dart';
import '../../core/session/session_controller.dart';
import 'code_api.dart';
import 'code_models.dart';

// ------------------------------------------------------------------ Đọc dữ liệu

/// Bài code đã publish của một lớp (học viên).
final classCodeAssignmentsProvider = FutureProvider.autoDispose.family<List<AssignmentItem>, String>((ref, classId) {
  ref.watch(sessionEpochProvider);
  return ref.watch(codeAssignmentsApiProvider).classAssignments(classId);
});

/// Đề + lượt + điểm. Giữ thời điểm nhận để đếm ngược theo đồng hồ server.
final codeAssignmentProvider =
    FutureProvider.autoDispose.family<({StudentCodeAssignment assignment, DateTime receivedAt}), String>((
      ref,
      id,
    ) async {
      ref.watch(sessionEpochProvider);
      final assignment = await ref.watch(codeAssignmentsApiProvider).assignment(id);
      return (assignment: assignment, receivedAt: DateTime.now());
    });

final codeSubmissionsProvider = FutureProvider.autoDispose.family<List<Submission>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(codeAssignmentsApiProvider).submissions(id);
});

/// Mentor: bài code của một buổi + bảng tổng hợp (chỉ đọc).
final sessionCodeAssignmentsProvider = FutureProvider.autoDispose.family<List<AssignmentItem>, String>((ref, sessionId) {
  ref.watch(sessionEpochProvider);
  return ref.watch(codeAssignmentsApiProvider).sessionAssignments(sessionId);
});

final codeSummaryProvider = FutureProvider.autoDispose.family<CodeSummary, String>((ref, assignmentId) {
  ref.watch(sessionEpochProvider);
  return ref.watch(codeAssignmentsApiProvider).summary(assignmentId);
});

// ------------------------------------------------------------------ Theo dõi kết quả chấm

class SubmissionWatch {
  const SubmissionWatch(this.submission, {this.timedOut = false, this.error});
  final Submission submission;

  /// Đã hỏi quá [pollLimit] mà chưa có kết quả: dừng hỏi tự động, cho làm mới tay.
  final bool timedOut;

  /// Lỗi ở lần hỏi lại; vẫn giữ kết quả cũ trên màn.
  final Object? error;

  bool get polling => submission.pending && !timedOut && error == null;
}

/// Hỏi `GET me/code-submissions/:id` theo `retryAfterMs` tới khi có kết quả, tối đa [pollLimit].
/// Socket `code_submission.updated` chỉ là tín hiệu phụ; polling là đường chính.
final codeSubmissionWatchProvider = AsyncNotifierProvider.autoDispose
    .family<CodeSubmissionWatchController, SubmissionWatch, String>(CodeSubmissionWatchController.new);

class CodeSubmissionWatchController extends AsyncNotifier<SubmissionWatch> {
  CodeSubmissionWatchController(this.submissionId);
  final String submissionId;
  Timer? _timer;
  DateTime _started = DateTime.now();

  @override
  Future<SubmissionWatch> build() async {
    ref.watch(sessionEpochProvider);
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _started = DateTime.now();
    final submission = await ref.watch(codeAssignmentsApiProvider).submission(submissionId);
    _schedule(submission);
    return SubmissionWatch(submission);
  }

  void _schedule(Submission submission) {
    _timer?.cancel();
    if (submission.pending) _timer = Timer(pollDelay(submission), _tick);
  }

  Future<void> _tick() async {
    final current = state.value;
    if (!ref.mounted || current == null) return;
    if (DateTime.now().difference(_started) >= pollLimit) {
      state = AsyncData(SubmissionWatch(current.submission, timedOut: true));
      return;
    }
    try {
      final next = await ref.read(codeAssignmentsApiProvider).submission(submissionId);
      if (!ref.mounted) return;
      state = AsyncData(SubmissionWatch(next));
      _schedule(next);
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(SubmissionWatch(current.submission, error: error));
    }
  }

  /// Làm mới tay: bắt đầu lại chu kỳ 60 giây.
  void restart() => ref.invalidateSelf();
}

// ------------------------------------------------------------------ Nháp (autosave)

typedef DraftKey = ({String assignmentId, CodeLanguageKey language});

enum DraftSave { idle, saving, saved, failed, conflict }

class DraftState {
  const DraftState(this.draft, {this.save = DraftSave.idle, this.error});
  final CodeDraft draft;
  final DraftSave save;
  final Object? error;
}

/// Nháp theo (bài, ngôn ngữ). Lưu theo version; 409 = nơi khác (web/máy khác) đã lưu bản mới hơn,
/// không ghi đè: người dùng chọn tải bản mới.
final codeDraftProvider = AsyncNotifierProvider.autoDispose.family<CodeDraftController, DraftState, DraftKey>(
  CodeDraftController.new,
);

class CodeDraftController extends AsyncNotifier<DraftState> {
  CodeDraftController(this.key);
  final DraftKey key;
  Future<void>? _saving;
  String? _queued;

  @override
  Future<DraftState> build() async {
    ref.watch(sessionEpochProvider);
    _queued = null;
    return DraftState(await ref.watch(codeAssignmentsApiProvider).draft(key.assignmentId, key.language));
  }

  /// Lưu [source] nếu khác bản server. Đang lưu thì giữ bản mới nhất và lưu tiếp sau khi xong.
  Future<void> save(String source) async {
    final current = state.value;
    if (current == null || current.save == DraftSave.conflict) return;
    if (_saving != null) {
      _queued = source;
      await _saving;
      return;
    }
    if (source == current.draft.sourceCode && current.draft.version > 0) return;
    _saving = _save(current, source);
    try {
      await _saving;
    } finally {
      _saving = null;
    }
    final queued = _queued;
    _queued = null;
    if (queued != null && ref.mounted) await save(queued);
  }

  Future<void> _save(DraftState current, String source) async {
    final epoch = ref.read(sessionEpochProvider);
    state = AsyncData(DraftState(current.draft, save: DraftSave.saving));
    try {
      final saved = await ref
          .read(codeAssignmentsApiProvider)
          .saveDraft(key.assignmentId, key.language, source, current.draft.version);
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
      state = AsyncData(DraftState(saved, save: DraftSave.saved));
    } catch (error) {
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
      final conflict = error is ApiError && error.code == 'CODE_DRAFT_VERSION_CONFLICT';
      state = AsyncData(DraftState(current.draft, save: conflict ? DraftSave.conflict : DraftSave.failed, error: error));
    }
  }

  /// Bỏ bản đang gõ, đọc bản mới nhất từ server.
  void reload() => ref.invalidateSelf();
}

// ------------------------------------------------------------------ Chạy thử / Nộp bài

class CodeCommandState {
  const CodeCommandState({this.busy = false, this.run, this.submitted, this.error, this.retryPending = false});
  final bool busy;
  final RunResult? run;
  final Submission? submitted;
  final Object? error;

  /// Nộp bài lỗi mạng/không rõ kết quả: chỉ cho gửi lại đúng yêu cầu cũ.
  final bool retryPending;
}

final codeCommandProvider = NotifierProvider.autoDispose.family<CodeCommandController, CodeCommandState, String>(
  CodeCommandController.new,
);

/// Một lệnh tại một thời điểm cho một bài. Không tự retry (codeRule §1.3).
class CodeCommandController extends Notifier<CodeCommandState> {
  CodeCommandController(this.assignmentId);
  final String assignmentId;
  IdempotentCall? _pending;

  @override
  CodeCommandState build() {
    ref.watch(sessionEpochProvider);
    _pending = null;
    return const CodeCommandState();
  }

  static bool _ambiguous(Object error) =>
      error is! ApiError || error.status == 0 || error.status == 408 || error.status >= 500;

  Future<RunResult?> run(CodeLanguageKey language, String source, {List<Object?>? customArgs}) async {
    if (state.busy || state.retryPending) return null;
    final epoch = ref.read(sessionEpochProvider);
    state = const CodeCommandState(busy: true);
    try {
      final result = await ref
          .read(codeAssignmentsApiProvider)
          .run(assignmentId, language, source, customArgs: customArgs);
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      state = CodeCommandState(run: result);
      return result;
    } catch (error) {
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) state = CodeCommandState(error: error);
      return null;
    }
  }

  /// Bấm Nộp = một [IdempotentCall] mới; [retry] gửi lại đúng call trước (cùng key + body).
  Future<Submission?> submit(CodeLanguageKey language, String source, {bool retry = false}) async {
    if (state.busy || (retry && _pending == null) || (!retry && state.retryPending)) return null;
    final call = retry ? _pending! : IdempotentCall({'languageKey': language.name, 'sourceCode': source});
    _pending = call;
    final epoch = ref.read(sessionEpochProvider);
    state = const CodeCommandState(busy: true);
    try {
      final submission = await ref.read(codeAssignmentsApiProvider).submit(assignmentId, call);
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      _pending = null;
      state = CodeCommandState(submitted: submission);
      ref.invalidate(codeAssignmentProvider(assignmentId));
      ref.invalidate(codeSubmissionsProvider(assignmentId));
      return submission;
    } catch (error) {
      if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return null;
      final again = _ambiguous(error);
      if (!again) _pending = null;
      state = CodeCommandState(error: error, retryPending: again);
      return null;
    }
  }

  void clear() {
    if (!state.busy && !state.retryPending) state = const CodeCommandState();
  }
}
