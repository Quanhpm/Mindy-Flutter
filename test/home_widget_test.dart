import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/ui/states.dart';
import 'package:mindy_flutter/features/cart/cart_controller.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/courses/courses_providers.dart';
import 'package:mindy_flutter/features/home/home_providers.dart';
import 'package:mindy_flutter/features/home/home_screen.dart';
import 'package:mindy_flutter/features/home/home_sections.dart';

import 'mentor_mf2_test.dart' show pumpScreen;

const _course = Course(
  id: '00000000-0000-4000-8000-000000000001',
  code: 'SYNTHETIC',
  title: 'Lập trình căn bản',
  description: null,
  imgUrl: null,
  priceAmount: 1000,
  categoryId: '00000000-0000-4000-8000-000000000002',
  categoryName: 'Lập trình',
);

void main() {
  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    final font = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await font.load();
    final mono = FontLoader('RobotoMono')..addFont(rootBundle.load('assets/fonts/RobotoMono.ttf'));
    await mono.load();
  });
  for (final lang in ['vi', 'en']) {
    for (final screen in <String, Widget>{
      'intro': const HomeIntro(),
      'about': const HomeAbout(),
      'compiler': const HomeCompiler(name: 'Học viên Mindy'),
      'footer': const HomeFooter(),
    }.entries) {
      testWidgets('${screen.key} 320 chữ 1.3 $lang', (tester) async {
        await pumpScreen(
          tester,
          Scaffold(
            body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: screen.value),
          ),
          language: lang,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('capture')),
          matchesGoldenFile('goldens/s1_${screen.key}_320_$lang.png'),
        );
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (screen.key == 'intro' || screen.key == 'about') {
          final t = Translator(I18n.bundle(Locale(lang)), Locale(lang));
          final prefix = screen.key == 'intro' ? 'home.intro' : 'home.about.notes';
          for (final (index, name) in [(2, 'second'), (3, 'third')]) {
            final dot = find.bySemanticsLabel(
              t('home.carousel.goToSlide', {'index': index, 'title': t('$prefix.$name.title')}),
            );
            await tester.ensureVisible(dot);
            await tester.tap(dot);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }
  testWidgets('Compiler 390 chữ thường giữ bố cục terminal nổi', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: HomeCompiler(name: 'Mindy'),
        ),
      ),
      width: 390,
      height: 844,
      scale: 1,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/s1_compiler_390_vi.png'));
  });

  testWidgets('Footer mở Khoá học, Lịch học và Lớp của tôi đúng route', (tester) async {
    final router = GoRouter(
      initialLocation: '/preview',
      routes: [
        GoRoute(
          path: '/preview',
          builder: (_, _) => const Scaffold(body: HomeFooter()),
        ),
        for (final path in [Routes.courses, Routes.schedule, '/my-classes'])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(
              body: Text('Destination ${state.uri.path} origin ${state.uri.queryParameters['origin'] ?? ''}'),
            ),
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    for (final (label, path) in [
      ('Khoá học', Routes.courses),
      ('Lịch học', Routes.schedule),
      ('Lớp của tôi', '/my-classes'),
    ]) {
      router.go('/preview');
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Destination $path origin ${path == Routes.myClassesPath ? 'home' : ''}'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  testWidgets('Home không tải lại metadata lớp đã được provider đọc là null', (tester) async {
    var extraRequests = 0;
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [
        cartCountProvider.overrideWithValue(0),
        homeCoursesProvider.overrideWith((ref) async => [_course]),
        homeNextSessionProvider.overrideWith(
          (ref) async => HomeNextSession(session: null, timeZone: 'Asia/Ho_Chi_Minh', asOf: DateTime.now()),
        ),
        nextClassProvider(_course.id).overrideWith((ref) async {
          extraRequests++;
          return null;
        }),
      ],
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(_course.title), 250, scrollable: find.byType(Scrollable).first);
    expect(extraRequests, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home đọc lại khi quay về/foreground, không tải khi bị che', (tester) async {
    var courseReads = 0, scheduleReads = 0;
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [
        cartCountProvider.overrideWithValue(0),
        homeCoursesProvider.overrideWith((ref) async {
          courseReads++;
          return [];
        }),
        homeNextSessionProvider.overrideWith((ref) async {
          scheduleReads++;
          return HomeNextSession(session: null, timeZone: 'Asia/Ho_Chi_Minh', asOf: DateTime.now());
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(courseReads, 1);
    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Detail'))));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(courseReads, 1);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(courseReads, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(courseReads, 3);
    expect(scheduleReads, 3);
  });
  for (final loading in [true, false]) {
    testWidgets('Home các vùng ${loading ? 'loading' : 'error'} không che nội dung giới thiệu', (tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        overrides: [
          cartCountProvider.overrideWithValue(0),
          homeCoursesProvider.overrideWith(
            (ref) => loading
                ? Future<List<Course>>.delayed(const Duration(seconds: 1), () => [])
                : Future.error(ApiError.network()),
          ),
          homeNextSessionProvider.overrideWith(
            (ref) async => HomeNextSession(session: null, timeZone: 'Asia/Ho_Chi_Minh', asOf: DateTime.now()),
          ),
        ],
      );
      if (loading) {
        expect(find.byType(Skeleton), findsWidgets);
        await tester.pump(const Duration(seconds: 1));
      } else {
        expect(find.text('Thử lại'), findsOneWidget);
      }
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(HomeIntro), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byType(HomeIntro), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
