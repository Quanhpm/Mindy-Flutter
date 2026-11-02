import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/account/account_screen.dart';
import 'package:mindy_flutter/features/cart/cart_controller.dart';
import 'package:mindy_flutter/features/courses/courses_models.dart';
import 'package:mindy_flutter/features/courses/courses_screen.dart';
import 'package:mindy_flutter/features/home/home_screen.dart';
import 'package:mindy_flutter/features/home/home_providers.dart';
import 'package:mindy_flutter/features/my_classes/my_classes_screen.dart';
import 'package:mindy_flutter/features/schedule/schedule_screen.dart';

/// Fixture chỉ nằm ở tool; mọi API không override đều bị chặn ngay tại adapter.
class _NoNetwork implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":"PREVIEW_ONLY"}',
    503,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _StudentSession extends SessionController {
  @override
  SessionState build() => SessionState(
    ready: true,
    epoch: 1,
    user: SessionUser(
      id: '00000000-0000-4000-8000-000000000001',
      displayName: 'Học viên Mindy',
      email: 'student@example.test',
      phone: null,
      role: Role.STUDENT,
      createdAt: DateTime.utc(2026),
    ),
  );
}

Future<void> main() async {
  if (!kDebugMode) throw StateError('UI preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  initTimeZones();
  final locale = await I18n.load();
  final client = ApiClient(cookieJar: CookieJar());
  client.dio.httpClientAdapter = _NoNetwork();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        initialLocaleProvider.overrideWithValue(locale),
        apiClientProvider.overrideWithValue(client),
        sessionProvider.overrideWith(_StudentSession.new),
        cartCountProvider.overrideWithValue(0),
        homeCoursesProvider.overrideWith(
          (ref) async => [
            for (var i = 1; i <= 4; i++)
              Course(
                id: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
                code: 'COURSE-$i',
                title: ['Lập trình Python', 'Thiết kế website', 'Ứng dụng di động', 'Cơ sở dữ liệu'][i - 1],
                description: null,
                imgUrl: null,
                priceAmount: 1500000,
                categoryId: '00000000-0000-4000-8000-000000000010',
                categoryName: 'Lập trình',
                openClass: const OpenClass(startDate: '2026-11-10', deliveryMode: DeliveryMode.ONLINE),
              ),
          ],
        ),
        homeNextSessionProvider.overrideWith(
          (ref) async => HomeNextSession(session: null, timeZone: 'Asia/Ho_Chi_Minh', asOf: DateTime.now()),
        ),
      ],
      child: const _Preview(),
    ),
  );
}

class _Preview extends ConsumerStatefulWidget {
  const _Preview();
  @override
  ConsumerState<_Preview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<_Preview> {
  late final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(path: 'courses', builder: (_, _) => const CoursesScreen()),
          GoRoute(path: 'schedule', builder: (_, _) => const ScheduleScreen()),
          GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(
        path: Routes.myClassesPath,
        builder: (_, _) => const MyClassesScreen(origin: 'home'),
      ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: buildAppTheme(),
    routerConfig: router,
    debugShowCheckedModeBanner: false,
    locale: ref.watch(localeProvider),
    supportedLocales: I18n.supported,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) =>
        Banner(message: ref.watch(trProvider)('preview.title'), location: BannerLocation.topEnd, child: child!),
  );
}
