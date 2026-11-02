import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/clock.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/code_assignments/code_api.dart';
import 'package:mindy_flutter/features/code_assignments/code_editing.dart';
import 'package:mindy_flutter/features/code_assignments/code_editor_screen.dart';
import 'package:mindy_flutter/features/code_assignments/code_models.dart';
import 'package:mindy_flutter/features/code_assignments/code_problem_screen.dart';
import 'package:mindy_flutter/features/code_assignments/code_providers.dart';
import 'package:mindy_flutter/features/mentor/code/mentor_session_code_screen.dart';
import 'package:mindy_flutter/features/schedule/schedule_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mentor_mf2_test.dart' show pumpScreen;

const assignmentId = '00000000-0000-4000-8000-00000000c001';
const sessionId = '00000000-0000-4000-8000-00000000c002';
const submissionId = '00000000-0000-4000-8000-00000000c003';
const studentId = '00000000-0000-4000-8000-00000000c004';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody body(Object? data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

CodeAssignmentsApi api(
  FutureOr<ResponseBody> Function(RequestOptions) handler,
) => CodeAssignmentsApi(
  ApiClient(cookieJar: CookieJar())..dio.httpClientAdapter = _Adapter(handler),
);

Map<String, Object?> assignmentJson({
  bool canSubmit = true,
  String? inFlight,
}) => {
  'assignmentId': assignmentId,
  'sessionId': sessionId,
  'title': 'Tổng hai số',
  'description': 'Bài tập sau buổi 3',
  'purpose': 'HOMEWORK',
  'status': 'PUBLISHED',
  'maxScore': '10.00',
  'dueAt': '2026-11-04T08:00:00.000Z',
  'serverNow': '2026-11-02T08:00:00.000Z',
  'deadlinePassed': false,
  'maxAttempts': 10,
  'attemptsUsed': 1,
  'attemptsRemaining': 9,
  'bestScore': '4.00',
  'bestSubmissionId': submissionId,
  'inFlightSubmissionId': inFlight,
  'canSubmit': canSubmit,
  'problem': {
    'statementMd': 'Trả về chỉ số hai phần tử có tổng bằng target.',
    'constraintsMd': '2 ≤ n ≤ 10^4',
    'difficulty': 'EASY',
    'signature': {
      'functionName': 'twoSum',
      'params': [
        {'name': 'nums', 'type': 'int[]'},
        {'name': 'target', 'type': 'int'},
      ],
      'returnType': 'int[]',
    },
    'compareMode': 'EXACT',
    'scoringMode': 'PER_TEST',
    'cpuTimeLimitMs': 1000,
    'memoryLimitMb': 128,
  },
  'languages': [
    {
      'key': 'javascript',
      'displayName': 'JavaScript',
      'runtimeVersion': 'Node.js 22',
      'editorMode': 'javascript',
      'starterCode': 'function twoSum(nums, target) {\n}\n',
    },
    {
      'key': 'java21',
      'displayName': 'Java 21',
      'runtimeVersion': 'Java 21',
      'editorMode': 'java',
      'starterCode': 'class Solution {\n}\n',
    },
  ],
  'samples': [
    {
      'position': 1,
      'inputArgs': [
        [2, 7, 11, 15],
        9,
      ],
      'expected': [0, 1],
      'display': 'nums = [2,7,11,15], target = 9',
      'explanationMd': null,
    },
  ],
  'hiddenTestCount': 3,
};

Map<String, Object?> submissionJson({
  String status = 'GRADED',
  bool hiddenLeak = false,
}) => {
  'id': submissionId,
  'assignmentId': assignmentId,
  'attemptNumber': 1,
  'languageKey': 'javascript',
  'runtimeVersion': 'Node.js 22',
  'status': status,
  'verdict': status == 'GRADED' ? 'PARTIAL' : null,
  'countsAsAttempt': true,
  'passedCount': status == 'GRADED' ? 2 : null,
  'totalCount': status == 'GRADED' ? 4 : null,
  'score': status == 'GRADED' ? '4.00' : null,
  'maxScore': '10.00',
  'compileOutput': null,
  'maxTimeMs': 12,
  'maxMemoryKb': 40000,
  'submittedAt': '2026-11-02T07:30:00.000Z',
  'judgedAt': status == 'GRADED' ? '2026-11-02T07:30:05.000Z' : null,
  'voidedReason': null,
  'retryAfterMs': status == 'GRADED' ? null : 1500,
  'tests': [
    {
      'position': 1,
      'visibility': 'SAMPLE',
      'status': 'PASSED',
      'timeMs': 5,
      'memoryKb': 30000,
      'inputArgs': [
        [2, 7, 11, 15],
        9,
      ],
      'expected': [0, 1],
      'actual': [0, 1],
      'console': '',
    },
    {
      'position': 2,
      'visibility': 'HIDDEN',
      'status': 'WRONG_ANSWER',
      'timeMs': 7,
      'memoryKb': 31000,
      if (hiddenLeak) 'expected': [4, 5],
    },
  ],
};

Map<String, Object?> draftJson(String language, {int version = 0}) => {
  'languageKey': language,
  'sourceCode': 'function twoSum(nums, target) {\n}\n',
  'version': version,
  'updatedAt': version == 0 ? null : '2026-11-02T07:00:00.000Z',
};

/// Server giả: trả DTO theo path, ghi lại request để kiểm tra body/header.
class FakeServer {
  final requests = <RequestOptions>[];
  int submitCalls = 0;
  bool failSubmitOnce = false;

  FutureOr<ResponseBody> handle(RequestOptions o) {
    requests.add(o);
    final path = o.path;
    if (path == 'me/assignments/$assignmentId/code') {
      return body(assignmentJson());
    }
    if (path == 'me/assignments/$assignmentId/code-submissions' &&
        o.method == 'GET') {
      return body({
        'items': [submissionJson()],
      });
    }
    if (path == 'me/assignments/$assignmentId/code-submissions' &&
        o.method == 'POST') {
      submitCalls++;
      if (failSubmitOnce && submitCalls == 1) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return body(submissionJson(status: 'QUEUED'), 202);
    }
    if (path.startsWith('me/assignments/$assignmentId/code-drafts/')) {
      final language = path.split('/').last;
      if (o.method == 'PUT') return body(draftJson(language, version: 1));
      return body(draftJson(language));
    }
    if (path == 'me/code-submissions/$submissionId') {
      return body(submissionJson());
    }
    if (path == 'me/assignments/$assignmentId/code-runs') {
      final custom = (o.data as Map<String, Object?>).containsKey('customArgs');
      return body({
        'compileStatus': 'OK',
        'compileOutput': '',
        'runtimeVersion': 'Node.js 22',
        'tests': [
          {
            'kind': custom ? 'CUSTOM' : 'SAMPLE',
            'position': custom ? null : 1,
            'display': custom
                ? 'nums = [3,2,4], target = 6'
                : 'nums = [2,7,11,15], target = 9',
            if (!custom) 'expected': [0, 1],
            'actual': custom ? [1, 2] : [0, 1],
            'status': custom ? 'COMPLETED' : 'PASSED',
            'console': '',
            'stderr': '',
            'timeMs': 4,
            'memoryKb': 30000,
          },
        ],
      });
    }
    if (path == 'mentor/class-sessions/$sessionId/assignments') {
      return body({
        'items': [
          {
            'id': assignmentId,
            'sessionId': sessionId,
            'purpose': 'HOMEWORK',
            'type': 'CODE',
            'title': 'Tổng hai số',
            'description': '',
            'maxScore': '10.00',
            'dueAt': '2026-11-04T08:00:00.000Z',
            'timeLimitMinutes': null,
            'maxAttempts': 10,
            'status': 'PUBLISHED',
            'revision': 3,
            'publishedAt': '2026-11-01T08:00:00.000Z',
          },
        ],
        'page': 1,
        'pageSize': 100,
        'total': 1,
      });
    }
    if (path == 'mentor/assignments/$assignmentId/code-summary') {
      return body({
        'assignmentId': assignmentId,
        'maxScore': '10.00',
        'maxAttempts': 10,
        'dueAt': '2026-11-04T08:00:00.000Z',
        'totals': {
          'students': 2,
          'submitted': 1,
          'notSubmitted': 1,
          'accepted': 0,
          'failed': 0,
          'averageBestScore': '4.00',
        },
        'items': [
          {
            'studentId': studentId,
            'displayName': 'Nguyễn Văn An',
            'enrollmentStatus': 'ACTIVE',
            'submissionCount': 1,
            'attemptsUsed': 1,
            'bestScore': '4.00',
            'bestSubmissionId': submissionId,
            'latestStatus': 'GRADED',
            'latestVerdict': 'PARTIAL',
            'latestSubmittedAt': '2026-11-02T07:30:00.000Z',
            'failedCount': 0,
          },
        ],
        'page': 1,
        'pageSize': 100,
        'total': 1,
      });
    }
    return body({
      'statusCode': 404,
      'code': 'NOT_FOUND',
      'message': 'not found',
    }, 404);
  }
}

List<Override> overridesFor(FakeServer server) => [
  sessionEpochProvider.overrideWithValue(0),
  codeAssignmentsApiProvider.overrideWithValue(api(server.handle)),
  learningTimeZoneProvider.overrideWith((ref) async => 'Asia/Ho_Chi_Minh'),
  appNowProvider.overrideWith(
    (ref) => Stream.value(DateTime.utc(2026, 11, 2, 8)),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => ['wifi'],
        );
  });

  group('Model', () {
    test('Đọc đề CODE đủ trường, chữ ký hiển thị gọn', () {
      final a = StudentCodeAssignment.fromJson(
        Json(assignmentJson(), codeError),
      );
      expect(a.languages.map((l) => l.key), [
        CodeLanguageKey.javascript,
        CodeLanguageKey.java21,
      ]);
      expect(
        a.problem.signature.display,
        'twoSum(nums: int[], target: int) → int[]',
      );
      expect(a.samples.single.display, 'nums = [2,7,11,15], target = 9');
      expect(formatCodeValue(a.samples.single.expected), '[0,1]');
    });

    test(
      'Test ẩn có expected/actual/input = response sai hợp đồng, không hiển thị',
      () {
        expect(
          () => Submission.fromJson(
            Json(submissionJson(hiddenLeak: true), codeError),
          ),
          throwsA(isA<ApiError>().having((e) => e.status, 'status', 502)),
        );
        final ok = Submission.fromJson(Json(submissionJson(), codeError));
        final hidden = ok.tests.firstWhere(
          (t) => t.visibility == TestVisibility.HIDDEN,
        );
        expect(hidden.hasDetail, isFalse);
        expect(hidden.input, isNull);
      },
    );

    test('Bài đã chấm phải có điểm; bài đang chờ không được có điểm', () {
      expect(
        () => Submission.fromJson(
          Json({...submissionJson(), 'score': null}, codeError),
        ),
        throwsA(isA<ApiError>()),
      );
      expect(
        () => Submission.fromJson(
          Json({
            ...submissionJson(status: 'QUEUED'),
            'score': '1.00',
          }, codeError),
        ),
        throwsA(isA<ApiError>()),
      );
      expect(
        Submission.fromJson(
          Json(submissionJson(status: 'RUNNING'), codeError),
        ).pending,
        isTrue,
      );
    });

    test('pollDelay kẹp 1–5 giây; timeLeft theo đồng hồ server', () {
      final s = Submission.fromJson(
        Json(submissionJson(status: 'QUEUED'), codeError),
      );
      expect(pollDelay(s), const Duration(milliseconds: 1500));
      final fast = Submission.fromJson(
        Json({
          ...submissionJson(status: 'QUEUED'),
          'retryAfterMs': 10,
        }, codeError),
      );
      expect(pollDelay(fast), const Duration(seconds: 1));
      final a = StudentCodeAssignment.fromJson(
        Json(assignmentJson(), codeError),
      );
      final received = DateTime.utc(2030); // giờ máy sai lệch không ảnh hưởng
      expect(
        timeLeft(a, received, received.add(const Duration(hours: 1))),
        const Duration(hours: 47),
      );
      expect(
        timeLeft(a, received, received.add(const Duration(days: 3))),
        Duration.zero,
      );
    });
  });

  group('Soạn code', () {
    test('Chèn cặp ngoặc đặt con trỏ ở giữa, thay vùng chọn', () {
      const value = TextEditingValue(
        text: 'ab',
        selection: TextSelection(baseOffset: 1, extentOffset: 2),
      );
      final next = insertCode(value, '{}', caret: 1);
      expect(next.text, 'a{}');
      expect(next.selection.baseOffset, 2);
    });

    test('Xuống dòng giữ thụt lề và thêm một mức sau dấu {', () {
      final formatter = CodeIndentFormatter();
      const before = TextEditingValue(
        text: '  if (x) {',
        selection: TextSelection.collapsed(offset: 10),
      );
      const typed = TextEditingValue(
        text: '  if (x) {\n',
        selection: TextSelection.collapsed(offset: 11),
      );
      final result = formatter.formatEditUpdate(before, typed);
      expect(result.text, '  if (x) {\n      ');
      expect(result.selection.baseOffset, result.text.length);
      // Dán nhiều ký tự: không can thiệp.
      const pasted = TextEditingValue(
        text: '  if (x) {\nabc',
        selection: TextSelection.collapsed(offset: 14),
      );
      expect(formatter.formatEditUpdate(before, pasted).text, pasted.text);
      expect(leadingWhitespace('', 0), '');
      expect(lineCount('a\nb\n'), 3);
      expect(longestLine('ab\nabcd'), 4);
    });
  });

  group('Input tự nhập', () {
    test('Chuỗi gõ thẳng, kiểu khác là JSON, kiểm tra kiểu như server', () {
      expect(parseCodeArg('string', 'hello world')?.value, 'hello world');
      expect(parseCodeArg('string', '"  a "')?.value, '  a ');
      expect(parseCodeArg('int', ' 42 ')?.value, 42);
      expect(parseCodeArg('int', '2147483648'), isNull);
      expect(parseCodeArg('int[]', '[1, 2, 3]')?.value, [1, 2, 3]);
      expect(parseCodeArg('int[]', '[1, "2"]'), isNull);
      expect(parseCodeArg('double', '1.5')?.value, 1.5);
      expect(parseCodeArg('double', ''), isNull);
      expect(parseCodeArg('boolean', 'true')?.value, true);
      expect(parseCodeArg('string[][]', '[["a"], []]')?.value, [
        ['a'],
        <Object?>[],
      ]);
      expect(matchesCodeType('long', 9007199254740992), isFalse);
      expect(codeTypeExample('int[][]'), '[[5]]');
    });
  });

  group('API', () {
    test(
      'Nộp bài gửi Idempotency-Key; lỗi mạng gửi lại đúng key + body',
      () async {
        final server = FakeServer()..failSubmitOnce = true;
        final container = ProviderContainer(
          overrides: overridesFor(server),
          retry: (_, _) => null,
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          codeCommandProvider(assignmentId),
          (_, _) {},
        );
        addTearDown(sub.close);
        final controller = container.read(
          codeCommandProvider(assignmentId).notifier,
        );
        expect(
          await controller.submit(CodeLanguageKey.javascript, 'code'),
          isNull,
        );
        expect(
          container.read(codeCommandProvider(assignmentId)).retryPending,
          isTrue,
        );
        // Đang chờ kiểm tra lại: không cho tạo lệnh nộp mới.
        expect(
          await controller.submit(CodeLanguageKey.javascript, 'code khác'),
          isNull,
        );
        expect(server.submitCalls, 1);
        final submitted = await controller.submit(
          CodeLanguageKey.javascript,
          'bỏ qua',
          retry: true,
        );
        expect(submitted?.status, SubmissionStatus.QUEUED);
        final posts = server.requests.where((r) => r.method == 'POST').toList();
        expect(posts, hasLength(2));
        expect(
          posts[0].headers['Idempotency-Key'],
          posts[1].headers['Idempotency-Key'],
        );
        expect(posts[1].data, {
          'languageKey': 'javascript',
          'sourceCode': 'code',
        });
      },
    );

    test(
      'Chạy thử gửi đúng body và timeout dài; id trả về sai bị từ chối',
      () async {
        RequestOptions? seen;
        final runApi = api((o) {
          seen = o;
          return body({
            'compileStatus': 'OK',
            'compileOutput': '',
            'runtimeVersion': 'Node.js 22',
            'tests': [],
          });
        });
        final result = await runApi.run(
          assignmentId,
          CodeLanguageKey.java21,
          'class Solution {}',
        );
        expect(result.compiled, isTrue);
        expect(seen!.data, {
          'languageKey': 'java21',
          'sourceCode': 'class Solution {}',
        });
        expect(seen!.receiveTimeout, CodeAssignmentsApi.runTimeout);
        final wrong = api((o) => body({...submissionJson(), 'id': studentId}));
        await expectLater(
          wrong.submission(submissionId),
          throwsA(isA<ApiError>()),
        );
      },
    );
  });

  group('Màn hình (input tự nhập)', () {
    testWidgets(
      'Editor: chạy với input tự nhập gửi customArgs đúng kiểu, báo lỗi ô sai',
      (tester) async {
        final server = FakeServer();
        await pumpScreen(
          tester,
          const CodeEditorScreen(assignmentId: assignmentId),
          overrides: overridesFor(server),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('code-editor-run-custom')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('code-custom-input-sheet')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('code-custom-arg-0')),
          '[3, 2, 4',
        );
        await tester.enterText(find.byKey(const Key('code-custom-arg-1')), '6');
        await tester.ensureVisible(find.byKey(const Key('code-custom-run')));
        await tester.tap(find.byKey(const Key('code-custom-run')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Cần Mảng số nguyên'), findsOneWidget);
        expect(
          server.requests.where((r) => r.path.endsWith('code-runs')),
          isEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('code-custom-arg-0')),
          '[3, 2, 4]',
        );
        await tester.ensureVisible(find.byKey(const Key('code-custom-run')));
        await tester.tap(find.byKey(const Key('code-custom-run')));
        await tester.pumpAndSettle();
        final run = server.requests.singleWhere(
          (r) => r.path.endsWith('code-runs'),
        );
        expect((run.data as Map<String, Object?>)['customArgs'], [
          [3, 2, 4],
          6,
        ]);
        expect(find.byKey(const Key('code-run-result')), findsOneWidget);
        expect(find.text('Input tự nhập'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('Màn hình', () {
    testWidgets('Đề bài 320×640 chữ 1.3: ví dụ, test ẩn chỉ đếm, lịch sử', (
      tester,
    ) async {
      final server = FakeServer();
      await pumpScreen(
        tester,
        const CodeProblemScreen(assignmentId: assignmentId),
        overrides: overridesFor(server),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tổng hai số'), findsWidgets);
      expect(
        find.textContaining('twoSum(nums: int[], target: int)'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Lịch sử nộp bài'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('3 test ẩn'), findsOneWidget);
      expect(
        find.byKey(const Key('code-history-$submissionId')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Editor: đổi ngôn ngữ, phím phụ, autosave nháp', (
      tester,
    ) async {
      final server = FakeServer();
      await pumpScreen(
        tester,
        const CodeEditorScreen(assignmentId: assignmentId),
        overrides: overridesFor(server),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('code-editor-field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('code-editor-field')));
      await tester.pump();
      await tester.tap(find.text('{ }'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final puts = server.requests.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(1));
      expect((puts.single.data as Map<String, Object?>)['expectedVersion'], 0);
      expect(find.text('Đã lưu nháp'), findsOneWidget);
      // Ẩn bàn phím để thấy nút, rồi đổi sang Java.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('code-language-java21')));
      await tester.pumpAndSettle();
      expect(
        server.requests.any((r) => r.path.endsWith('code-drafts/java21')),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Mentor: tổng hợp bài code của buổi (chỉ đọc), en', (
      tester,
    ) async {
      final server = FakeServer();
      await pumpScreen(
        tester,
        const MentorSessionCodeScreen(sessionId: sessionId),
        language: 'en',
        overrides: overridesFor(server),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tổng hai số'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('4.00 / 10.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
