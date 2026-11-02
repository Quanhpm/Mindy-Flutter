import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/home/next_session_card.dart';
import 'package:mindy_flutter/features/mentor/mentor_home_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_screen.dart';
import 'package:mindy_flutter/features/mentor/session/room_sheet.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_models.dart';
import 'package:mindy_flutter/features/mentor/substitute/substitute_screen.dart';
import 'package:mindy_flutter/features/notifications/notifications_models.dart';
import 'package:mindy_flutter/features/notifications/notifications_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/preview/mentor_fixtures.dart';

Map<String, Object?> sessionJson([Map<String, Object?> changes = const {}]) => {
  'sessionId': '00000000-0000-4000-8000-000000000101',
  'classId': '00000000-0000-4000-8000-000000000010',
  'classUnitId': '00000000-0000-4000-8000-000000000020',
  'title': 'Unit 5',
  'startsAt': '2026-11-02T14:00:00+07:00',
  'endsAt': '2026-11-02T15:30:00+07:00',
  'status': 'SCHEDULED',
  'assignmentType': 'PRIMARY',
  'version': 2,
  'primaryMentor': {'id': previewMentor.id, 'displayName': 'Mentor'},
  'effectiveMentor': null,
  'timeZone': previewZone,
  'asOf': '2026-11-02T07:00:00Z',
  'actualStartedAt': null,
  'actualEndedAt': null,
  'editableUntil': null,
  'makeupForSessionId': null,
  'makeupRootSessionId': null,
  ...changes,
};

class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
    ready: true,
    epoch: 1,
    user: SessionUser(
      id: previewMentor.id,
      displayName: previewMentor.displayName!,
      email: 'mentor@example.test',
      phone: null,
      role: Role.MENTOR,
      createdAt: DateTime.utc(2026),
    ),
  );
}

class _Favorites extends MentorFavoritesController {
  @override
  Future<List<MentorUtil>> build() async => const [];
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  double width = 320,
  double height = 640,
  double scale = 1.3,
  String language = 'vi',
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        initialLocaleProvider.overrideWithValue(Locale(language)),
        sessionProvider.overrideWith(_Session.new),
        mentorFavoritesProvider.overrideWith(_Favorites.new),
        mentorSubstituteOnlyProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(key: const ValueKey('capture'), child: screen),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/illustrations/mindy-frog-peek.png'),
      tester.element(find.byType(MaterialApp)),
    ),
  );
  await tester.pump();
}

Widget scheduleScreen(AsyncValue<TeachingSchedule> value, {ValueChanged<String>? onDay, ValueChanged<int>? onWeek}) =>
    MentorScheduleScreen(
      value: value,
      selectedDay: previewDay,
      now: previewNow,
      onDaySelected: onDay ?? (_) {},
      onWeekChanged: onWeek ?? (_) {},
      onRefresh: () async {},
      onRetry: () {},
      onRoom: (_) {},
      onAttendance: (_) {},
      onBack: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    for (final entry in {
      'Nunito': ['Nunito-Regular.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf'],
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

  test('Session parser từ chối enum, timezone, version và thời gian sai contract', () {
    for (final invalid in <Map<String, Object?>>[
      {'status': 'UNKNOWN'},
      {'assignmentType': 'BOTH'},
      {'version': 0},
      {'timeZone': 'Invalid/Zone'},
      {'endsAt': '2026-11-02T13:00:00+07:00'},
      {'startsAt': '2026-11-02T14:00:00'},
    ]) {
      expect(
        () => TeachingSession.fromJson(Json(sessionJson(invalid), 'INVALID_MENTOR_RESPONSE')),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 502)),
      );
    }
    expect(TeachingSession.fromJson(Json(sessionJson())).id, sampleSchedule().entries.first.session.id);
  });

  test('Trạng thái buổi ưu tiên lifecycle; SCHEDULED hết giờ không bị coi là COMPLETED', () {
    final scheduled = TeachingSession.fromJson(Json(sessionJson()));
    expect(
      scheduled.displayStatus(scheduled.startsAt.subtract(const Duration(seconds: 1))),
      TeachingDisplayStatus.upcoming,
    );
    expect(scheduled.displayStatus(scheduled.startsAt), TeachingDisplayStatus.live);
    expect(scheduled.displayStatus(scheduled.endsAt), TeachingDisplayStatus.ended);
    expect(
      TeachingSession.fromJson(Json(sessionJson({'status': 'COMPLETED'}))).displayStatus(previewNow),
      TeachingDisplayStatus.completed,
    );
    expect(
      TeachingSession.fromJson(Json(sessionJson({'status': 'CANCELLED'}))).displayStatus(previewNow),
      TeachingDisplayStatus.cancelled,
    );
    expect(
      TeachingSession.fromJson(Json(sessionJson({'status': 'IN_PROGRESS'}))).displayStatus(DateTime.utc(2027)),
      TeachingDisplayStatus.live,
    );
  });

  test('Ngày và khoảng tuần theo timezone server qua DST', () {
    final spring = Dates.weekRange('2026-03-08', 'America/New_York');
    expect(spring.to.difference(spring.from).inHours, 167);
    final autumn = Dates.weekRange('2026-11-01', 'America/New_York');
    expect(autumn.to.difference(autumn.from).inHours, 169);
    final schedule = TeachingSchedule(entries: sampleSchedule().entries, timeZone: 'Pacific/Honolulu');
    expect(schedule.onDay('2026-11-01').map((e) => e.session.id), contains(sampleSchedule().entries.first.session.id));
  });

  test('Home chọn buổi đang dạy trước buổi sắp tới; bỏ buổi huỷ và hết giờ', () {
    final schedule = sampleSchedule();
    expect(schedule.nextToday(previewNow)?.session.id, schedule.entries.first.session.id);
    expect(schedule.nextToday(DateTime.utc(2026, 11, 2, 9))?.session.id, schedule.entries[1].session.id);
    expect(schedule.nextToday(DateTime.utc(2026, 11, 2, 14)), isNull);
    expect(schedule.substitutes, hasLength(3));
    expect(schedule.substitutes.every((e) => e.session.isSubstitute), isTrue);
    expect(schedule.substitutesForDisplay(previewNow).first.session.id, schedule.entries[1].session.id);
    expect(schedule.substitutesForDisplay(previewNow).last.session.status, TeachingStatus.COMPLETED);
  });

  test('Room kiểm tra ID và URL trước khi mở link', () {
    final id = sampleSchedule().entries.first.session.id;
    for (final url in ['javascript:alert(1)', 'https://user:secret@example.test/room', 'invalid']) {
      expect(
        () => TeachingRoom.fromJson(
          Json({'session': sessionJson(), 'accessScope': 'SESSION', 'roomName': null, 'meetingUrl': url}),
          sessionId: id,
        ),
        throwsA(isA<ApiError>()),
      );
    }
    expect(
      () => TeachingRoom.fromJson(
        Json({'session': sessionJson(), 'accessScope': 'SESSION', 'roomName': null, 'meetingUrl': null}),
        sessionId: previewMentor.id,
      ),
      throwsA(isA<ApiError>()),
    );
  });

  test('Thông báo dùng data/meta cursor; không đọc nhầm items hay cursor sai', () {
    final page = NotificationPage.fromJson(
      Json({
        'data': <Object?>[],
        'meta': {'hasMore': false, 'nextCursor': null},
      }),
    );
    expect(page.items, isEmpty);
    expect(
      () => NotificationPage.fromJson(
        Json({
          'items': <Object?>[],
          'meta': {'hasMore': false, 'nextCursor': null},
        }),
      ),
      throwsA(isA<ApiError>()),
    );
    expect(
      () => NotificationPage.fromJson(
        Json({
          'data': <Object?>[],
          'meta': {'hasMore': true, 'nextCursor': null},
        }),
      ),
      throwsA(isA<ApiError>()),
    );
  });

  final states = <String, AsyncValue<TeachingSchedule>>{
    'data': AsyncData(sampleSchedule()),
    'empty': AsyncData(TeachingSchedule(entries: const [], timeZone: previewZone)),
    'loading': const AsyncLoading(),
    'error': AsyncError(
      ApiError(status: 503, code: 'NETWORK_ERROR', message: 'Offline', requestId: 'mf2-test'),
      StackTrace.current,
    ),
  };
  for (final language in ['vi', 'en']) {
    for (final state in states.entries) {
      testWidgets('Lịch ${state.key} ở 320×640 chữ ×1,3 ($language)', (tester) async {
        await pumpScreen(tester, scheduleScreen(state.value), language: language);
        expect(tester.takeException(), isNull);
        if (state.key == 'data' && language == 'vi') {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile('goldens/mf2_schedule_320_vi.png'),
          );
        }
        if (state.key == 'error') expect(find.textContaining('mf2-test'), findsOneWidget);
      });
    }
  }

  testWidgets('Chọn ngày và đổi tuần gọi đúng callback', (tester) async {
    String? day;
    int? offset;
    await pumpScreen(
      tester,
      scheduleScreen(AsyncData(sampleSchedule()), onDay: (value) => day = value, onWeek: (value) => offset = value),
    );
    await tester.tap(find.text('T3'));
    expect(day, '2026-11-03');
    await tester.tap(find.byTooltip('Tuần sau'));
    expect(offset, 1);
  });

  for (final state in ['empty', 'loading', 'error', 'disabled']) {
    testWidgets('Thông báo $state có trạng thái đúng ở 320 chữ lớn', (tester) async {
      final value = switch (state) {
        'loading' => const AsyncLoading<NotificationPage>(),
        'error' => AsyncError<NotificationPage>(ApiError.network(), StackTrace.current),
        _ => AsyncData(NotificationPage(items: const [], nextCursor: null, hasMore: false)),
      };
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: NotificationsPanel(
              value: value,
              timeZone: previewZone,
              disabled: state == 'disabled',
              onRetry: () {},
              onRead: (_) async {},
              onReadAll: () async {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (state == 'disabled') expect(find.text('Thông báo hiện chưa được bật tại trung tâm.'), findsOneWidget);
      if (state == 'error') expect(find.text('Thử lại'), findsOneWidget);
    });
  }

  for (final state in states.entries) {
    testWidgets('Thẻ Home ${state.key} không hiện Meet khi chưa có context', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [
              MentorNextSessionCard(
                value: state.value,
                now: previewNow,
                onViewSchedule: () {},
                onRetry: () {},
                onEnterRoom: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Vào Google Meet'), findsNothing);
      if (state.key == 'empty') expect(find.text('Hôm nay bạn không có buổi dạy'), findsOneWidget);
    });
  }

  testWidgets('Home dữ liệu mẫu ở 320 chữ lớn và 390 bình thường', (tester) async {
    Widget home() => MentorHomeScreen(
      teachingCard: MentorNextSessionCard(
        value: AsyncData(sampleSchedule()),
        now: previewNow,
        room: AsyncData(sampleRoom()),
        onViewSchedule: () {},
        onRetry: () {},
        onEnterRoom: (_) {},
      ),
    );
    await pumpScreen(tester, home());
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/mf2_home_320_vi.png'));
    await pumpScreen(tester, home(), width: 390, height: 844, scale: 1);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/mf2_home_390_vi.png'));
  });

  testWidgets('Buổi dạy thay đúng lọc, không overflow ở chữ lớn', (tester) async {
    await pumpScreen(
      tester,
      MentorSubstituteScreen(
        value: AsyncData(sampleSchedule()),
        now: previewNow,
        onRefresh: () async {},
        onRetry: () {},
        onRoom: (_) {},
        onAttendance: (_) {},
        onBack: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/mf2_substitute_320_vi.png'));
  });

  testWidgets('Phòng không link không hiện nút vào; link hợp lệ có thể sao chép', (tester) async {
    Widget room(bool noLink) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: MentorRoomContent(
          value: AsyncData(sampleRoom(noLink: noLink)),
          onRetry: () {},
          onOpen: (_) async {},
        ),
      ),
    );
    await pumpScreen(tester, room(true));
    expect(find.text('Vào phòng học'), findsNothing);
    await pumpScreen(tester, room(false));
    expect(find.text('Vào phòng học'), findsOneWidget);
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/mf2_room_320_vi.png'));
    await tester.tap(find.text('Sao chép liên kết'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thông báo không đổi chấm chưa đọc trước khi callback server hoàn tất', (tester) async {
    final semantics = tester.ensureSemantics();
    final done = Completer<void>();
    var calls = 0;
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: NotificationsPanel(
            value: AsyncData(NotificationPage(items: sampleNotifications(), nextCursor: null, hasMore: false)),
            timeZone: previewZone,
            onRetry: () {},
            onRead: (item) {
              calls++;
              return done.future;
            },
            onReadAll: () async {},
          ),
        ),
      ),
    );
    await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('goldens/mf2_notifications_320_vi.png'));
    await tester.tap(find.text('Tin nhắn mới').first);
    await tester.pump();
    expect(calls, 1);
    expect(find.bySemanticsLabel(RegExp('Chưa đọc')), findsNWidgets(2));
    await tester.tap(find.text('Tin nhắn mới').first);
    await tester.pump();
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
