import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/config/env.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/features/account/account_screen.dart';
import 'package:mindy_flutter/features/auth/login_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_home_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_pages.dart';
import 'package:mindy_flutter/features/mentor/mentor_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';

const userJson = <String, Object?>{
  'id': '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f',
  'email': 'mentor@example.test',
  'displayName': 'Trần Thị Linh',
  'phone': null,
  'role': 'MENTOR',
  'status': 'ACTIVE',
  'createdAt': '2026-01-01T00:00:00Z',
};

SessionUser user(Role role) => SessionUser(
  id: userJson['id']! as String,
  email: userJson['email']! as String,
  displayName: userJson['displayName']! as String,
  phone: null,
  role: role,
  createdAt: DateTime.utc(2026),
);

class FixedSession extends SessionController {
  FixedSession(this.role);
  final Role role;
  @override
  SessionState build() => SessionState(ready: true, user: user(role), epoch: 1);
}

class EmptyFavorites extends MentorFavoritesController {
  @override
  Future<List<MentorUtil>> build() async => const [];
}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody expired() => jsonBody({'statusCode': 401, 'code': 'AUTHENTICATION_REQUIRED', 'message': 'Expired'}, 401);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    for (final entry in <String, List<String>>{
      'Nunito': ['Nunito-Regular.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf'],
      'BeVietnamPro': [
        'BeVietnamPro-Regular.ttf',
        'BeVietnamPro-Medium.ttf',
        'BeVietnamPro-SemiBold.ttf',
        'BeVietnamPro-Bold.ttf',
      ],
      'MaterialSymbolsRounded': ['MaterialSymbolsRounded.ttf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
  });

  test('review: bootstrap completes after successful access-token refresh', () async {
    final client = ApiClient(cookieJar: CookieJar());
    var reads = 0;
    client.dio.httpClientAdapter = Adapter((o) {
      if (o.path == 'auth/refresh') return jsonBody({});
      if (o.path == 'auth/me') return ++reads == 1 ? expired() : jsonBody(userJson);
      throw StateError('Unexpected request: ${o.path}');
    });
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (container.read(sessionProvider).ready) break;
    }
    expect(reads, 2, reason: 'auth/me was retried successfully');
    expect(
      container.read(sessionProvider).ready,
      isTrue,
      reason: 'A successful refresh must not leave the app on splash',
    );
    expect(container.read(sessionProvider).user?.role, Role.MENTOR);
  });

  test('review: a request from an old session is not replayed using new cookies', () async {
    final jar = CookieJar();
    final client = ApiClient(cookieJar: jar);
    final firstSeen = Completer<void>();
    final release = Completer<ResponseBody>();
    final cookies = <String>[];
    client.dio.httpClientAdapter = Adapter((o) {
      cookies.add('${o.headers[HttpHeaders.cookieHeader]}');
      if (cookies.length == 1) {
        firstSeen.complete();
        return release.future;
      }
      return jsonBody({'owner': 'new-user'});
    });
    await jar.saveFromResponse(Uri.parse(Env.apiUrl), [Cookie('access_token', 'old-user')]);
    final pending = client.post('me/cart/items', body: {'classId': 'old-user-choice'});
    await firstSeen.future;
    client.sessionEpoch++;
    await jar.deleteAll();
    await jar.saveFromResponse(Uri.parse(Env.apiUrl), [Cookie('access_token', 'new-user')]);
    release.complete(expired());
    await expectLater(pending, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    expect(cookies, hasLength(1), reason: 'Old mutation was replayed across sessions: $cookies');
  });

  test('Response thành công của phiên cũ không được lưu cookie hay trả dữ liệu', () async {
    final jar = CookieJar();
    final client = ApiClient(cookieJar: jar);
    final seen = Completer<void>();
    final release = Completer<ResponseBody>();
    client.dio.httpClientAdapter = Adapter((o) {
      seen.complete();
      return release.future;
    });
    final pending = client.get('auth/me');
    await seen.future;
    client.sessionEpoch++;
    await jar.saveFromResponse(Uri.parse(Env.apiUrl), [Cookie('access_token', 'new-user')]);
    release.complete(
      ResponseBody.fromString(
        jsonEncode(userJson),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          HttpHeaders.setCookieHeader: ['access_token=stale-user; Path=/'],
        },
      ),
    );
    await expectLater(pending, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    expect((await jar.loadForRequest(Uri.parse(Env.apiUrl))).single.value, 'new-user');
  });

  test('Request chưa tới interceptor cũng giữ phiên tại thời điểm tạo lệnh', () async {
    final client = ApiClient(cookieJar: CookieJar());
    var sends = 0;
    client.dio.httpClientAdapter = Adapter((o) {
      sends++;
      return jsonBody({'ok': true});
    });
    final pending = client.post('me/cart/items', body: {'classId': 'old-choice'});
    client.sessionEpoch++;
    await expectLater(pending, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    expect(sends, 0);
  });

  test('Nhiều request 401 dùng chung một refresh và mỗi request chỉ gửi lại một lần', () async {
    final client = ApiClient(cookieJar: CookieJar());
    final refreshSeen = Completer<void>();
    final refreshDone = Completer<ResponseBody>();
    var refreshes = 0;
    final attempts = <String, int>{};
    client.dio.httpClientAdapter = Adapter((o) {
      if (o.path == 'auth/refresh') {
        refreshes++;
        refreshSeen.complete();
        return refreshDone.future;
      }
      final count = attempts.update(o.path, (value) => value + 1, ifAbsent: () => 1);
      return count == 1 ? expired() : jsonBody({'ok': true});
    });
    final first = client.get('me/cart');
    final second = client.get('mentor/schedule');
    await refreshSeen.future;
    refreshDone.complete(jsonBody({}));
    await Future.wait([first, second]);
    expect(refreshes, 1);
    expect(attempts.values, everyElement(2));
    expect(client.sessionEpoch, 0);
    expect(client.refreshGeneration, 1);
  });

  test('Refresh về muộn không xoá cookie hay hết hạn phiên mới', () async {
    final jar = CookieJar();
    final client = ApiClient(cookieJar: jar);
    final refreshSeen = Completer<void>();
    final refreshDone = Completer<ResponseBody>();
    var expirations = 0;
    client.onSessionExpired = () => expirations++;
    client.dio.httpClientAdapter = Adapter((o) {
      if (o.path == 'auth/refresh') {
        refreshSeen.complete();
        return refreshDone.future;
      }
      return expired();
    });
    final pending = client.get('me/cart');
    await refreshSeen.future;
    client.sessionEpoch++;
    await jar.saveFromResponse(Uri.parse(Env.apiUrl), [Cookie('access_token', 'new-user')]);
    refreshDone.complete(expired());
    await expectLater(pending, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    expect(expirations, 0);
    expect((await jar.loadForRequest(Uri.parse(Env.apiUrl))).single.value, 'new-user');
  });

  test('review: substitute-only mentor is detected using current backend contract', () async {
    final client = ApiClient(cookieJar: CookieJar());
    client.dio.httpClientAdapter = Adapter(
      (o) => jsonBody({
        'items': o.queryParameters['assignment'] == 'PRIMARY'
            ? []
            : [
                {'assignmentType': 'SUBSTITUTE'},
              ],
        'total': o.queryParameters['assignment'] == 'PRIMARY' ? 0 : 1,
        'page': 1,
        'pageSize': 1,
      }),
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        sessionProvider.overrideWith(() => FixedSession(Role.MENTOR)),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(mentorSubstituteOnlyProvider.future), isTrue);
  });

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'mentor-home': const MentorHomeScreen(),
    'mentor-utilities': const MentorUtilitiesScreen(),
    'student-account': const AccountScreen(),
  };

  for (final entry in screens.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('review: ${entry.key} renders at 320x640, text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith(
                () => FixedSession(entry.key == 'student-account' ? Role.STUDENT : Role.MENTOR),
              ),
              mentorSubstituteOnlyProvider.overrideWith((ref) async => false),
              mentorFavoritesProvider.overrideWith(EmptyFavorites.new),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
