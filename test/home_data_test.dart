import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/features/courses/courses_api.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/home/home_providers.dart';

import 'p0_regression_test.dart' show Adapter, jsonBody;

const _courseId = '00000000-0000-4000-8000-000000000001';
const _course = Course(
  id: _courseId,
  code: 'SYNTHETIC',
  title: 'Synthetic course',
  description: null,
  imgUrl: null,
  priceAmount: 1,
  categoryId: '00000000-0000-4000-8000-000000000002',
  categoryName: 'Synthetic',
);

class _HomeApi extends CoursesApi {
  _HomeApi({required this.page}) : super(ApiClient(cookieJar: CookieJar()));
  final int page;
  var metadataCalls = 0;
  @override
  Future<Paged<Course>> courses({
    required int page,
    required int pageSize,
    String? categoryId,
    DeliveryMode? deliveryMode,
    CancelToken? cancel,
  }) async => Paged(items: [_course], page: this.page, pageSize: 4, total: 1);
  @override
  Future<OpenClass?> nextClass(String id, {CancelToken? cancel}) async {
    metadataCalls++;
    throw ApiError.network();
  }
}

Map<String, Object?> _class(int index, String date) => {
  'id': '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  'courseId': _courseId,
  'code': 'CLASS-$index',
  'name': 'Synthetic class',
  'startDate': date,
  'endDate': date,
  'deliveryMode': 'ONLINE',
  'availableSeats': 1,
  'mentor': {'displayName': 'Synthetic mentor'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
  });
  test('Lớp khai giảng sớm nhất có thể ở trang sau', () async {
    final client = ApiClient(cookieJar: CookieJar());
    final pages = <int>[];
    client.dio.httpClientAdapter = Adapter((request) {
      final page = request.queryParameters['page']! as int;
      pages.add(page);
      return jsonBody({
        'items': [_class(page, page == 1 ? '2026-12-15' : '2026-11-10')],
        'page': page,
        'pageSize': 1,
        'total': 2,
      });
    });
    final next = await CoursesApi(client).nextClass(_courseId);
    expect(next!.startDate, '2026-11-10');
    expect(pages, [1, 2]);
  });
  test('Không dùng lớp khi metadata trang sai hoặc lặp ID', () async {
    for (final duplicate in [false, true]) {
      final client = ApiClient(cookieJar: CookieJar());
      client.dio.httpClientAdapter = Adapter((request) {
        final page = request.queryParameters['page']! as int;
        return jsonBody({
          'items': [_class(1, '2026-11-10')],
          'page': duplicate ? page : page + 1,
          'pageSize': 1,
          'total': 2,
        });
      });
      await expectLater(CoursesApi(client).nextClass(_courseId), throwsA(isA<ApiError>()));
    }
  });
  test('Không dùng lớp của một khoá khác trong response', () async {
    final client = ApiClient(cookieJar: CookieJar());
    client.dio.httpClientAdapter = Adapter(
      (_) => jsonBody({
        'items': [
          {..._class(1, '2026-11-10'), 'courseId': '00000000-0000-4000-8000-000000000999'},
        ],
        'page': 1,
        'pageSize': 100,
        'total': 1,
      }),
    );
    await expectLater(CoursesApi(client).nextClass(_courseId), throwsA(isA<ApiError>()));
  });
  test('Home giữ thẻ khoá khi metadata lớp lỗi, không làm lỗi cả vùng', () async {
    final api = _HomeApi(page: 1);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [sessionEpochProvider.overrideWithValue(1), coursesApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(homeCoursesProvider.future, (_, _) {});
    final list = await subscription.read();
    expect(list.single.id, _courseId);
    expect(list.single.openClass, isNull);
    expect(api.metadataCalls, 1);
    subscription.close();
  });
  test('Home từ chối metadata sai trang trước khi đọc lớp', () async {
    final api = _HomeApi(page: 2);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [sessionEpochProvider.overrideWithValue(1), coursesApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(homeCoursesProvider.future, (_, _) {});
    await expectLater(subscription.read(), throwsA(isA<ApiError>()));
    expect(api.metadataCalls, 0);
    subscription.close();
  });
}
