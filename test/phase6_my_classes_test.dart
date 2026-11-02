import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_providers.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_screen.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';
import 'package:mindy_flutter/features/schedule/schedule_providers.dart';

class _FakeMyClassesController extends MyClassesController {
  _FakeMyClassesController(super.view, this.initialData);

  final ClassesList initialData;

  @override
  Future<ClassesList> build() async => initialData;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  final fullEnrollment = Enrollment(
    enrollmentId: 'enr-full',
    enrollmentStatus: EnrollmentStatus.ACTIVE,
    isHoldExpired: false,
    courseId: 'crs-web',
    courseCode: 'WEB101',
    courseTitle: 'Lập trình Web cơ bản',
    courseImageUrl: null,
    classId: 'cls-full',
    classCode: 'WEB-K1',
    className: 'Lớp Web K1',
    classStatus: ClassStatus.OPEN,
    startDate: '2026-11-01',
    endDate: '2026-12-01',
    deliveryMode: DeliveryMode.ONLINE,
    mentorName: 'Thầy Minh',
    accessMode: AccessMode.FULL,
    accessReason: AccessReason.ACTIVE_ENROLLMENT,
    canViewClass: true,
    canViewSchedule: true,
    order: null,
  );

  final cashPreviewEnrollment = Enrollment(
    enrollmentId: 'enr-cash',
    enrollmentStatus: EnrollmentStatus.PENDING_PAYMENT,
    isHoldExpired: false,
    courseId: 'crs-web',
    courseCode: 'WEB101',
    courseTitle: 'Lập trình Web cơ bản',
    courseImageUrl: null,
    classId: 'cls-cash',
    classCode: 'WEB-K2',
    className: 'Lớp Web K2',
    classStatus: ClassStatus.OPEN,
    startDate: '2026-11-05',
    endDate: '2026-12-05',
    deliveryMode: DeliveryMode.OFFLINE,
    mentorName: 'Thầy Hùng',
    accessMode: AccessMode.CASH_PREVIEW,
    accessReason: AccessReason.PENDING_CASH,
    canViewClass: true,
    canViewSchedule: true,
    order: const EnrollmentOrder(
      orderId: 'ord-cash-1',
      orderCode: 'ORD-CASH',
      orderStatus: OrderStatus.PENDING,
      paymentType: PaymentType.CASH,
      expiresAt: null,
      requiresReview: false,
    ),
  );

  final paymentEnrollment = Enrollment(
    enrollmentId: 'enr-payos',
    enrollmentStatus: EnrollmentStatus.PENDING_PAYMENT,
    isHoldExpired: false,
    courseId: 'crs-flutter',
    courseCode: 'FL101',
    courseTitle: 'Lập trình Flutter cơ bản',
    courseImageUrl: null,
    classId: 'cls-flutter',
    classCode: 'FL-K1',
    className: 'Lớp Flutter K1',
    classStatus: ClassStatus.OPEN,
    startDate: '2026-11-10',
    endDate: '2026-12-10',
    deliveryMode: DeliveryMode.ONLINE,
    mentorName: 'Cô Lan',
    accessMode: AccessMode.NONE,
    accessReason: AccessReason.PENDING_PAYOS,
    canViewClass: false,
    canViewSchedule: false,
    order: EnrollmentOrder(
      orderId: 'ord-payos-1',
      orderCode: 'ORD-PAYOS',
      orderStatus: OrderStatus.PENDING,
      paymentType: PaymentType.PAYOS,
      expiresAt: DateTime.utc(2026, 11, 15, 12, 0),
      requiresReview: false,
    ),
  );

  Widget buildSubject(ClassesList data, {String origin = 'account'}) {
    return ProviderScope(
      overrides: [
        myClassesProvider('current').overrideWith(() => _FakeMyClassesController('current', data)),
        myClassesProvider('history').overrideWith(() => _FakeMyClassesController('history', data)),
        learningTimeZoneProvider.overrideWith((ref) async => 'Asia/Ho_Chi_Minh'),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MyClassesScreen(origin: origin),
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('MyClassesScreen renders header, back button, and course folders', (tester) async {
    configureViewport(tester);
    final data = ClassesList(
      items: [fullEnrollment, cashPreviewEnrollment, paymentEnrollment],
      total: 3,
      page: 1,
    );
    await tester.pumpWidget(buildSubject(data));
    await tester.pumpAndSettle();

    // Screen shell & header
    expect(find.byKey(const Key('my-classes-screen')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-back')), findsOneWidget);
    expect(find.text('Lớp của tôi'), findsOneWidget);

    // Course folders
    expect(find.byKey(const Key('my-classes-course-crs-web')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-course-crs-flutter')), findsOneWidget);

    // Initially collapsed: enrollments are hidden
    expect(find.byKey(const Key('my-classes-enrollment-enr-full')), findsNothing);

    // Tap to expand crs-web
    await tester.tap(find.byKey(const Key('my-classes-course-crs-web')));
    await tester.pumpAndSettle();

    // Enrollments in crs-web are now visible
    expect(find.byKey(const Key('my-classes-enrollment-enr-full')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-enrollment-enr-cash')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-open-enr-full')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-open-enr-cash')), findsOneWidget);

    // Tap to expand crs-flutter
    await tester.tap(find.byKey(const Key('my-classes-course-crs-flutter')));
    await tester.pumpAndSettle();

    // Payment enrollment has resume button, no open button
    expect(find.byKey(const Key('my-classes-enrollment-enr-payos')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-resume-enr-payos')), findsOneWidget);
    expect(find.byKey(const Key('my-classes-open-enr-payos')), findsNothing);
  });

  testWidgets('MyClassesScreen renders load more button when hasMore is true', (tester) async {
    configureViewport(tester);
    final data = ClassesList(
      items: [fullEnrollment],
      total: 5,
      page: 1,
    );
    await tester.pumpWidget(buildSubject(data));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-classes-load-more')), findsOneWidget);
  });

  testWidgets('MyClassesScreen renders empty state when no classes', (tester) async {
    configureViewport(tester);
    const data = ClassesList(
      items: [],
      total: 0,
      page: 1,
    );
    await tester.pumpWidget(buildSubject(data));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-classes-empty')), findsOneWidget);
    expect(find.text('Bạn chưa có lớp trong danh sách hiện tại.'), findsOneWidget);
  });
}
