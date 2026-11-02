import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/ui/staff/staff_theme.dart';
import 'package:mindy_flutter/core/ui/staff/staff_widgets.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/home/next_session_card.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_sheet.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_home_screen.dart';
import 'package:mindy_flutter/features/mentor/mentor_pages.dart';
import 'package:mindy_flutter/features/mentor/mentor_providers.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_screen.dart';
import 'package:mindy_flutter/features/mentor/session/room_sheet.dart';
import 'package:mindy_flutter/features/mentor/substitute/substitute_screen.dart';
import 'package:mindy_flutter/features/notifications/notifications_models.dart';
import 'package:mindy_flutter/features/notifications/notifications_panel.dart';

import 'preview/mentor_fixtures.dart';
import 'preview/attendance_fixtures.dart';

Future<void> main() async {
  if (!kDebugMode) throw StateError('UI preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  initTimeZones();
  final locale = await I18n.load();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        initialLocaleProvider.overrideWithValue(locale),
        sessionProvider.overrideWith(_PreviewSession.new),
        mentorClockProvider.overrideWithValue(() => previewNow),
        mentorAttendanceApiProvider.overrideWithValue(MemoryAttendanceRouter()),
        mentorSubstituteOnlyProvider.overrideWith((ref) async => false),
        mentorFavoritesProvider.overrideWith(_PreviewFavorites.new),
      ],
      child: const MentorPreviewApp(),
    ),
  );
}

class _PreviewSession extends SessionController {
  @override
  Future<void> logout() async {} // Preview không gọi auth/logout thật.
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

class _PreviewFavorites extends MentorFavoritesController {
  @override
  Future<List<MentorUtil>> build() async => const [];
  @override
  Future<String?> toggle(MentorUtil util) async {
    final (next, error) = toggleFavorite(state.value ?? const [], util);
    if (error == null) state = AsyncData(next);
    return error;
  }
}

enum PreviewScenario { data, empty, loading, error, noLink, disabled }

class MentorPreviewApp extends ConsumerStatefulWidget {
  const MentorPreviewApp({super.key});
  @override
  ConsumerState<MentorPreviewApp> createState() => _MentorPreviewAppState();
}

class _MentorPreviewAppState extends ConsumerState<MentorPreviewApp> {
  final _changes = ValueNotifier<int>(0);
  String _day = previewDay;
  PreviewScenario _scenario = PreviewScenario.data;
  var _notifications = sampleNotifications();
  bool _showNotice = true;
  double _scale = 1;

  late final _router = GoRouter(
    initialLocation: Routes.mentor,
    routes: [
      GoRoute(path: Routes.mentor, builder: (_, _) => _listen(_home)),
      GoRoute(
        path: Routes.mentorUtilities,
        builder: (_, _) => MentorUtilitiesScreen(
          onSessionUtility: (utility) {
            final entry = sampleSchedule().entries.first;
            if (utility == MentorUtil.room) {
              _room(entry);
            } else {
              _attendance(entry);
            }
          },
        ),
      ),
      GoRoute(
        path: Routes.mentorPagePath,
        builder: (_, state) => _listen(
          () => switch (state.pathParameters['key']) {
            'schedule' => _scheduleScreen(),
            'substitute' => _substituteScreen(),
            _ => MentorPlaceholderPage(utilKey: state.pathParameters['key']!),
          },
        ),
      ),
    ],
  );

  Widget _listen(Widget Function() builder) => ListenableBuilder(listenable: _changes, builder: (_, _) => builder());
  void _change(VoidCallback action) {
    action();
    _changes.value++;
    setState(() {});
  }

  AsyncValue<T> _value<T>(T data) => switch (_scenario) {
    PreviewScenario.loading => const AsyncLoading(),
    PreviewScenario.error => AsyncError(
      ApiError(status: 503, code: 'NETWORK_ERROR', message: 'Preview', requestId: 'preview-mf2'),
      StackTrace.current,
    ),
    _ => AsyncData(data),
  };
  AsyncValue<TeachingSchedule> get _schedule => _value(
    TeachingSchedule(
      timeZone: previewZone,
      entries: _scenario == PreviewScenario.empty ? [] : sampleSchedule().entries,
    ),
  );
  Future<void> _refresh() async => _change(() => _scenario = PreviewScenario.data);
  void _retry() => _change(() => _scenario = PreviewScenario.data);
  void _attendance(TeachingEntry entry) =>
      showMentorAttendance(_router.routerDelegate.navigatorKey.currentContext!, ref, entry);
  Future<void> _sampleLink(Uri _) async => showStaffToast(
    _router.routerDelegate.navigatorKey.currentContext!,
    ref.read(trProvider)('mentor.preview.sampleLink'),
  );

  Widget _home() {
    final t = ref.watch(trProvider);
    return MentorHomeScreen(
      teachingCard: MentorNextSessionCard(
        value: _schedule,
        now: previewNow,
        room: _value(sampleRoom(noLink: _scenario == PreviewScenario.noLink)),
        onRetry: _retry,
        onViewSchedule: () => _router.push(Routes.mentorPage('schedule')),
        onEnterRoom: _room,
      ),
      notificationButton: NotificationBell(
        count: _scenario == PreviewScenario.disabled ? 0 : _notifications.where((n) => n.readAt == null).length,
        label: t('mentor.notifications'),
        onPressed: _panel,
      ),
      substituteNotice: _showNotice && _scenario == PreviewScenario.data
          ? MentorSubstituteNotice(
              className: sampleSchedule().substitutes.first.className,
              onDismiss: () => _change(() => _showNotice = false),
              onOpen: () => _router.push(Routes.mentorPage('substitute')),
            )
          : null,
    );
  }

  Widget _scheduleScreen() => MentorScheduleScreen(
    value: _schedule,
    selectedDay: _day,
    now: previewNow,
    onDaySelected: (day) => _change(() => _day = day),
    onWeekChanged: (offset) => _change(() => _day = Dates.shiftDay(_day, offset * 7)),
    onRefresh: _refresh,
    onRetry: _retry,
    onRoom: _room,
    onAttendance: _attendance,
    onBack: () => _router.go(Routes.mentor),
  );

  Widget _substituteScreen() => MentorSubstituteScreen(
    value: _schedule,
    now: previewNow,
    onRefresh: _refresh,
    onRetry: _retry,
    onRoom: _room,
    onAttendance: _attendance,
    onBack: () => _router.go(Routes.mentor),
  );

  void _room(TeachingEntry entry) {
    final t = ref.read(trProvider);
    final context = _router.routerDelegate.navigatorKey.currentContext!;
    openStaffSheet(
      context,
      title: t('mentor.room.title'),
      subtitle: entry.className,
      builder: (_) => _listen(
        () => MentorRoomContent(
          value: _value(sampleRoom(noLink: _scenario == PreviewScenario.noLink, entry: entry)),
          onRetry: _retry,
          onOpen: _sampleLink,
        ),
      ),
    );
  }

  void _panel() {
    final t = ref.read(trProvider);
    openStaffSheet(
      _router.routerDelegate.navigatorKey.currentContext!,
      title: t('mentor.notifications'),
      builder: (_) => _listen(
        () => NotificationsPanel(
          value: _value(
            NotificationPage(
              items: _scenario == PreviewScenario.empty ? [] : _notifications,
              nextCursor: null,
              hasMore: false,
            ),
          ),
          timeZone: previewZone,
          disabled: _scenario == PreviewScenario.disabled,
          onRetry: _retry,
          onRead: (item) => _markRead(item.id),
          onReadAll: () => _markRead(null),
        ),
      ),
    );
  }

  Future<void> _markRead(String? id) async {
    // Chỉ mô phỏng response trễ trong preview; không chạm API hay cookie thật.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _change(
      () => _notifications = [
        for (final n in _notifications)
          MindyNotification(
            id: n.id,
            actorId: n.actorId,
            conversationId: n.conversationId,
            messageId: n.messageId,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            readAt: id == null || id == n.id ? previewNow : n.readAt,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return MaterialApp.router(
      title: 'Mindy UI preview',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
      locale: ref.watch(localeProvider),
      supportedLocales: I18n.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_scale)),
        child: Column(
          children: [
            Material(
              color: StaffColors.surface,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(t('mentor.preview.title'), style: StaffText.small),
                      const SizedBox(width: 8),
                      DropdownButton<PreviewScenario>(
                        value: _scenario,
                        items: [
                          for (final state in PreviewScenario.values)
                            DropdownMenuItem(value: state, child: Text(t('mentor.preview.${state.name}'))),
                        ],
                        onChanged: (value) {
                          if (value != null) _change(() => _scenario = value);
                        },
                      ),
                      TextButton(onPressed: () => _router.go(Routes.mentor), child: Text(t('mentor.preview.home'))),
                      TextButton(
                        onPressed: () => _router.go(Routes.mentorPage('schedule')),
                        child: Text(t('mentor.preview.schedule')),
                      ),
                      TextButton(
                        onPressed: () => _router.go(Routes.mentorPage('substitute')),
                        child: Text(t('mentor.preview.substitute')),
                      ),
                      TextButton(
                        onPressed: () => _room(sampleSchedule().entries.first),
                        child: Text(t('mentor.preview.room')),
                      ),
                      TextButton(onPressed: _panel, child: Text(t('mentor.preview.notifications'))),
                      TextButton(
                        onPressed: () => ref
                            .read(localeProvider.notifier)
                            .change(t.locale.languageCode == 'vi' ? const Locale('en') : const Locale('vi')),
                        child: Text(t.locale.languageCode.toUpperCase()),
                      ),
                      TextButton(
                        onPressed: () => _change(() => _scale = _scale == 1 ? 1.3 : 1),
                        child: Text('×$_scale'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: true, child: child!),
            ),
          ],
        ),
      ),
    );
  }
}
