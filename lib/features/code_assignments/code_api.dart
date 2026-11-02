import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/idempotency.dart';
import '../../core/network/json.dart';
import '../../core/network/pagination.dart';
import 'code_models.dart';

final codeAssignmentsApiProvider = Provider((ref) => CodeAssignmentsApi(ref.watch(apiClientProvider)));

/// Endpoint bài tập lập trình (Phase 7). Học viên: `me/...`; Mentor (chỉ đọc trên app): `mentor/...`.
class CodeAssignmentsApi {
  CodeAssignmentsApi(this._api);
  final ApiClient _api;

  /// Chạy thử chờ runner chấm các test mẫu: lâu hơn timeout mặc định 60 giây.
  static const runTimeout = Duration(seconds: 95);

  Json _json(Object? value) => Json(value, codeError);

  Future<List<AssignmentItem>> _assignments(String path) async {
    final items = await readAllPages<AssignmentItem>(
      (page) async => Paged.fromJson(
        _json(await _api.get(path, query: {'type': 'CODE', 'page': page, 'pageSize': 100})),
        AssignmentItem.fromJson,
      ),
      idOf: (a) => a.id,
      errorCode: codeError,
    );
    // Đã lọc type=CODE ở server; dòng khác loại là response sai.
    if (items.any((a) => a.type != AssignmentType.CODE)) throw ApiError.invalidResponse(codeError);
    return items;
  }

  // ------------------------------------------------------------------ Học viên

  Future<List<AssignmentItem>> classAssignments(String classId) => _assignments('me/classes/$classId/assignments');

  Future<StudentCodeAssignment> assignment(String id) async {
    final a = StudentCodeAssignment.fromJson(_json(await _api.get('me/assignments/$id/code')));
    return expectId(a, a.assignmentId, id);
  }

  Future<CodeDraft> draft(String id, CodeLanguageKey language) async {
    final d = CodeDraft.fromJson(_json(await _api.get('me/assignments/$id/code-drafts/${language.name}')));
    return expectId(d, d.languageKey.name, language.name);
  }

  /// `expectedVersion` = version đang giữ; 409 `CODE_DRAFT_VERSION_CONFLICT` khi nơi khác (web) đã lưu.
  Future<CodeDraft> saveDraft(String id, CodeLanguageKey language, String source, int expectedVersion) async {
    final d = CodeDraft.fromJson(
      _json(
        await _api.put(
          'me/assignments/$id/code-drafts/${language.name}',
          body: {'sourceCode': source, 'expectedVersion': expectedVersion},
        ),
      ),
    );
    return expectId(d, d.languageKey.name, language.name);
  }

  /// Chạy với các test mẫu; không tính lượt. Rate limit theo học viên (429).
  /// [customArgs] = một bộ input học viên tự nhập (đúng thứ tự tham số); bỏ trống = chạy các ví dụ.
  Future<RunResult> run(String id, CodeLanguageKey language, String source, {List<Object?>? customArgs}) async =>
      RunResult.fromJson(
        _json(
          await _api.post(
            'me/assignments/$id/code-runs',
            body: {
              'languageKey': language.name,
              'sourceCode': source,
              'customArgs': ?customArgs,
            },
            timeout: runTimeout,
          ),
        ),
      );

  /// Nộp bài. Lỗi mạng thì gửi lại ĐÚNG [call] (cùng key + body); server trả lại bài đã tạo.
  Future<Submission> submit(String id, IdempotentCall call) async {
    final s = Submission.fromJson(
      _json(await _api.post('me/assignments/$id/code-submissions', body: call.body, headers: call.headers)),
    );
    return expectId(s, s.assignmentId, id);
  }

  Future<List<Submission>> submissions(String id) async {
    final list = _json(await _api.get('me/assignments/$id/code-submissions')).list('items', Submission.fromJson);
    if (list.any((s) => s.assignmentId != id)) throw ApiError.invalidResponse(codeError);
    return List.unmodifiable(list);
  }

  Future<Submission> submission(String submissionId) async {
    final s = Submission.fromJson(_json(await _api.get('me/code-submissions/$submissionId')));
    return expectId(s, s.id, submissionId);
  }

  // ------------------------------------------------------------------ Mentor

  Future<List<AssignmentItem>> sessionAssignments(String sessionId) async {
    final items = await _assignments('mentor/class-sessions/$sessionId/assignments');
    if (items.any((a) => a.sessionId != sessionId)) throw ApiError.invalidResponse(codeError);
    return items;
  }

  /// Trang đầu (100 học viên) của bảng tổng hợp; xem đầy đủ trên web.
  Future<CodeSummary> summary(String assignmentId) async {
    final s = CodeSummary.fromJson(
      _json(await _api.get('mentor/assignments/$assignmentId/code-summary', query: {'page': 1, 'pageSize': 100})),
    );
    return expectId(s, s.assignmentId, assignmentId);
  }
}
