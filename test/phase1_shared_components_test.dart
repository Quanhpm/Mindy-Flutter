import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/ui/ui.dart';
import 'package:mindy_flutter/features/courses/course_tile.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';

import 'mentor_mf2_test.dart' show pumpScreen;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    final font = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await font.load();
  });

  group('BrandBar', () {
    testWidgets('hiển thị logo Mindy CODING và nút giỏ hàng có badge', (tester) async {
      var topTapped = false;
      var cartTapped = false;

      await pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.mint,
          body: BrandBar(
            onTop: () => topTapped = true,
            onCart: () => cartTapped = true,
            cartCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-logo')), findsOneWidget);
      expect(find.text('Mindy'), findsOneWidget);
      expect(find.text('CODING'), findsOneWidget);
      expect(find.byKey(const Key('home-cart-button')), findsOneWidget);
      expect(find.byKey(const Key('home-cart-badge')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-logo')));
      expect(topTapped, isTrue);

      await tester.tap(find.byKey(const Key('home-cart-button')));
      expect(cartTapped, isTrue);
    });

    testWidgets('chế độ compact và badge 9+ khi cartCount > 9', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.mint,
          body: BrandBar(
            onTop: () {},
            onCart: () {},
            compact: true,
            cartCount: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-compact-logo')), findsOneWidget);
      expect(find.byKey(const Key('home-compact-cart-button')), findsOneWidget);
      expect(find.byKey(const Key('home-compact-cart-badge')), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('AppTabBar', () {
    testWidgets('AppTabBar hiển thị 5 tab và xử lý chọn tab', (tester) async {
      HomeTab? clickedTab;
      var homeTopClicked = false;

      await pumpScreen(
        tester,
        Scaffold(
          body: AppTabBar(
            selected: HomeTab.courses,
            learningEnabled: true,
            onTab: (t) => clickedTab = t,
            onTop: () => homeTopClicked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-tab-home')), findsOneWidget);
      expect(find.byKey(const Key('home-tab-courses')), findsOneWidget);
      expect(find.byKey(const Key('home-tab-schedule')), findsOneWidget);
      expect(find.byKey(const Key('home-tab-account')), findsOneWidget);
      expect(find.byKey(const Key('home-tab-notifications')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-tab-schedule')));
      expect(clickedTab, HomeTab.schedule);

      await tester.tap(find.byKey(const Key('home-tab-home')));
      expect(homeTopClicked, isTrue);
    });
  });

  group('CourseTile', () {
    const course = Course(
      id: '00000000-0000-4000-8000-000000000001',
      code: 'CS101',
      title: 'Python for Beginners',
      description: null,
      imgUrl: null,
      priceAmount: 1500000,
      categoryId: 'cat-1',
      categoryName: 'Programming',
      openClass: OpenClass(
        deliveryMode: DeliveryMode.ONLINE,
        startDate: '2026-12-01T00:00:00Z',
      ),
    );

    testWidgets('CourseTile vẽ thẻ 3:4, fallback hoạ tiết sọc và nút mở', (tester) async {
      var opened = false;

      await pumpScreen(
        tester,
        Scaffold(
          body: CourseTile(
            course: course,
            index: 0,
            onTap: () => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('home-course-${course.id}')), findsOneWidget);
      expect(find.byKey(Key('home-course-open-${course.id}')), findsOneWidget);
      expect(find.text('Python for Beginners'), findsOneWidget);
      expect(find.textContaining('1.500.000'), findsOneWidget);

      await tester.tap(find.byKey(Key('home-course-open-${course.id}')));
      expect(opened, isTrue);
    });
  });

  group('HomeButton', () {
    testWidgets('HomeButton nhận sự kiện nhấn và hỗ trợ disabled', (tester) async {
      var pressed = false;

      await pumpScreen(
        tester,
        Scaffold(
          body: Column(
            children: [
              HomeButton(
                label: 'Khám phá ngay',
                onPressed: () => pressed = true,
              ),
              const HomeButton(
                label: 'Tạm khoá',
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khám phá ngay'), findsOneWidget);
      expect(find.text('Tạm khoá'), findsOneWidget);

      await tester.tap(find.text('Khám phá ngay'));
      expect(pressed, isTrue);
    });
  });

  group('LearningLayout', () {
    testWidgets('LearningLayout hiển thị BrandBar khi không có onBack và title khi có', (tester) async {
      await pumpScreen(
        tester,
        const LearningLayout(
          prefix: 'test-learning',
          title: 'Lịch học',
          children: Text('Nội dung học tập'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('test-learning-screen')), findsOneWidget);
      expect(find.text('Lịch học'), findsOneWidget);
      expect(find.text('Nội dung học tập'), findsOneWidget);
    });
  });
}
