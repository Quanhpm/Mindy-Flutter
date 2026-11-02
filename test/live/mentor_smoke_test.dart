import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/config/env.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_controller.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/material_actions.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_controller.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';

/// Chỉ entrypoint local riêng này dùng socket thật trong Flutter test. Không đổi
/// HttpOverrides của app hoặc bộ test mặc định; không gọi server dev của owner.
class _LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Backend local: login → lịch hôm nay → bắt đầu → lưu điểm danh → chốt',
    () async {
      final base = Uri.parse(Env.apiUrl);
      expect(base.host, '127.0.0.1');
      expect(base.scheme, 'http');
      final password = Platform.environment['MINDY_UAT_PASSWORD'];
      final sessionId = Platform.environment['MINDY_UAT_SESSION_ID'];
      expect(password, isNotEmpty);
      expect(sessionId, isNotEmpty);
      SharedPreferences.setMockInitialValues({});
      initTimeZones();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['wifi'],
      );
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = ApiClient(cookieJar: CookieJar());
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [apiClientProvider.overrideWithValue(client)],
        );
        try {
          container.read(sessionProvider);
          for (var i = 0; i < 200 && !container.read(sessionProvider).ready; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
          expect(container.read(sessionProvider).ready, isTrue);
          await container.read(sessionProvider.notifier).login('mentor@http.test', password!);
          expect(container.read(sessionProvider).user?.role, Role.MENTOR);

          final scheduleSub = container.listen(mentorScheduleProvider(mentorHomeQuery).future, (_, _) {});
          final schedule = await scheduleSub.read();
          final entry = schedule.entries.singleWhere((entry) => entry.session.id == sessionId);
          expect(entry.session.displayStatus(DateTime.now()), TeachingDisplayStatus.live);
          final overviewSub = container.listen(mentorClassOverviewProvider(entry.session.classId).future, (_, _) {});
          final overview = await overviewSub.read();
          expect(overview.workspace.primary, isTrue);
          expect(overview.enrollmentCount, 1);

          final editorProvider = attendanceEditorProvider(sessionId!);
          final editorSub = container.listen(editorProvider.future, (_, _) {});
          await editorSub.read();
          final controller = container.read(editorProvider.notifier);
          expect(await controller.start(), isTrue, reason: '${container.read(editorProvider).value?.error}');
          final roster = container.read(editorProvider).requireValue.roster;
          expect(roster.records, hasLength(1));
          controller.setStatus(roster.records.single, AttendanceStatus.PRESENT);
          expect(await controller.save(), isTrue, reason: '${container.read(editorProvider).value?.error}');
          if (Platform.environment['MINDY_UAT_FILES'] == '1') {
            final file = File(Platform.environment['MINDY_UAT_FILE_PATH']!);
            final size = await file.length();
            final classId = entry.session.classId;
            final unitsSub = container.listen(mentorClassUnitsProvider(classId).future, (_, _) {});
            final unit = (await unitsSub.read()).single;
            final upload = mentorUploadProvider(classId);
            final uploadSub = container.listen(upload, (_, _) {});
            final uploaded = await container
                .read(upload.notifier)
                .start(
                  file: PickedUploadFile(
                    name: 'Mindy-live-smoke.pdf',
                    size: size,
                    mimeType: 'application/pdf',
                    openRead: file.openRead,
                  ),
                  unit: unit,
                  title: 'Mindy local live smoke',
                );
            expect(uploaded, isTrue, reason: '${container.read(upload).error}');
            final draft = container.read(upload).material!;
            expect(draft.reviewStatus, MaterialReviewStatus.DRAFT);
            expect(draft.file!.size, size);
            final materialApi = container.read(mentorMaterialsApiProvider);
            final access = await materialApi.access(classId, draft, draft.file!.id);
            final download = HttpClient();
            try {
              final response = await (await download.getUrl(access.url)).close();
              expect(response.statusCode, 200);
              expect(await response.fold<int>(0, (total, bytes) => total + bytes.length), size);
            } finally {
              download.close(force: true);
            }
            final actions = materialActionsProvider(classId);
            final actionsSub = container.listen(actions, (_, _) {});
            expect(
              await container.read(actions.notifier).submit([draft]),
              isTrue,
              reason: '${container.read(actions).error}',
            );
            expect(
              (await materialApi.detail(classId, draft.id)).material.reviewStatus,
              MaterialReviewStatus.PENDING_REVIEW,
            );
            actionsSub.close();
            uploadSub.close();
            unitsSub.close();
          }
          expect(await controller.finalize(), isTrue, reason: '${container.read(editorProvider).value?.error}');
          final finished = container.read(editorProvider).requireValue.roster;
          expect(finished.header.session.status, TeachingStatus.COMPLETED);
          expect(finished.header.totals.present, 1);
          expect(finished.header.totals.unmarked, 0);
          editorSub.close();
          overviewSub.close();
          scheduleSub.close();
          await container.read(sessionProvider.notifier).logout();
          expect(container.read(sessionProvider).user, isNull);
        } finally {
          if (Platform.environment['MINDY_UAT_FILES'] == '1') {
            container.read(uploadClientProvider).dio.close(force: true);
          }
          container.dispose();
          client.dio.close(force: true);
        }
      }, _LocalHttp());
    },
    skip: Platform.environment['MINDY_UAT_LIVE'] != '1'
        ? 'Chỉ chạy bằng tool/live/run_mentor_smoke.mjs với PostgreSQL riêng'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
