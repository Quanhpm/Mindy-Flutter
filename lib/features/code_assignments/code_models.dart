// ignore_for_file: constant_identifier_names
import 'dart:convert';

import '../../core/network/api_error.dart';
import '../../core/network/json.dart';

/// Model bài tập lập trình (Phase 7, slice C6).
/// Contract: `Mindy-BE/docs/api_flow/PHASE_7_flow-api-breakdown.md` (DTO `code-student.dto.ts`, `code-review.dto.ts`).
/// Server chấm và tính điểm; app chỉ hiển thị. Test ẩn chỉ có trạng thái + thời gian (quyết định owner D10).
const codeError = 'INVALID_CODE_RESPONSE';

/// Bài tập không có `timeZone` trong DTO; trung tâm hoạt động theo giờ Việt Nam.
const codeFallbackTimeZone = 'Asia/Ho_Chi_Minh';

enum CodeLanguageKey { javascript, java21 }

enum AssignmentType { QUIZ, ZIP, CODE }

enum AssignmentPurpose { TEST, HOMEWORK }

enum AssignmentStatus { DRAFT, PUBLISHED, ARCHIVED }

enum SubmissionStatus { QUEUED, RUNNING, GRADED, FAILED, VOIDED }

enum TestVisibility { SAMPLE, HIDDEN }

enum CompareMode { EXACT, FLOAT, UNORDERED }

enum ScoringMode { PER_TEST, ALL_OR_NOTHING }

enum Difficulty { EASY, MEDIUM, HARD }

/// Kết quả từng test (chạy thử thêm `COMPLETED` cho input tự nhập).
const testStatuses = {
  'PASSED',
  'WRONG_ANSWER',
  'TIME_LIMIT',
  'MEMORY_LIMIT',
  'RUNTIME_ERROR',
  'OUTPUT_LIMIT',
  'COMPLETED',
};

/// Verdict tổng của một bài nộp.
const submissionVerdicts = {
  'ACCEPTED',
  'PARTIAL',
  'WRONG_ANSWER',
  'TIME_LIMIT',
  'MEMORY_LIMIT',
  'RUNTIME_ERROR',
  'OUTPUT_LIMIT',
  'COMPILE_ERROR',
};

final _score = RegExp(r'^\d{1,6}(?:\.\d{1,2})?$');

extension CodeJson on Json {
  /// Điểm dạng chuỗi thập phân (`"10.00"`), giữ nguyên chuỗi server để không lệch làm tròn.
  String score(String key) => _score.hasMatch(str(key)) ? str(key) : fail();
  String? scoreOrNull(String key) => has(key) ? score(key) : null;

  int count(String key) => integer(key) >= 0 ? integer(key) : fail();
  int? countOrNull(String key) => has(key) ? count(key) : null;

  /// Thời gian/bộ nhớ đo bởi runner: số không âm, làm tròn để hiển thị.
  int measure(String key) => number(key) >= 0 ? number(key).round() : fail();
  int? measureOrNull(String key) => has(key) ? measure(key) : null;

  String status(String key, Set<String> allowed) => allowed.contains(str(key)) ? str(key) : fail();
  String? statusOrNull(String key, Set<String> allowed) => has(key) ? status(key, allowed) : null;

  List<Object?> rawList(String key) {
    final value = raw(key);
    return value is List ? List<Object?>.unmodifiable(value) : fail();
  }
}

/// Hiển thị một giá trị JSON (tham số, kết quả) đúng như server gửi.
String formatCodeValue(Object? value) => jsonEncode(value);

/// Một dòng trong danh sách bài tập của lớp (`GET me/classes/:id/assignments`, `GET mentor/class-sessions/:id/assignments`).
class AssignmentItem {
  const AssignmentItem({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.purpose,
    required this.title,
    required this.maxScore,
    required this.dueAt,
    required this.maxAttempts,
    required this.status,
  });

  final String id;
  final String sessionId;
  final AssignmentType type;
  final AssignmentPurpose purpose;
  final String title;
  final String maxScore;
  final DateTime? dueAt;
  final int maxAttempts;
  final AssignmentStatus status;

  factory AssignmentItem.fromJson(Json j) => AssignmentItem(
    id: j.uuid('id'),
    sessionId: j.uuid('sessionId'),
    type: j.enumOf('type', AssignmentType.values),
    purpose: j.enumOf('purpose', AssignmentPurpose.values),
    title: j.str('title'),
    maxScore: j.score('maxScore'),
    dueAt: j.dateTimeOrNull('dueAt'),
    maxAttempts: j.count('maxAttempts'),
    status: j.enumOf('status', AssignmentStatus.values),
  );
}

class CodeParam {
  const CodeParam(this.name, this.type);
  final String name;
  final String type;
}

class CodeSignature {
  const CodeSignature({required this.functionName, required this.params, required this.returnType});
  final String functionName;
  final List<CodeParam> params;
  final String returnType;

  static const types = {
    'int',
    'long',
    'double',
    'boolean',
    'string',
    'int[]',
    'long[]',
    'double[]',
    'boolean[]',
    'string[]',
    'int[][]',
    'string[][]',
  };

  factory CodeSignature.fromJson(Json j) {
    final params = j.list('params', (p) => CodeParam(p.nonEmpty('name'), p.status('type', types)));
    if (params.isEmpty || params.length > 6) j.fail();
    return CodeSignature(
      functionName: j.nonEmpty('functionName'),
      params: List.unmodifiable(params),
      returnType: j.status('returnType', types),
    );
  }

  /// `twoSum(nums: int[], target: int) → int[]`
  String get display => '$functionName(${params.map((p) => '${p.name}: ${p.type}').join(', ')}) → $returnType';
}

class CodeProblem {
  const CodeProblem({
    required this.statementMd,
    required this.constraintsMd,
    required this.difficulty,
    required this.signature,
    required this.compareMode,
    required this.scoringMode,
    required this.cpuTimeLimitMs,
    required this.memoryLimitMb,
  });

  final String statementMd;
  final String constraintsMd;
  final Difficulty? difficulty;
  final CodeSignature signature;
  final CompareMode compareMode;
  final ScoringMode scoringMode;
  final int cpuTimeLimitMs;
  final int memoryLimitMb;

  factory CodeProblem.fromJson(Json j) => CodeProblem(
    statementMd: j.str('statementMd'),
    constraintsMd: j.str('constraintsMd'),
    difficulty: j.has('difficulty') ? j.enumOf('difficulty', Difficulty.values) : null,
    signature: CodeSignature.fromJson(j.obj('signature')),
    compareMode: j.enumOf('compareMode', CompareMode.values),
    scoringMode: j.enumOf('scoringMode', ScoringMode.values),
    cpuTimeLimitMs: j.count('cpuTimeLimitMs'),
    memoryLimitMb: j.count('memoryLimitMb'),
  );
}

class CodeLanguage {
  const CodeLanguage({
    required this.key,
    required this.displayName,
    required this.runtimeVersion,
    required this.starterCode,
  });
  final CodeLanguageKey key;
  final String displayName;
  final String runtimeVersion;
  final String starterCode;

  factory CodeLanguage.fromJson(Json j) => CodeLanguage(
    key: j.enumOf('key', CodeLanguageKey.values),
    displayName: j.nonEmpty('displayName'),
    runtimeVersion: j.str('runtimeVersion'),
    starterCode: j.str('starterCode'),
  );
}

class CodeSample {
  const CodeSample({required this.position, required this.display, required this.expected, this.explanationMd});
  final int position;
  final String display;
  final Object? expected;
  final String? explanationMd;

  factory CodeSample.fromJson(Json j) => CodeSample(
    position: j.count('position'),
    display: j.str('display'),
    expected: j.raw('expected'),
    explanationMd: j.strOrNull('explanationMd'),
  );
}

/// `GET me/assignments/:id/code`
class StudentCodeAssignment {
  const StudentCodeAssignment({
    required this.assignmentId,
    required this.sessionId,
    required this.title,
    required this.description,
    required this.status,
    required this.maxScore,
    required this.dueAt,
    required this.serverNow,
    required this.deadlinePassed,
    required this.maxAttempts,
    required this.attemptsUsed,
    required this.attemptsRemaining,
    required this.bestScore,
    required this.inFlightSubmissionId,
    required this.canSubmit,
    required this.problem,
    required this.languages,
    required this.samples,
    required this.hiddenTestCount,
  });

  final String assignmentId;
  final String sessionId;
  final String title;
  final String description;
  final AssignmentStatus status;
  final String maxScore;
  final DateTime dueAt;
  final DateTime serverNow;
  final bool deadlinePassed;
  final int maxAttempts;
  final int attemptsUsed;
  final int attemptsRemaining;
  final String? bestScore;
  final String? inFlightSubmissionId;
  final bool canSubmit;
  final CodeProblem problem;
  final List<CodeLanguage> languages;
  final List<CodeSample> samples;
  final int hiddenTestCount;

  factory StudentCodeAssignment.fromJson(Json j) {
    final status = j.enumOf('status', AssignmentStatus.values);
    final languages = j.list('languages', CodeLanguage.fromJson);
    final attemptsUsed = j.count('attemptsUsed'), attemptsRemaining = j.count('attemptsRemaining');
    final maxAttempts = j.count('maxAttempts');
    // Học viên chỉ thấy bài đã publish/archive; cần ≥ 1 ngôn ngữ, không trùng.
    if (status == AssignmentStatus.DRAFT ||
        languages.isEmpty ||
        languages.map((l) => l.key).toSet().length != languages.length ||
        attemptsRemaining > maxAttempts) {
      j.fail();
    }
    return StudentCodeAssignment(
      assignmentId: j.uuid('assignmentId'),
      sessionId: j.uuid('sessionId'),
      title: j.str('title'),
      description: j.str('description'),
      status: status,
      maxScore: j.score('maxScore'),
      dueAt: j.dateTime('dueAt'),
      serverNow: j.dateTime('serverNow'),
      deadlinePassed: j.boolean('deadlinePassed'),
      maxAttempts: maxAttempts,
      attemptsUsed: attemptsUsed,
      attemptsRemaining: attemptsRemaining,
      bestScore: j.scoreOrNull('bestScore'),
      inFlightSubmissionId: j.uuidOrNull('inFlightSubmissionId'),
      canSubmit: j.boolean('canSubmit'),
      problem: CodeProblem.fromJson(j.obj('problem')),
      languages: List.unmodifiable(languages),
      samples: List.unmodifiable(j.list('samples', CodeSample.fromJson)),
      hiddenTestCount: j.count('hiddenTestCount'),
    );
  }

  CodeLanguage language(CodeLanguageKey key) => languages.firstWhere((l) => l.key == key, orElse: () => languages.first);
}

/// `GET/PUT me/assignments/:id/code-drafts/:languageKey`. version 0 = chưa lưu (sourceCode là code khởi đầu).
class CodeDraft {
  const CodeDraft({required this.languageKey, required this.sourceCode, required this.version});
  final CodeLanguageKey languageKey;
  final String sourceCode;
  final int version;

  factory CodeDraft.fromJson(Json j) => CodeDraft(
    languageKey: j.enumOf('languageKey', CodeLanguageKey.values),
    sourceCode: j.str('sourceCode'),
    version: j.count('version'),
  );
}

class RunTest {
  const RunTest({
    required this.custom,
    required this.position,
    required this.display,
    required this.expected,
    required this.actual,
    required this.status,
    required this.console,
    required this.stderr,
    required this.timeMs,
    required this.memoryKb,
  });

  final bool custom;
  final int? position;
  final String display;
  final Object? expected;
  final Object? actual;
  final String status;
  final String console;
  final String stderr;
  final int timeMs;
  final int memoryKb;

  factory RunTest.fromJson(Json j) => RunTest(
    custom: j.status('kind', const {'SAMPLE', 'CUSTOM'}) == 'CUSTOM',
    position: j.countOrNull('position'),
    display: j.str('display'),
    expected: j.raw('expected'),
    actual: j.raw('actual'),
    status: j.status('status', testStatuses),
    console: j.str('console'),
    stderr: j.str('stderr'),
    timeMs: j.measure('timeMs'),
    memoryKb: j.measure('memoryKb'),
  );
}

/// `POST me/assignments/:id/code-runs` - chạy thử, không tính lượt.
class RunResult {
  const RunResult({required this.compileStatus, required this.compileOutput, required this.tests});
  final String compileStatus;
  final String compileOutput;
  final List<RunTest> tests;

  bool get compiled => compileStatus == 'OK';

  factory RunResult.fromJson(Json j) => RunResult(
    compileStatus: j.status('compileStatus', const {'OK', 'ERROR', 'TIMEOUT'}),
    compileOutput: j.str('compileOutput'),
    tests: List.unmodifiable(j.list('tests', RunTest.fromJson)),
  );
}

class SubmissionTest {
  const SubmissionTest({
    required this.position,
    required this.visibility,
    required this.status,
    required this.timeMs,
    required this.memoryKb,
    this.input,
    this.expected,
    this.actual,
    this.hasDetail = false,
  });

  final int position;
  final TestVisibility visibility;
  final String status;
  final int timeMs;
  final int memoryKb;
  final String? input;
  final Object? expected;
  final Object? actual;

  /// Chỉ test SAMPLE có dữ liệu chi tiết; test ẩn không bao giờ có input/expected/actual.
  final bool hasDetail;

  factory SubmissionTest.fromJson(Json j) {
    final visibility = j.enumOf('visibility', TestVisibility.values);
    final detail = j.has('inputArgs');
    // Lộ dữ liệu test ẩn = response sai hợp đồng, không hiển thị.
    if (visibility == TestVisibility.HIDDEN && (detail || j.has('expected') || j.has('actual'))) j.fail();
    return SubmissionTest(
      position: j.count('position'),
      visibility: visibility,
      status: j.status('status', testStatuses),
      timeMs: j.measure('timeMs'),
      memoryKb: j.measure('memoryKb'),
      input: detail ? j.rawList('inputArgs').map(formatCodeValue).join(', ') : null,
      expected: j.raw('expected'),
      actual: j.raw('actual'),
      hasDetail: detail,
    );
  }
}

/// Một lần nộp bài (`POST/GET me/assignments/:id/code-submissions`, `GET me/code-submissions/:id`).
class Submission {
  const Submission({
    required this.id,
    required this.assignmentId,
    required this.attemptNumber,
    required this.languageKey,
    required this.status,
    required this.verdict,
    required this.countsAsAttempt,
    required this.passedCount,
    required this.totalCount,
    required this.score,
    required this.maxScore,
    required this.compileOutput,
    required this.maxTimeMs,
    required this.submittedAt,
    required this.voidedReason,
    required this.retryAfterMs,
    required this.tests,
  });

  final String id;
  final String assignmentId;
  final int attemptNumber;
  final CodeLanguageKey languageKey;
  final SubmissionStatus status;
  final String? verdict;
  final bool countsAsAttempt;
  final int? passedCount;
  final int? totalCount;
  final String? score;
  final String maxScore;
  final String? compileOutput;
  final int? maxTimeMs;
  final DateTime submittedAt;
  final String? voidedReason;
  final int? retryAfterMs;
  final List<SubmissionTest> tests;

  bool get pending => status == SubmissionStatus.QUEUED || status == SubmissionStatus.RUNNING;

  factory Submission.fromJson(Json j) {
    final status = j.enumOf('status', SubmissionStatus.values);
    final verdict = j.statusOrNull('verdict', submissionVerdicts);
    final score = j.scoreOrNull('score');
    // Bài đã chấm phải có verdict + điểm; bài đang chờ chưa được có điểm.
    if ((status == SubmissionStatus.GRADED && (verdict == null || score == null)) ||
        ((status == SubmissionStatus.QUEUED || status == SubmissionStatus.RUNNING) && score != null)) {
      j.fail();
    }
    return Submission(
      id: j.uuid('id'),
      assignmentId: j.uuid('assignmentId'),
      attemptNumber: j.count('attemptNumber'),
      languageKey: j.enumOf('languageKey', CodeLanguageKey.values),
      status: status,
      verdict: verdict,
      countsAsAttempt: j.boolean('countsAsAttempt'),
      passedCount: j.countOrNull('passedCount'),
      totalCount: j.countOrNull('totalCount'),
      score: score,
      maxScore: j.score('maxScore'),
      compileOutput: j.strOrNull('compileOutput'),
      maxTimeMs: j.measureOrNull('maxTimeMs'),
      submittedAt: j.dateTime('submittedAt'),
      voidedReason: j.strOrNull('voidedReason'),
      retryAfterMs: j.countOrNull('retryAfterMs'),
      tests: j.has('tests') ? List.unmodifiable(j.list('tests', SubmissionTest.fromJson)) : const [],
    );
  }
}

/// Mentor: tổng hợp nộp bài (`GET mentor/assignments/:id/code-summary`), chỉ đọc trên app.
class CodeSummaryRow {
  const CodeSummaryRow({
    required this.studentId,
    required this.displayName,
    required this.attemptsUsed,
    required this.bestScore,
    required this.latestStatus,
    required this.latestVerdict,
    required this.failedCount,
  });

  final String studentId;
  final String displayName;
  final int attemptsUsed;
  final String? bestScore;
  final SubmissionStatus? latestStatus;
  final String? latestVerdict;
  final int failedCount;

  bool get submitted => latestStatus != null;

  factory CodeSummaryRow.fromJson(Json j) => CodeSummaryRow(
    studentId: j.uuid('studentId'),
    displayName: j.str('displayName'),
    attemptsUsed: j.count('attemptsUsed'),
    bestScore: j.scoreOrNull('bestScore'),
    latestStatus: j.has('latestStatus') ? j.enumOf('latestStatus', SubmissionStatus.values) : null,
    latestVerdict: j.statusOrNull('latestVerdict', submissionVerdicts),
    failedCount: j.count('failedCount'),
  );
}

class CodeSummary {
  const CodeSummary({
    required this.assignmentId,
    required this.maxScore,
    required this.maxAttempts,
    required this.dueAt,
    required this.students,
    required this.submitted,
    required this.notSubmitted,
    required this.accepted,
    required this.failed,
    required this.averageBestScore,
    required this.items,
    required this.total,
  });

  final String assignmentId;
  final String maxScore;
  final int maxAttempts;
  final DateTime? dueAt;
  final int students;
  final int submitted;
  final int notSubmitted;
  final int accepted;
  final int failed;
  final String? averageBestScore;
  final List<CodeSummaryRow> items;

  /// Tổng số dòng roster; lớn hơn [items] khi còn trang sau (app chỉ đọc trang đầu).
  final int total;

  factory CodeSummary.fromJson(Json j) {
    final totals = j.obj('totals');
    final page = Paged.fromJson(j, CodeSummaryRow.fromJson);
    page.check(1, page.items.length, codeError);
    return CodeSummary(
      assignmentId: j.uuid('assignmentId'),
      maxScore: j.score('maxScore'),
      maxAttempts: j.count('maxAttempts'),
      dueAt: j.dateTimeOrNull('dueAt'),
      students: totals.count('students'),
      submitted: totals.count('submitted'),
      notSubmitted: totals.count('notSubmitted'),
      accepted: totals.count('accepted'),
      failed: totals.count('failed'),
      averageBestScore: totals.has('averageBestScore') ? totals.str('averageBestScore') : null,
      items: List.unmodifiable(page.items),
      total: page.total,
    );
  }
}

/// Khoảng chờ giữa hai lần hỏi kết quả: theo `retryAfterMs` của server, kẹp 1–5 giây.
Duration pollDelay(Submission submission) =>
    Duration(milliseconds: (submission.retryAfterMs ?? 1500).clamp(1000, 5000).toInt());

/// Dừng hỏi tự động sau 60 giây; người dùng kéo để làm mới (REMAINING_WORK_PLAN §10b).
const pollLimit = Duration(seconds: 60);

/// Thời gian còn lại tới hạn nộp theo đồng hồ server, cộng thời gian đã trôi kể từ lúc nhận response.
Duration timeLeft(StudentCodeAssignment a, DateTime receivedAt, DateTime now) {
  final serverNow = a.serverNow.add(now.difference(receivedAt));
  final left = a.dueAt.difference(serverNow);
  return left.isNegative ? Duration.zero : left;
}

/// Kiểm tra id trong response khớp id đã hỏi (codeRule §6).
T expectId<T>(T value, String actual, String expected) =>
    actual == expected ? value : throw ApiError.invalidResponse(codeError);
