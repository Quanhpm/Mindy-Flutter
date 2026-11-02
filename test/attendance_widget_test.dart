import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_api.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_models.dart';
import 'package:mindy_flutter/features/mentor/attendance/attendance_sheet.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_models.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/preview/attendance_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';
import 'mentor_mf2_test.dart' show pumpScreen;

class _ReadStateApi extends MemoryAttendanceApi {
  _ReadStateApi(this.loading);
  final bool loading;
  final pending = Completer<AttendanceRoster>();
  @override
  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) async {
    if (loading) return pending.future;
    throw ApiError.network();
  }
}

class _GoneApi extends MemoryAttendanceApi {
  @override
  Future<AttendanceRoster> roster(String id, {CancelToken? cancel}) async =>
      throw ApiError(status: 404, code: 'CLASS_SESSION_NOT_FOUND');
}

Future<void> pumpAttendance(WidgetTester tester, MemoryAttendanceApi api, {String language = 'vi', Widget? child}) =>
    pumpScreen(
      tester,
      child ??
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AttendanceSheetContent(sessionId: sampleSchedule().entries.first.session.id),
            ),
          ),
      language: language,
      overrides: [
        mentorClockProvider.overrideWithValue(() => previewNow),
        mentorAttendanceApiProvider.overrideWithValue(api),
      ],
    );

void main() {
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
  for (final language in ['vi', 'en']) {
    for (final status in [TeachingStatus.SCHEDULED, TeachingStatus.IN_PROGRESS, TeachingStatus.COMPLETED]) {
      testWidgets('Điểm danh ${status.name}, 320×640 chữ ×1,3, $language', (tester) async {
        await pumpAttendance(tester, MemoryAttendanceApi(studentCount: 4, status: status), language: language);
        expect(tester.takeException(), isNull);
        if (language == 'vi' && status == TeachingStatus.IN_PROGRESS) {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile('goldens/mf3_attendance_320_vi.png'),
          );
        }
        if (language == 'vi' && status == TeachingStatus.SCHEDULED) {
          expect(find.text('Bắt đầu buổi'), findsOneWidget);
          await tester.tap(find.text('Bắt đầu buổi'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('Hết hạn không có nút ghi, loading và lỗi có nội dung đúng', (tester) async {
    await pumpAttendance(tester, MemoryAttendanceApi(studentCount: 2, expired: true));
    expect(find.text('Lưu điểm danh'), findsNothing);
    await pumpAttendance(tester, _ReadStateApi(true));
    expect(find.text('Lưu điểm danh'), findsNothing);
    await pumpAttendance(tester, _ReadStateApi(false));
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Chạm học viên, lưu thật qua controller rồi mới báo thành công', (tester) async {
    final api = MemoryAttendanceApi(studentCount: 2);
    await pumpAttendance(tester, api);
    await tester.tap(find.text('Học viên mẫu 1'));
    await tester.pump();
    expect(find.text('1 thay đổi chưa lưu'), findsOneWidget);
    await tester.ensureVisible(find.text('Lưu điểm danh'));
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu điểm danh'), findsOneWidget);
    final roster = await api.roster(sampleSchedule().entries.first.session.id);
    expect(roster.records.first.status, AttendanceStatus.PRESENT);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Rời sheet có bản nháp thì hỏi, chọn tiếp tục không làm mất dữ liệu', (tester) async {
    final api = MemoryAttendanceApi(studentCount: 2);
    await pumpAttendance(
      tester,
      api,
      child: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            return TextButton(
              onPressed: () => showMentorAttendance(context, ref, sampleSchedule().entries.first),
              child: const Text('Mở điểm danh'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Mở điểm danh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học viên mẫu 1'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Rời điểm danh?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục điểm danh'));
    await tester.pumpAndSettle();
    expect(find.text('1 thay đổi chưa lưu'), findsOneWidget);
    expect(api.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Sheet xác nhận chốt hiển thị tổng server và cảnh báo UNMARKED', (tester) async {
    final api = MemoryAttendanceApi(studentCount: 2);
    await pumpAttendance(tester, api);
    await tester.ensureVisible(find.text('Chốt buổi học'));
    await tester.tap(find.text('Chốt buổi học'));
    await tester.pumpAndSettle();
    expect(find.text('2 lượt chưa điểm danh sẽ được tính vắng khi chốt.'), findsOneWidget);
    await tester.tap(find.text('Xác nhận chốt buổi'));
    await tester.pumpAndSettle();
    expect(
      (await api.roster(sampleSchedule().entries.first.session.id)).header.session.status,
      TeachingStatus.COMPLETED,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('404 buổi không còn tồn tại thì đóng sheet về lịch', (tester) async {
    await pumpAttendance(
      tester,
      _GoneApi(),
      child: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showMentorAttendance(context, ref, sampleSchedule().entries.first),
            child: const Text('Mở điểm danh'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở điểm danh'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceSheetContent), findsNothing);
    expect(find.text('Mở điểm danh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
