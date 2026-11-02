import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/operations/leave_screens.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_models.dart';
import 'package:mindy_flutter/features/mentor/operations/operations_providers.dart';
import 'package:mindy_flutter/features/mentor/operations/session_edit_screens.dart';
import 'package:mindy_flutter/features/mentor/session/session_context_api.dart';
import 'preview/operations_fixtures.dart';

/// Fixture debug, không bootstrap user, không cookie lưu, chặn toàn bộ HTTP.
class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, epoch: 1);
}

class _NoNetwork implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) =>
      Future.error(DioException(requestOptions: options, type: DioExceptionType.cancel));
  @override
  void close({bool force = false}) {}
}

Future<void> main() async {
  if (!const bool.fromEnvironment('dart.vm.product')) {
    WidgetsFlutterBinding.ensureInitialized();
    initTimeZones();
    final locale = await I18n.load();
    final client = ApiClient(cookieJar: CookieJar())..dio.httpClientAdapter = _NoNetwork();
    runApp(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          initialLocaleProvider.overrideWithValue(locale),
          sessionProvider.overrideWith(_Session.new),
          apiClientProvider.overrideWithValue(client),
          mentorClassesProvider.overrideWith((_) async => []),
          mentorLeavesProvider.overrideWith((_, status) async => [operationRequest()]),
          mentorLeaveDetailProvider.overrideWith((_, id) async {
            final request = operationRequest();
            return LeaveDetail(request, request.items);
          }),
          mentorNoteProvider.overrideWith(
            (_, id) async => TeachingNote(id, 1, 'Nội dung buổi học tổng hợp.', 'Ôn lại nội dung đã học.'),
          ),
          mentorRoomProvider.overrideWith((_, id) async => operationRoom()),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const _Menu()),
              GoRoute(path: Routes.mentorPage('leave'), builder: (_, _) => const MentorLeaveScreen()),
              GoRoute(path: Routes.mentorLeaveCreate, builder: (_, _) => const MentorLeaveCreateScreen()),
              GoRoute(
                path: Routes.mentorLeaveDetailPath,
                builder: (_, st) => MentorLeaveDetailScreen(requestId: st.pathParameters['requestId']!),
              ),
              GoRoute(
                path: Routes.mentorNotesPath,
                builder: (_, st) => MentorNotesScreen(sessionId: st.pathParameters['sessionId']!),
              ),
              GoRoute(
                path: Routes.mentorMeetingPath,
                builder: (_, st) => MentorMeetingScreen(sessionId: st.pathParameters['sessionId']!),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    throw StateError('Debug preview only');
  }
}

class _Menu extends StatelessWidget {
  const _Menu();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MF7 · dữ liệu tổng hợp')),
    body: ListView(
      children: [
        for (final entry in <String, String>{
          'Nghỉ dạy': Routes.mentorPage('leave'),
          'Tạo đơn': Routes.mentorLeaveCreate,
          'Chi tiết đơn': Routes.mentorLeaveDetail(operationRequestId),
          'Ghi chú': Routes.mentorNotes(operationSessionId),
          'Link phòng': Routes.mentorMeeting(operationSessionId),
        }.entries)
          ListTile(title: Text(entry.key), onTap: () => context.push(entry.value)),
      ],
    ),
  );
}
