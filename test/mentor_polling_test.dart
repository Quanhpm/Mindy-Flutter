import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/home/home_providers.dart';
import 'package:mindy_flutter/features/mentor/live_mentor_home_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_api.dart';
import 'package:mindy_flutter/features/notifications/notifications_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/preview/mentor_fixtures.dart';

class _CountApi extends NotificationsApi {
  _CountApi() : super(ApiClient(cookieJar: CookieJar()));
  int counts = 0;
  @override
  Future<int> count({CancelToken? cancel}) async {
    counts++;
    return 0;
  }
}

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
}

class _Dismissed extends MentorDismissedNotices {
  @override
  Future<Set<String>> build() async => {};
}

class _Favorites extends MentorFavoritesController {
  @override
  Future<List<MentorUtil>> build() async => [];
}

void main() {
  testWidgets('Badge chỉ poll khi Home đang hiện và foreground; trở lại thì đọc mới', (tester) async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _CountApi();
    final router = GoRouter(
      initialLocation: '/mentor',
      routes: [
        GoRoute(path: '/mentor', builder: (_, _) => const LiveMentorHomeScreen()),
        GoRoute(
          path: '/mentor/page/schedule',
          builder: (_, _) => const Scaffold(body: Text('Details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          notificationsApiProvider.overrideWithValue(api),
          mentorClockProvider.overrideWithValue(() => previewNow),
          mentorTimeZoneProvider.overrideWith((ref) async => previewZone),
          mentorScheduleProvider.overrideWith((ref, query) async => sampleSchedule()),
          mentorRoomProvider.overrideWith((ref, id) async => sampleRoom()),
          mentorFavoritesProvider.overrideWith(_Favorites.new),
          mentorDismissedNoticesProvider.overrideWith(_Dismissed.new),
          mentorSubstituteOnlyProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final start = api.counts;
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(api.counts, start + 1);
    unawaited(router.push('/mentor/page/schedule'));
    await tester.pumpAndSettle();
    final hidden = api.counts;
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.counts, hidden);
    router.pop();
    await tester.pumpAndSettle();
    expect(api.counts, hidden + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    final background = api.counts;
    expect(background, hidden + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.counts, background + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
