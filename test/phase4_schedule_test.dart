import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_models.dart';
import 'package:mindy_flutter/features/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/schedule/schedule_providers.dart';
import 'package:mindy_flutter/features/schedule/schedule_screen.dart';

import 'mentor_mf2_test.dart' show pumpScreen;

final _sessionStart = DateTime.parse('2026-11-02T08:00:00Z');
final _sessionEnd = DateTime.parse('2026-11-02T10:00:00Z');

final _mockSession = ScheduleSession(
  sessionId: 'sess-1',
  sessionNumber: 1,
  sessionTitle: 'Nhập môn lập trình và cấu trúc máy tính',
  sessionStatus: SessionStatus.SCHEDULED,
  startsAt: _sessionStart,
  endsAt: _sessionEnd,
  classId: 'cls-1',
  classCode: 'FL01',
  className: 'Lớp Lập trình Flutter',
  classStatus: ClassStatus.OPEN,
  courseTitle: 'Flutter Foundation',
  deliveryMode: DeliveryMode.ONLINE,
  mentorName: 'Mindy Mentor',
  roomName: null,
  access: ScheduleAccess.FULL,
);

class _TestAnchor extends ScheduleAnchor {
  @override
  String build() => '2026-11-02';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  group('Phase 4 - ScheduleScreen', () {
    testWidgets('renders calendar header, day buttons, and session groups', (tester) async {
      await pumpScreen(
        tester,
        const ScheduleScreen(),
        width: 390,
        height: 844,
        scale: 1.0,
        overrides: [
          learningTimeZoneProvider.overrideWith((ref) async => 'Asia/Ho_Chi_Minh'),
          scheduleAnchorProvider.overrideWith(_TestAnchor.new),
          scheduleWeekProvider.overrideWith((ref) async => ScheduleWeek(
                items: [_mockSession],
                timeZone: 'Asia/Ho_Chi_Minh',
                asOf: _sessionStart,
              )),
        ],
      );
      await tester.pumpAndSettle();

      // Calendar Header
      expect(find.byKey(const Key('schedule-prev-week')), findsOneWidget);
      expect(find.byKey(const Key('schedule-today')), findsOneWidget);
      expect(find.byKey(const Key('schedule-next-week')), findsOneWidget);

      // Day buttons
      expect(find.byKey(const Key('schedule-day-2026-11-02')), findsOneWidget);
      expect(find.byKey(const Key('schedule-day-2026-11-03')), findsOneWidget);

      // Session row
      expect(find.byKey(const Key('schedule-session-sess-1')), findsOneWidget);
      expect(find.text('FL01'), findsOneWidget);
      expect(find.text('Nhập môn lập trình và cấu trúc máy tính'), findsOneWidget);

      // Tapping a day with no sessions shows schedule-empty-day
      await tester.tap(find.byKey(const Key('schedule-day-2026-11-03')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schedule-empty-day')), findsOneWidget);
    });
  });
}
