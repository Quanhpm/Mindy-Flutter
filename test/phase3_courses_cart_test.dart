import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/features/cart/cart_controller.dart';
import 'package:mindy_flutter/features/cart/cart_models.dart';
import 'package:mindy_flutter/features/cart/cart_sheet.dart';
import 'package:mindy_flutter/features/courses/course_sheet.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/courses/courses_providers.dart';
import 'package:mindy_flutter/features/courses/courses_screen.dart';
import 'package:mindy_flutter/features/courses/filter_sheet.dart';
import 'package:mindy_flutter/features/courses/recommendations.dart';

import 'mentor_mf2_test.dart' show pumpScreen;

const _mockCourse = Course(
  id: 'c-1',
  code: 'CS101',
  title: 'Lập trình Flutter cơ bản',
  description: 'Khoá học thực chiến từ cơ bản đến nâng cao cùng chuyên gia.',
  imgUrl: null,
  priceAmount: 1500000,
  categoryId: 'cat-1',
  categoryName: 'Mobile Development',
  openClass: OpenClass(
    startDate: '2026-11-15',
    deliveryMode: DeliveryMode.ONLINE,
  ),
);

const _mockClass = CourseClass(
  id: 'cls-1',
  courseId: 'c-1',
  code: 'FL01',
  name: 'Lớp T2-T4-T6 Buổi Tối',
  startDate: '2026-11-15',
  endDate: '2026-12-30',
  deliveryMode: DeliveryMode.ONLINE,
  availableSeats: 5,
  mentorName: 'Mindy Mentor',
);

class _TestCartNotifier extends CartController {
  @override
  Future<Cart> build() async => const Cart(
        totalAmount: 1500000,
        items: [
          CartItem(
            classId: 'cls-1',
            classCode: 'FL01',
            className: 'Lớp T2-T4-T6 Buổi Tối',
            courseId: 'c-1',
            courseTitle: 'Lập trình Flutter cơ bản',
            deliveryMode: DeliveryMode.ONLINE,
            startDate: '2026-11-15',
            endDate: '2026-12-30',
            priceSnapshot: 1500000,
            currentPriceAmount: 1500000,
            isPurchasable: true,
          ),
        ],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  group('Phase 3 - Recommendations', () {
    testWidgets('renders title, card with ribbon, view button and dots', (tester) async {
      String? openedId;
      await pumpScreen(
        tester,
        Scaffold(
          body: Recommendations(
            courses: const [_mockCourse],
            onOpen: (id) => openedId = id,
          ),
        ),
        scale: 1.0,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('courses-recommend')), findsOneWidget);
      expect(find.text('Gợi ý cho bạn'), findsOneWidget);
      expect(find.text('RECOMMEND'), findsOneWidget);
      expect(find.byKey(const Key('courses-recommend-c-1')), findsOneWidget);
      expect(find.byKey(const Key('courses-recommend-view-c-1')), findsOneWidget);
      expect(find.byKey(const Key('courses-recommend-dot-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('courses-recommend-view-c-1')));
      expect(openedId, 'c-1');
    });
  });

  group('Phase 3 - FilterSheet', () {
    testWidgets('renders modes tabs, reset and apply buttons', (tester) async {
      DeliveryMode? appliedMode;
      bool closed = false;

      await pumpScreen(
        tester,
        Scaffold(
          body: FilterSheet(
            deliveryMode: DeliveryMode.ONLINE,
            total: 10,
            onApply: (mode) => appliedMode = mode,
            onClose: () => closed = true,
          ),
        ),
        scale: 1.0,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('courses-filter-sheet')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-mode-all')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-mode-ONLINE')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-mode-OFFLINE')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-reset')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-apply')), findsOneWidget);

      await tester.tap(find.byKey(const Key('courses-filter-mode-OFFLINE')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('courses-filter-apply')));
      expect(appliedMode, DeliveryMode.OFFLINE);
      expect(closed, isTrue);
    });
  });

  group('Phase 3 - CoursesScreen', () {
    testWidgets('renders BrandBar header, categories, grid and tab bar', (tester) async {
      await pumpScreen(
        tester,
        const CoursesScreen(),
        width: 390,
        height: 844,
        scale: 1.0,
        overrides: [
          categoriesProvider.overrideWith((ref) async => [
                const CourseCategory(id: 'cat-1', name: 'Mobile', isActive: true),
              ]),
          catalogPageProvider.overrideWith((ref) async => Paged(
                items: const [_mockCourse],
                total: 1,
                page: 1,
                pageSize: 6,
              )),
          recommendationsProvider.overrideWith((ref) async => const [_mockCourse]),
          cartProvider.overrideWith(_TestCartNotifier.new),
        ],
      );
      await tester.pumpAndSettle();

      // BrandBar header with prefix 'courses'
      expect(find.byKey(const Key('courses-header')), findsOneWidget);
      expect(find.byKey(const Key('courses-cart-button')), findsOneWidget);

      // Recommendations carousel
      expect(find.byKey(const Key('courses-recommend')), findsOneWidget);

      // Categories and filter
      expect(find.byKey(const Key('courses-categories')), findsOneWidget);
      expect(find.byKey(const Key('courses-filter-button')), findsOneWidget);
      expect(find.byKey(const Key('courses-category-all')), findsOneWidget);
      expect(find.byKey(const Key('courses-category-cat-1')), findsOneWidget);

      // Grid
      expect(find.byKey(const Key('courses-grid')), findsOneWidget);
      expect(find.byKey(const Key('courses-course-c-1')), findsOneWidget);

      // Floating tab bar with prefix 'courses'
      expect(find.byKey(const Key('courses-tab-courses')), findsOneWidget);
      expect(find.byKey(const Key('courses-tab-home')), findsOneWidget);
    });
  });

  group('Phase 3 - CourseSheet', () {
    testWidgets('renders hero, title, class list, pick button and CTA buttons', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: CourseSheet(courseId: 'c-1')),
        width: 390,
        height: 844,
        scale: 1.0,
        overrides: [
          courseDetailProvider('c-1').overrideWith((ref) async => _mockCourse),
          courseClassesProvider('c-1').overrideWith((ref) async => const [_mockClass]),
          cartProvider.overrideWith(_TestCartNotifier.new),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('course-sheet')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-hero')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-title')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-body')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-class-cls-1')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-pick-cls-1')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-price')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-add-to-cart')), findsOneWidget);
      expect(find.byKey(const Key('course-sheet-buy')), findsOneWidget);
    });
  });

  group('Phase 3 - CartSheet', () {
    testWidgets('renders cart title, item, remove button, total and checkout button', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: CartSheet()),
        width: 390,
        height: 844,
        scale: 1.0,
        overrides: [
          cartProvider.overrideWith(_TestCartNotifier.new),
          courseDetailProvider('c-1').overrideWith((ref) async => _mockCourse),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cart-sheet')), findsOneWidget);
      expect(find.byKey(const Key('cart-title')), findsOneWidget);
      expect(find.byKey(const Key('cart-item-cls-1')), findsOneWidget);
      expect(find.byKey(const Key('cart-item-remove-cls-1')), findsOneWidget);
      expect(find.byKey(const Key('cart-total')), findsOneWidget);
      expect(find.byKey(const Key('cart-checkout')), findsOneWidget);
    });
  });
}
