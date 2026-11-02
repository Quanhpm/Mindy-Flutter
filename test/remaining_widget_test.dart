import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/operations/leave_screens.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_models.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_providers.dart';
import 'package:mindy_flutter/features/mentor/operations/session_edit_screens.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_api.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';
import 'package:mindy_flutter/features/payment/payment_result_ticket.dart';
import 'package:mindy_flutter/features/cart/cart_controller.dart';
import 'package:mindy_flutter/features/cart/cart_models.dart';
import 'package:mindy_flutter/features/cart/cart_sheet.dart';
import 'package:mindy_flutter/features/courses/course_sheet.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/courses/courses_providers.dart';
import 'package:mindy_flutter/features/my_classes/class_detail_screen.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_providers.dart';
import 'package:mindy_flutter/features/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/schedule/schedule_providers.dart';
import 'package:mindy_flutter/features/schedule/schedule_screen.dart';
import '../tool/preview/operations_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart' show previewNow;
import 'package:mindy_flutter/core/utils/clock.dart';
import 'mentor_mf2_test.dart' show pumpScreen;

List<Override> _overrides() => [
  mentorClassesProvider.overrideWith((_) async => []),
  mentorLeavesProvider.overrideWith((_, status) async => [operationRequest()]),
  mentorLeaveDetailProvider.overrideWith((_, id) async {
    final request = operationRequest();
    return LeaveDetail(request, request.items);
  }),
  mentorNoteProvider.overrideWith(
    (_, id) async => TeachingNote(id, 1, 'Các nội dung đã dạy trong buổi học.', 'Ôn tập và làm bài trước buổi sau.'),
  ),
  mentorRoomProvider.overrideWith((_, id) async => operationRoom()),
];
const _course = Course(
  id: operationRequestId,
  code: 'SYNTHETIC',
  title: 'Lập trình nhập môn',
  description:
      'Khóa học cơ bản với nhiều nội dung. Nội dung được trình bày theo từng chương, bài học và bài tập thực hành dành cho học viên mới. Phần mô tả dài để thử khả năng xem thêm hoặc thu gọn trên màn hình nhỏ.',
  imgUrl: null,
  priceAmount: 1000000,
  categoryId: operationRequestId,
  categoryName: 'Lập trình',
);

class _FixtureCart extends CartController {
  static const cart = Cart(
    totalAmount: 1000000,
    items: [
      CartItem(
        classId: operationSessionId,
        classCode: 'TEST',
        className: 'Lớp lập trình nhập môn buổi tối',
        courseId: operationRequestId,
        courseTitle: 'Lập trình nhập môn',
        deliveryMode: DeliveryMode.ONLINE,
        startDate: '2026-11-02',
        endDate: '2026-12-02',
        priceSnapshot: 900000,
        currentPriceAmount: 1000000,
        isPurchasable: true,
      ),
    ],
  );
  @override
  Future<Cart> build() async => cart;
  @override
  Future<Cart> refresh() async => cart;
}

class _FixtureAnchor extends ScheduleAnchor {
  @override
  String build() => '2026-11-02';
}

List<Override> _studentOverrides() {
  final start = previewNow;
  final session = ClassSession(
    id: operationSessionId,
    sessionNumber: 1,
    title: 'Nội dung buổi học',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    roomName: null,
    status: SessionStatus.SCHEDULED,
  );
  return [
    learningTimeZoneProvider.overrideWith((_) async => 'Asia/Ho_Chi_Minh'),
    scheduleAnchorProvider.overrideWith(_FixtureAnchor.new),
    appNowProvider.overrideWith((_) => Stream.value(previewNow)),
    cartProvider.overrideWith(_FixtureCart.new),
    courseDetailProvider.overrideWith((_, id) async => _course),
    courseClassesProvider.overrideWith(
      (_, id) async => [
        const CourseClass(
          id: operationSessionId,
          courseId: operationRequestId,
          code: 'TEST',
          name: 'Lớp buổi tối',
          startDate: '2026-11-02',
          endDate: '2026-12-02',
          deliveryMode: DeliveryMode.ONLINE,
          availableSeats: 8,
          mentorName: 'Giảng viên tổng hợp',
        ),
      ],
    ),
    classSessionsProvider.overrideWith((_, id) async => [start]),
    classDetailProvider.overrideWith(
      (_, id) async => (
        detail: ClassDetail(
          id: id,
          code: 'TEST',
          name: 'Lớp lập trình nhập môn',
          startDate: '2026-11-02',
          endDate: '2026-12-02',
          deliveryMode: DeliveryMode.ONLINE,
          classStatus: ClassStatus.OPEN,
          mentorName: 'Giảng viên tổng hợp',
          accessMode: AccessMode.FULL,
          units: [
            ClassUnit(id: operationRequestId, title: 'Nội dung chương học', sessions: [session]),
          ],
        ),
        enrollment: const Enrollment(
          enrollmentId: operationRequestId,
          enrollmentStatus: EnrollmentStatus.ACTIVE,
          isHoldExpired: false,
          courseId: operationRequestId,
          courseCode: 'TEST',
          courseTitle: 'Lập trình nhập môn',
          courseImageUrl: null,
          classId: operationSessionId,
          classCode: 'TEST',
          className: 'Lớp lập trình nhập môn',
          classStatus: ClassStatus.OPEN,
          startDate: '2026-11-02',
          endDate: '2026-12-02',
          deliveryMode: DeliveryMode.ONLINE,
          mentorName: 'Giảng viên tổng hợp',
          accessMode: AccessMode.FULL,
          accessReason: AccessReason.ACTIVE_ENROLLMENT,
          canViewClass: true,
          canViewSchedule: true,
          order: null,
        ),
      ),
    ),
    scheduleWeekProvider.overrideWith(
      (_) async => ScheduleWeek(
        timeZone: 'Asia/Ho_Chi_Minh',
        asOf: start,
        items: [
          ScheduleSession(
            sessionId: operationSessionId,
            sessionNumber: 1,
            sessionTitle: session.title,
            sessionStatus: SessionStatus.SCHEDULED,
            startsAt: start,
            endsAt: session.endsAt,
            classId: operationRequestId,
            classCode: 'TEST',
            className: 'Lớp lập trình nhập môn',
            classStatus: ClassStatus.OPEN,
            courseTitle: _course.title,
            deliveryMode: DeliveryMode.ONLINE,
            mentorName: 'Giảng viên tổng hợp',
            roomName: null,
            access: ScheduleAccess.FULL,
          ),
        ],
      ),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    for (final entry in {
      'Nunito': ['Nunito-Regular.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf'],
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
  for (final language in ['vi', 'en']) {
    final screens = <String, Widget>{
      'leave': const MentorLeaveScreen(),
      'leave_create': const MentorLeaveCreateScreen(),
      'leave_detail': const MentorLeaveDetailScreen(requestId: operationRequestId),
      'notes': const MentorNotesScreen(sessionId: operationSessionId),
      'meeting': const MentorMeetingScreen(sessionId: operationSessionId),
      'payment_ticket': PaymentResultTicket(
        status: OrderStatus.PAID,
        orderCode: 'MINDY-202611020001',
        amount: 12000000,
        onHome: () {},
        onRetry: () {},
      ),
    };
    for (final entry in screens.entries) {
      testWidgets('${entry.key} vi/en 320×640 chữ 1.3: $language', (tester) async {
        await pumpScreen(tester, entry.value, language: language, overrides: _overrides());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (['leave', 'notes', 'payment_ticket'].contains(entry.key)) {
          await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile('goldens/remaining_${entry.key}_320_$language.png'),
          );
        }
        final list = find.byType(ListView);
        if (list.evaluate().isNotEmpty) {
          await tester.drag(list.first, const Offset(0, -360));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final language in ['vi', 'en']) {
    for (final entry in <String, Widget>{
      'course': Scaffold(
        body: PrimaryScrollController(
          controller: ScrollController(),
          child: const CourseSheet(courseId: operationRequestId),
        ),
      ),
      'cart': Scaffold(
        body: SizedBox(
          height: 256,
          child: PrimaryScrollController(controller: ScrollController(), child: const CartSheet()),
        ),
      ),
      'schedule': const ScheduleScreen(),
      'student_class': const ClassDetailScreen(classId: operationSessionId),
    }.entries) {
      testWidgets('${entry.key} màn nhỏ/chữ lớn $language', (tester) async {
        await pumpScreen(tester, entry.value, language: language, overrides: _studentOverrides());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (entry.key == 'cart') {
          final c = ProviderScope.containerOf(tester.element(find.byType(CartSheet)));
          c.read(checkoutPendingProvider.notifier).set([operationSessionId]);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          return;
        }
        if (entry.key == 'student_class') {
          final btn = find.byKey(const Key('class-detail-participants'));
          if (btn.evaluate().isNotEmpty) {
            await tester.tap(btn);
          } else {
            final label = language == 'vi' ? 'Người tham gia' : 'Participants';
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (entry.key == 'schedule') {
          await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile('goldens/remaining_schedule_320_$language.png'),
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Nhập note và link bật bảo vệ back ngay, không đợi submit', (tester) async {
    for (final screen in <Widget>[
      const MentorNotesScreen(sessionId: operationSessionId),
      const MentorMeetingScreen(sessionId: operationSessionId),
    ]) {
      await pumpScreen(tester, screen, overrides: _overrides());
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope).last).canPop, isTrue);
      await tester.enterText(find.byType(TextField).first, 'https://example.test/changed');
      await tester.pump();
      expect(tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope).last).canPop, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
