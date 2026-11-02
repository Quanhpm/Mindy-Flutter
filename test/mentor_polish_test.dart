import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mindy_flutter/app/router.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/ui/states.dart';
import 'package:mindy_flutter/core/ui/button.dart';
import 'package:mindy_flutter/core/ui/staff/staff_widgets.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/mentor_actions.dart';
import 'package:mindy_flutter/features/mentor/mentor_home_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_pages.dart';
import 'package:mindy_flutter/features/mentor/mentor_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';

import 'mentor_mf2_test.dart' show pumpScreen;
import 'p0_regression_test.dart' show Adapter, jsonBody, FixedSession;

class _SwitchSession extends FixedSession {
  _SwitchSession() : super(Role.MENTOR);
  void switchAccount() {
    state = SessionState(
      ready: true,
      epoch: 2,
      user: SessionUser(
        id: '00000000-0000-4000-8000-000000000999',
        email: 'next@example.test',
        displayName: 'Next mentor',
        phone: null,
        role: Role.MENTOR,
        createdAt: DateTime.utc(2026),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    initTimeZones();
    for (final entry in {
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

  test('Quyền lớp chỉ hiện khi snapshot đã đọc thành công, cả khi refresh', () {
    expect(canShowPrimaryUtilities(const AsyncData(false)), isTrue);
    expect(canShowPrimaryUtilities(const AsyncData(true)), isFalse);
    expect(canShowPrimaryUtilities(const AsyncLoading()), isFalse);
  });

  test('Lỗi đọc assignment không được suy ra quyền mentor chính', () async {
    final client = ApiClient(cookieJar: CookieJar());
    client.dio.httpClientAdapter = Adapter((_) => jsonBody({'code': 'SERVICE_UNAVAILABLE'}, 503));
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [apiClientProvider.overrideWithValue(client), sessionEpochProvider.overrideWithValue(1)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(mentorSubstituteOnlyProvider.future, (_, _) {});
    addTearDown(subscription.close);
    await expectLater(subscription.read(), throwsA(isA<ApiError>().having((e) => e.status, 'status', 503)));
  });

  test('Lưu yêu thích đang chờ không ghi vào tài khoản vừa đăng nhập', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [sessionProvider.overrideWith(_SwitchSession.new)]);
    addTearDown(container.dispose);
    await container.read(mentorFavoritesProvider.future);
    final key = 'mentor_favs_${container.read(sessionProvider).user!.id}';
    final pending = container.read(mentorFavoritesProvider.notifier).toggle(MentorUtil.students);
    (container.read(sessionProvider.notifier) as _SwitchSession).switchAccount();
    await pending;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('mentor_favs_${container.read(sessionProvider).user!.id}'), isNull);
    expect(prefs.getStringList(key), ['students']);
  });

  for (final screen in <String, Widget>{
    'Home': const MentorHomeScreen(),
    'Tiện ích': const MentorUtilitiesScreen(),
  }.entries) {
    testWidgets('${screen.key}: không hiện lớp chính khi đang tải hoặc đọc quyền thất bại', (tester) async {
      final ready = Completer<bool>();
      await pumpScreen(
        tester,
        ProviderScope(
          overrides: [mentorSubstituteOnlyProvider.overrideWith((ref) => ready.future)],
          child: screen.value,
        ),
      );
      expect(find.text('Lớp phụ trách'), findsNothing);
      ready.completeError(ApiError(status: 503, code: 'SERVICE_UNAVAILABLE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Lớp phụ trách'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lang in ['vi', 'en']) {
    testWidgets('Tiện ích lỗi quyền có thể thử lại, 320 chữ 1.3 $lang', (tester) async {
      var reads = 0;
      await pumpScreen(
        tester,
        ProviderScope(
          overrides: [
            mentorSubstituteOnlyProvider.overrideWith((ref) async {
              if (++reads == 1) throw ApiError.network();
              return false;
            }),
          ],
          child: const MentorUtilitiesScreen(),
        ),
        language: lang,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/mf6_utilities_error_320_$lang.png'),
      );
      await tester.tap(find.text(lang == 'vi' ? 'Thử lại' : 'Try again'));
      await tester.pumpAndSettle();
      expect(find.text(lang == 'vi' ? 'Lớp phụ trách' : 'My classes'), findsOneWidget);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Route Mentor không tồn tại hiển thị lối về trang chủ', (tester) async {
    final container = ProviderContainer(overrides: [sessionProvider.overrideWith(() => FixedSession(Role.MENTOR))]);
    final router = container.read(routerProvider);
    router.go(Routes.mentorPage('obsolete'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy trang'), findsNWidgets(2));
    expect(find.text('Về trang chủ'), findsOneWidget);
    await tester.tap(find.text('Về trang chủ'));
    expect(router.routeInformationProvider.value.uri.path, Routes.mentor);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });

  testWidgets('Tiện ích mở trực tiếp giữ request lịch qua nhiều frame', (tester) async {
    final ready = Completer<TeachingSchedule>();
    var disposed = false;
    await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => openMentorSessionUtility(context, ref, MentorUtil.room),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [
        mentorScheduleProvider(mentorHomeQuery).overrideWith((ref) {
          ref.onDispose(() => disposed = true);
          return ready.future;
        }),
      ],
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(disposed, isFalse, reason: 'Chỉ read(future) không giữ provider autoDispose');
    ready.complete(TeachingSchedule(entries: const [], timeZone: 'Asia/Ho_Chi_Minh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hiện không có buổi dạy đang diễn ra.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(disposed, isTrue);
  });

  testWidgets('Skeleton giảm chuyển động ngừng ticker và đọc nhãn tiếng Việt', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: Skeleton()),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  for (final staff in [true, false]) {
    testWidgets('Nút ${staff ? 'Staff' : 'Student'} có action tap cho trình đọc màn hình', (tester) async {
      final semantics = tester.ensureSemantics();
      var calls = 0;
      Widget button(bool enabled) => MaterialApp(
        home: Scaffold(
          body: staff
              ? StaffButton(label: 'Submit', onPressed: enabled ? () => calls++ : null)
              : MindyButton(label: 'Submit', onPressed: enabled ? () => calls++ : null),
        ),
      );
      await tester.pumpWidget(button(true));
      final node = tester.getSemantics(find.bySemanticsLabel('Submit'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.platformDispatcher.onSemanticsActionEvent!(
        SemanticsActionEvent(type: SemanticsAction.tap, nodeId: node.id, viewId: tester.view.viewId),
      );
      expect(calls, 1);
      await tester.pumpWidget(button(false));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Submit')).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    });
  }
}
