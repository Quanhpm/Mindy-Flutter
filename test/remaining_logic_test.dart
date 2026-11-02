import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/idempotency.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/ui/page_numbers.dart';
import 'package:mindy_flutter/core/utils/concurrent.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/cart/cart_api.dart';
import 'package:mindy_flutter/features/cart/cart_controller.dart';
import 'package:mindy_flutter/features/cart/cart_models.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_api.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_models.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_providers.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';
import '../tool/preview/operations_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';
import 'p0_regression_test.dart' show Adapter, jsonBody;

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
  void change() => state = SessionState(ready: true, epoch: state.epoch + 1);
}

class _Operations extends MentorOperationsApi {
  _Operations() : super(ApiClient(cookieJar: CookieJar()));
  final calls = <IdempotentCall>[];
  bool unknown = false, conflict = false;
  Completer<TeachingNote>? delayed;
  int meetingCalls = 0;
  @override
  Future<TeachingNote> saveNote(String id, IdempotentCall call) async {
    calls.add(call);
    if (unknown) {
      unknown = false;
      throw ApiError.network();
    }
    if (conflict) {
      conflict = false;
      throw ApiError(status: 409, code: 'TEACHING_VERSION_CONFLICT');
    }
    if (delayed != null) return delayed!.future;
    return TeachingNote(id, 2, call.body['content']! as String, call.body['nextSteps']! as String);
  }

  @override
  Future<MeetingUpdate> meeting(String id, {required int version, required String? url}) async {
    meetingCalls++;
    if (unknown) throw ApiError.network();
    return MeetingUpdate(id, version + 1, url, url);
  }
}

class _Cart extends CartApi {
  _Cart() : super(ApiClient(cookieJar: CookieJar()));
  Completer<Cart>? delayed;
  int checkouts = 0;
  static const cart = Cart(
    totalAmount: 100,
    items: [
      CartItem(
        classId: operationSessionId,
        classCode: 'TEST',
        className: 'Test',
        courseId: operationRequestId,
        courseTitle: 'Synthetic',
        deliveryMode: DeliveryMode.ONLINE,
        startDate: '2026-11-12',
        endDate: '2026-12-12',
        priceSnapshot: 100,
        currentPriceAmount: 100,
        isPurchasable: true,
      ),
    ],
  );
  @override
  Future<Cart> get() async => delayed == null ? cart : delayed!.future;
  @override
  Future<Order> checkout() async {
    checkouts++;
    throw ApiError.network();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  ProviderContainer scope(_Operations api) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWith(_Session.new), mentorOperationsApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('Unknown note: đóng màn rồi mở lại vẫn retry đúng key/body, chặn ghi mới', () async {
    final api = _Operations()..unknown = true;
    final container = scope(api), provider = mentorNoteSaveProvider(operationSessionId);
    final sub = container.listen(provider, (_, _) {});
    final ctrl = container.read(provider.notifier);
    expect(await ctrl.save(1, 'Bản nháp', 'Tiếp theo'), isNull);
    sub.close();
    await container.pump();
    expect(container.read(provider).retryPending, isTrue);
    expect(await container.read(provider.notifier).save(1, 'Khác', ''), isNull);
    expect(api.calls.length, 1);
    expect(await container.read(provider.notifier).retry(), isNotNull);
    expect(api.calls[0].key, api.calls[1].key);
    expect(api.calls[0].body, api.calls[1].body);
  });
  test('409 note: giữ nháp, chỉ lệnh mới sau review, key mới và version mới', () async {
    final api = _Operations()..conflict = true;
    final container = scope(api), p = mentorNoteSaveProvider(operationSessionId);
    final sub = container.listen(p, (_, _) {});
    addTearDown(sub.close);
    final ctrl = container.read(p.notifier);
    await ctrl.save(1, 'Dữ liệu', '');
    expect(container.read(p).conflict, isTrue);
    await ctrl.save(2, 'Dữ liệu', '');
    expect(api.calls.length, 1);
    ctrl.reviewed();
    await ctrl.save(2, 'Dữ liệu', '');
    expect(api.calls.last.body['expectedVersion'], 2);
    expect(api.calls.last.key, isNot(api.calls.first.key));
  });
  test('Mutation cũ về sau khi đổi actor không ghi vào provider mới', () async {
    final api = _Operations()..delayed = Completer<TeachingNote>();
    final c = scope(api), p = mentorNoteSaveProvider(operationSessionId);
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    final pending = c.read(p.notifier).save(1, 'Riêng tư', '');
    (c.read(sessionProvider.notifier) as _Session).change();
    await c.pump();
    expect(c.read(p).busy, isFalse);
    api.delayed!.complete(const TeachingNote(operationSessionId, 2, 'Riêng tư', ''));
    expect(await pending, isNull);
    expect(c.read(p).result, isNull);
  });
  test('PATCH meeting unknown không replay, phải đọc và review trước lệnh mới', () async {
    final api = _Operations()..unknown = true, c = scope(api);
    final p = mentorMeetingSaveProvider(operationSessionId),
        sub = c.listen(mentorMeetingSaveProvider(operationSessionId), (_, _) {});
    addTearDown(sub.close);
    final ctrl = c.read(p.notifier);
    await ctrl.save(2, 'https://example.test/new');
    await ctrl.save(2, 'https://example.test/new');
    expect(api.meetingCalls, 1);
    expect(c.read(p).retryPending, isTrue);
    ctrl.reviewed();
    api.unknown = false;
    expect(await ctrl.save(3, null), isNotNull);
    expect(api.meetingCalls, 2);
  });
  test('Meeting API chấp nhận no-op cùng version, chặn URL sai/snapshot nhảy', () async {
    final client = ApiClient(cookieJar: CookieJar());
    var version = 2;
    client.dio.httpClientAdapter = Adapter(
      (_) => jsonBody({
        'sessionId': operationSessionId,
        'classId': operationRequestId,
        'version': version,
        'meetingUrl': null,
        'effectiveMeetingUrl': 'https://example.test/class',
      }),
    );
    final api = MentorOperationsApi(client);
    expect((await api.meeting(operationSessionId, version: 2, url: null)).version, 2);
    version = 4;
    await expectLater(api.meeting(operationSessionId, version: 2, url: null), throwsA(isA<ApiError>()));
  });
  test('Leave detail đọc đủ trang và từ chối snapshot đổi version', () async {
    final client = ApiClient(cookieJar: CookieJar());
    var changed = false;
    client.dio.httpClientAdapter = Adapter((r) {
      final page = r.queryParameters['page']! as int;
      return jsonBody({
        'id': operationRequestId,
        'mentorId': operationSessionId,
        'fromDate': '2026-11-12',
        'toDate': '2026-11-12',
        'period': 'FULL_DAY',
        'status': 'PENDING',
        'reason': 'Synthetic',
        'version': changed && page == 2 ? 2 : 1,
        'submittedAt': '2026-11-02T07:00:00Z',
        'expiresAt': '2026-11-10T17:00:00Z',
        'asOf': '2026-11-02T07:00:00Z',
        'timeZone': previewZone,
        'itemCount': 2,
        'page': page,
        'pageSize': 1,
        'classExtensions': [],
        'studentConflictCount': null,
        'review': null,
        'items': [
          {
            'sourceSessionId': '00000000-0000-4000-8000-${page.toString().padLeft(12, '0')}',
            'classId': operationRequestId,
            'sourceVersion': 1,
            'sourceStartsAt': '2026-11-12T07:00:00Z',
            'sourceEndsAt': '2026-11-12T08:30:00Z',
            'startsAt': '2026-11-15T07:00:00Z',
            'endsAt': '2026-11-15T08:30:00Z',
            'replacementSessionId': null,
          },
        ],
      });
    });
    final api = MentorOperationsApi(client);
    expect((await api.detail(operationRequestId)).items.length, 2);
    changed = true;
    await expectLater(api.detail(operationRequestId), throwsA(isA<ApiError>().having((e) => e.status, 'status', 409)));
  });
  test('FULL_DAY serialize sessionMappings với giờ offset được chuẩn hóa UTC', () {
    final preview = LeavePreview(
      sessions: [sampleSchedule().entries.first.session],
      versions: [const SourceVersion(operationSessionId, 1)],
      eligible: true,
      deadline: previewNow,
      asOf: previewNow,
      zone: previewZone,
    );
    final body = LeaveDraft(
      query: (fromDate: '2026-11-12', toDate: '2026-11-12', period: LeavePeriod.FULL_DAY),
      reason: '  Lý do  ',
      preview: preview,
      mappings: [
        LeaveMapping(
          sessionId: operationSessionId,
          targetDate: '2026-11-15',
          period: LeavePeriod.MORNING,
          slot: LeaveSlot(DateTime.parse('2026-11-15T08:00:00+07:00'), DateTime.parse('2026-11-15T09:00:00+07:00')),
        ),
      ],
    ).toJson();
    expect(body['reason'], 'Lý do');
    expect(body.containsKey('dayMappings'), isFalse);
    expect((body['sessionMappings']! as List).first['startsAt'], '2026-11-15T01:00:00.000Z');
  });
  test('Note response phiên bản không khớp và khoảng slot âm báo schema lỗi', () {
    expect(
      () => TeachingNote.fromJson(
        Json({
          'sessionId': operationSessionId,
          'version': 2,
          'note': {'version': 1, 'content': '', 'nextSteps': ''},
        }),
      ),
      throwsA(isA<ApiError>()),
    );
    expect(
      () => LeaveSlot.fromJson(Json({'startsAt': '2026-11-15T09:00:00Z', 'endsAt': '2026-11-15T08:00:00Z'})),
      throwsA(isA<ApiError>()),
    );
  });
  test('Gate không vượt 6 task; task lỗi trả lượt cho hàng đợi', () async {
    final gate = AsyncGate(6);
    var active = 0, max = 0;
    final futures = List.generate(
      19,
      (i) => gate
          .run(() async {
            active++;
            if (active > max) max = active;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            active--;
            if (i == 2) throw StateError('synthetic');
            return i;
          })
          .then((_) => true, onError: (_) => false),
    );
    final results = await Future.wait(futures);
    expect(max, 6);
    expect(results.where((r) => !r).length, 1);
  });
  test('Số trang có dấu lược và trạng thái buổi đã qua không còn live', () {
    expect(pageNumbers(6, 12), [1, null, 5, 6, 7, null, 12]);
    final start = DateTime.utc(2026, 11, 2, 7), end = DateTime.utc(2026, 11, 2, 8);
    expect(sessionDisplayStatus(SessionStatus.IN_PROGRESS, start, end, end), SessionDisplay.ended);
    expect(sessionDisplayStatus(SessionStatus.CANCELLED, start, end, start), SessionDisplay.cancelled);
  });
  test('Cart refresh trả muộn sau đổi phiên không ghi đè giỏ của actor mới', () async {
    final api = _Cart(),
        c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [sessionProvider.overrideWith(_Session.new), cartApiProvider.overrideWithValue(api)],
        );
    addTearDown(c.dispose);
    await c.read(cartProvider.future);
    api.delayed = Completer<Cart>();
    final pending = c.read(cartProvider.notifier).refresh();
    final assertion = expectLater(pending, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
    (c.read(sessionProvider.notifier) as _Session).change();
    await c.pump();
    api.delayed!.complete(Cart.empty);
    await assertion;
  });
  test('Cart unknown ở RAM: lần checkout kế tiếp không gửi POST và đổi phiên reset', () async {
    final api = _Cart(),
        c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [sessionProvider.overrideWith(_Session.new), cartApiProvider.overrideWithValue(api)],
        );
    addTearDown(c.dispose);
    await c.read(cartProvider.future);
    final ctrl = c.read(cartProvider.notifier);
    await expectLater(ctrl.checkout(), throwsA(isA<CheckoutUnknown>()));
    await c.pump();
    await expectLater(ctrl.checkout(), throwsA(isA<CheckoutUnknown>()));
    expect(api.checkouts, 1);
    expect(c.read(checkoutPendingProvider), [operationSessionId]);
    (c.read(sessionProvider.notifier) as _Session).change();
    await c.pump();
    expect(c.read(checkoutPendingProvider), isNull);
  });
  test('Tất cả enum MF7/S4 có key Việt và Anh', () {
    for (final language in ['vi', 'en']) {
      final d = jsonDecode(File('assets/i18n/$language.json').readAsStringSync()) as Map<String, dynamic>;
      for (final value in LeaveStatus.values) {
        expect(d['mentor']['leave']['status'][value.name], isA<String>());
      }
      for (final value in SessionDisplay.values) {
        expect(d['learning']['display'][value.name], isA<String>());
      }
    }
  });
}
