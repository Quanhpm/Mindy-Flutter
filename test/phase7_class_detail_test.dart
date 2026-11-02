import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/my_classes/class_detail_screen.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_providers.dart';
import 'package:mindy_flutter/features/schedule/schedule_providers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  final now = DateTime.now();

  final mockSession1 = ClassSession(
    id: 'sess-1',
    sessionNumber: 1,
    title: 'Buổi 1: Giới thiệu khóa học',
    startsAt: now.subtract(const Duration(days: 2)),
    endsAt: now.subtract(const Duration(days: 2, hours: -2)),
    roomName: 'P.301',
    status: SessionStatus.COMPLETED,
    meetingUrl: 'https://meet.google.com/abc-defg-hij',
  );

  final mockSession2 = ClassSession(
    id: 'sess-2',
    sessionNumber: 2,
    title: 'Buổi 2: Kiến trúc Widget',
    startsAt: now.add(const Duration(hours: 1)),
    endsAt: now.add(const Duration(hours: 3)),
    roomName: 'P.301',
    status: SessionStatus.SCHEDULED,
    meetingUrl: 'https://meet.google.com/abc-defg-hij',
  );

  final mockDetail = ClassDetail(
    id: 'cls-123',
    code: 'FL-2026',
    name: 'Khóa học Flutter nâng cao',
    startDate: '2026-11-01',
    endDate: '2026-12-01',
    deliveryMode: DeliveryMode.ONLINE,
    classStatus: ClassStatus.IN_PROGRESS,
    mentorName: 'Thầy Hưng',
    accessMode: AccessMode.FULL,
    meetingUrl: 'https://meet.google.com/abc-defg-hij',
    units: [
      ClassUnit(
        id: 'unit-1',
        title: 'Chương 1: Nền tảng Flutter',
        sessions: [mockSession1, mockSession2],
      ),
    ],
  );

  final mockEnrollment = const Enrollment(
    enrollmentId: 'enr-123',
    enrollmentStatus: EnrollmentStatus.ACTIVE,
    isHoldExpired: false,
    courseId: 'crs-1',
    courseCode: 'FL101',
    courseTitle: 'Flutter Foundation',
    courseImageUrl: null,
    classId: 'cls-123',
    classCode: 'FL-2026',
    className: 'Khóa học Flutter nâng cao',
    classStatus: ClassStatus.IN_PROGRESS,
    startDate: '2026-11-01',
    endDate: '2026-12-01',
    deliveryMode: DeliveryMode.ONLINE,
    mentorName: 'Thầy Hưng',
    accessMode: AccessMode.FULL,
    accessReason: AccessReason.ACTIVE_ENROLLMENT,
    canViewClass: true,
    canViewSchedule: true,
    order: null,
  );

  Widget buildSubject({String? sessionId}) {
    return ProviderScope(
      overrides: [
        classDetailProvider('cls-123').overrideWith(
          (ref) async => (detail: mockDetail, enrollment: mockEnrollment),
        ),
        learningTimeZoneProvider.overrideWith((ref) async => 'Asia/Ho_Chi_Minh'),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: ClassDetailScreen(classId: 'cls-123', sessionId: sessionId),
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

  testWidgets('ClassDetailScreen renders hero, meta, sessions and floating footer', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Screen shell & hero
    expect(find.byKey(const Key('class-detail-screen')), findsOneWidget);
    expect(find.byKey(const Key('class-detail-back')), findsOneWidget);
    expect(find.text('FL-2026'), findsOneWidget);
    expect(find.text('Flutter Foundation'), findsOneWidget);

    // Mentor name
    expect(find.text('Thầy Hưng'), findsWidgets);

    // Sessions
    expect(find.byKey(const Key('class-detail-session-sess-1')), findsOneWidget);
    expect(find.byKey(const Key('class-detail-session-sess-2')), findsOneWidget);

    // Floating footer: participants and join buttons
    expect(find.byKey(const Key('class-detail-participants')), findsOneWidget);
    expect(find.byKey(const Key('class-detail-join')), findsOneWidget);
  });

  testWidgets('Tapping participants button opens ClassParticipantsSheet', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Open participants sheet
    await tester.tap(find.byKey(const Key('class-detail-participants')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('class-participants-sheet')), findsOneWidget);
    expect(find.byKey(const Key('class-participants-mentor')), findsOneWidget);
    expect(find.byKey(const Key('class-participants-pending')), findsOneWidget);

    // Close sheet
    expect(find.byKey(const Key('class-participants-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('class-participants-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('class-participants-sheet')), findsNothing);
  });

  testWidgets('Tapping a session navigates to SessionDetailScreen', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap session 2
    await tester.tap(find.byKey(const Key('class-detail-session-sess-2')));
    await tester.pumpAndSettle();

    // Session detail screen
    expect(find.byKey(const Key('class-session-screen')), findsOneWidget);
    expect(find.byKey(const Key('class-session-close')), findsOneWidget);
    expect(find.byKey(const Key('class-session-materials')), findsOneWidget);
    expect(find.byKey(const Key('class-session-join')), findsOneWidget);
    expect(find.text('Buổi 2: Kiến trúc Widget'), findsOneWidget);

    // Close session detail
    await tester.tap(find.byKey(const Key('class-session-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('class-session-screen')), findsNothing);
  });
}
