import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/network/pagination.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_api.dart';
import 'package:mindy_flutter/features/notifications/notifications_api.dart';
import 'package:mindy_flutter/features/notifications/notifications_providers.dart';

import 'mentor_mf2_test.dart' show sessionJson;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async =>
      respond(options);
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
ApiClient client(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    ApiClient(cookieJar: CookieJar())..dio.httpClientAdapter = _Adapter(handler);

Map<String, Object?> notificationJson({String? readAt}) => {
  'id': '00000000-0000-4000-8000-000000000200',
  'actorId': '00000000-0000-4000-8000-000000000002',
  'conversationId': '00000000-0000-4000-8000-000000000300',
  'messageId': '00000000-0000-4000-8000-000000000400',
  'type': 'CHAT_MESSAGE',
  'title': 'Thông báo mẫu',
  'body': 'Nội dung mẫu',
  'readAt': readAt,
  'createdAt': '2026-11-02T07:00:00Z',
  'data': {
    'conversationId': '00000000-0000-4000-8000-000000000300',
    'messageId': '00000000-0000-4000-8000-000000000400',
  },
};

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
  void change() => state = SessionState(ready: true, epoch: state.epoch + 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
  });

  test('Phân trang phải đọc hết, giữ total/pageSize và không ghép ID trùng', () async {
    var calls = 0;
    Future<Paged<String>> page(int number) async {
      calls++;
      return Paged(items: number == 1 ? ['a', 'b'] : ['c'], page: number, pageSize: 2, total: 3);
    }

    expect(await readAllPages(page, idOf: (id) => id, errorCode: 'INVALID_TEST'), ['a', 'b', 'c']);
    expect(calls, 2);
    for (final malformed in [
      Paged(items: ['a'], page: 2, pageSize: 2, total: 3),
      Paged(items: ['c'], page: 2, pageSize: 2, total: 4),
      Paged<String>(items: [], page: 2, pageSize: 2, total: 3),
    ]) {
      await expectLater(
        readAllPages(
          (number) async => number == 1 ? Paged(items: ['a', 'b'], page: 1, pageSize: 2, total: 3) : malformed,
          idOf: (id) => id,
          errorCode: 'INVALID_TEST',
        ),
        throwsA(isA<ApiError>()),
      );
    }
  });

  test('Lỗi trang sau không biến thành danh sách rỗng hay dữ liệu thiếu', () async {
    await expectLater(
      readAllPages<String>(
        (number) async {
          if (number == 2) throw ApiError.network();
          return Paged(items: ['a'], page: 1, pageSize: 1, total: 2);
        },
        idOf: (id) => id,
        errorCode: 'INVALID_TEST',
      ),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
    );
  });

  test('Schedule range kiểm tra response range và timezone; giữ query timestamp UTC', () async {
    final from = DateTime.utc(2026, 11, 2), to = DateTime.utc(2026, 11, 3);
    final api = MentorScheduleApi(
      client((request) {
        expect(request.queryParameters['from'], from.toIso8601String());
        return body({
          'items': [sessionJson()],
          'page': 1,
          'pageSize': 100,
          'total': 1,
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
          'timeZone': 'Asia/Ho_Chi_Minh',
          'asOf': from.toIso8601String(),
        });
      }),
    );
    expect((await api.range(from, to)).sessions, hasLength(1));
    final invalid = MentorScheduleApi(
      client(
        (request) => body({
          'items': [sessionJson()],
          'page': 1,
          'pageSize': 100,
          'total': 1,
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
          'timeZone': 'America/New_York',
          'asOf': from.toIso8601String(),
        }),
      ),
    );
    await expectLater(invalid.range(from, to), throwsA(isA<ApiError>()));
  });

  test('Notification API dùng cursor và response data, mutation cần Origin', () async {
    final api = NotificationsApi(
      client((request) {
        if (request.path == 'notifications' && request.method == 'GET') {
          expect(request.queryParameters['cursor'], 'opaque-token');
          expect(request.queryParameters.containsKey('page'), isFalse);
          return body({
            'data': [notificationJson()],
            'meta': {'hasMore': false, 'nextCursor': null},
          });
        }
        expect(request.method, 'PATCH');
        expect(request.headers['Origin'], isNotEmpty);
        return body(notificationJson(readAt: '2026-11-02T07:01:00Z'));
      }),
    );
    final page = await api.page(cursor: 'opaque-token');
    expect(page.items.single.readAt, isNull);
    expect((await api.read(page.items.single.id)).readAt, isNotNull);
  });

  test('Tắt chat chỉ fallback cho 404/503; response sai hoặc lỗi 403 không bị nuốt', () async {
    for (final status in [404, 503, 403, 502]) {
      final api = NotificationsApi(
        client((_) => body({'statusCode': status, 'code': 'TEST', 'message': 'Test'}, status)),
      );
      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(_Session.new), notificationsApiProvider.overrideWithValue(api)],
        retry: (_, _) => null,
      );
      final subscription = container.listen(notificationFeedProvider, (_, _) {});
      if ([404, 503].contains(status)) {
        expect((await container.read(notificationFeedProvider.future)).disabled, isTrue);
      } else {
        await expectLater(container.read(notificationFeedProvider.future), throwsA(isA<ApiError>()));
      }
      subscription.close();
      container.dispose();
    }
  });

  test('Đánh dấu thông báo đợi server; lỗi giữ nguyên chưa đọc; không tự retry mutation', () async {
    final release = Completer<ResponseBody>();
    final seen = Completer<void>();
    var writes = 0;
    final api = NotificationsApi(
      client((request) {
        if (request.method == 'GET') {
          return body({
            'data': [notificationJson()],
            'meta': {'hasMore': false, 'nextCursor': null},
          });
        }
        writes++;
        seen.complete();
        return release.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith(_Session.new), notificationsApiProvider.overrideWithValue(api)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final subscription = container.listen(notificationFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    final feed = await container.read(notificationFeedProvider.future);
    final pending = container.read(notificationFeedProvider.notifier).read(feed.page.items.single);
    await seen.future;
    expect(container.read(notificationFeedProvider).value!.page.items.single.readAt, isNull);
    release.complete(body({'statusCode': 503, 'code': 'TEST', 'message': 'Test'}, 503));
    await expectLater(pending, throwsA(isA<ApiError>()));
    expect(writes, 1);
    expect(container.read(notificationFeedProvider).value!.page.items.single.readAt, isNull);
  });

  test('Response đánh dấu đọc của phiên cũ không thay feed của phiên mới', () async {
    final release = Completer<ResponseBody>();
    final seen = Completer<void>();
    var reads = 0;
    final api = NotificationsApi(
      client((request) {
        if (request.method == 'GET') {
          reads++;
          return body({
            'data': [notificationJson()],
            'meta': {'hasMore': false, 'nextCursor': null},
          });
        }
        seen.complete();
        return release.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith(_Session.new), notificationsApiProvider.overrideWithValue(api)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final subscription = container.listen(notificationFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    final feed = await container.read(notificationFeedProvider.future);
    final pending = container.read(notificationFeedProvider.notifier).read(feed.page.items.single);
    await seen.future;
    (container.read(sessionProvider.notifier) as _Session).change();
    await container.read(notificationFeedProvider.future);
    release.complete(body(notificationJson(readAt: '2026-11-02T07:01:00Z')));
    await pending;
    expect(reads, 2);
    expect(container.read(notificationFeedProvider).value!.page.items.single.readAt, isNull);
  });
}
