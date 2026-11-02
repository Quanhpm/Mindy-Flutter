import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_screen.dart';
import 'package:mindy_flutter/features/mentor/classes/class_detail_screen.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/reports/attendance_report_screen.dart';
import 'package:mindy_flutter/features/mentor/students/students_screen.dart';
import 'package:mindy_flutter/features/mentor/students/student_detail_sheet.dart';
import '../tool/preview/classes_fixtures.dart';
import '../tool/mentor_preview.dart' as preview;
import 'mentor_mf2_test.dart' show pumpScreen;

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
  testWidgets('Entrypoint preview ghép MF2–MF4 không override trùng và mở được Lớp', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(preview.main);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('previewClasses')));
    await tester.tap(find.byKey(const ValueKey('previewClasses')));
    await tester.pumpAndSettle();
    expect(find.text('Giao tiếp B1 · Lớp 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  final screens = <String, Widget>{
    'classes': const MentorClassesScreen(),
    'detail': MentorClassDetailScreen(classId: fixtureClassId),
    'report': const MentorAttendanceReportScreen(),
    'students': const MentorStudentsScreen(),
  };
  for (final language in ['vi', 'en']) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} 320×640 chữ 1.3 $language', (tester) async {
        await pumpScreen(tester, entry.value, language: language, overrides: classesPreviewOverrides());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/mf4_${entry.key}_320_$language.png'));
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Lớp lọc trạng thái, lỗi từng thẻ không che lớp khác', (tester) async {
    await pumpScreen(tester, const MentorClassesScreen(), overrides: classesPreviewOverrides());
    await tester.pumpAndSettle();
    expect(find.text('Giao tiếp B1 · Lớp 7'), findsOneWidget);
    await tester.tap(find.text('Sắp mở (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Giao tiếp B1 · Lớp 8'), findsOneWidget);
  });
  testWidgets('Học viên tìm không dấu, lọc áp dụng, null không được gắn cần chú ý', (tester) async {
    await pumpScreen(tester, const MentorStudentsScreen(), height: 1000, overrides: classesPreviewOverrides());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dang');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Đặng Thùy Dương'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsNothing);
    await tester.ensureVisible(find.text('Tất cả'));
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dưới 80%'), findsOneWidget);
    await tester.tap(find.text('Đi học đều'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Không có học viên phù hợp'), findsOneWidget);
  });
  testWidgets('Chi tiết lớp readonly không mở lệnh điểm danh', (tester) async {
    await pumpScreen(
      tester,
      MentorClassDetailScreen(classId: fixtureClassId),
      height: 1200,
      overrides: [
        ...classesPreviewOverrides(includeDetail: false),
        mentorClassDetailProvider.overrideWith(
          (ref, id) async => sampleClassDetail(status: MentorClassStatus.COMPLETED),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Lớp chỉ đọc; các thao tác ghi đã được khóa.'), findsOneWidget);
    expect(find.text('Điểm danh'), findsNothing);
  });
  testWidgets('Chi tiết học viên hiển thị học bù và policy tiến độ chưa định nghĩa', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MentorStudentDetailContent(query: (classId: fixtureClassId, studentId: fixtureId(300))),
        ),
      ),
      overrides: classesPreviewOverrides(),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/mf4_student_detail_320_vi.png'));
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Đã ghi nhận kết quả học bù'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có quy tắc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final state in ['loading', 'empty', 'error']) {
    testWidgets('MF4 các màn có state $state và không overflow', (tester) async {
      final pending = Completer<Never>();
      for (final entry in screens.entries) {
        final List<Override> overrides = [...classesPreviewOverrides(includeClasses: false, includeDetail: false)];
        if (state == 'loading') {
          overrides.addAll([
            mentorPrimaryClassesProvider.overrideWith((ref) => pending.future),
            mentorClassDetailProvider.overrideWith((ref, id) => pending.future),
          ]);
        } else if (state == 'error') {
          overrides.addAll([
            mentorPrimaryClassesProvider.overrideWith((ref) async => throw ApiError.network()),
            mentorClassDetailProvider.overrideWith((ref, id) async => throw ApiError.network()),
          ]);
        } else {
          overrides.addAll([
            mentorPrimaryClassesProvider.overrideWith((ref) async => []),
            mentorClassDetailProvider.overrideWith(
              (ref, id) async => MentorClassDetail(
                overview: MentorClassOverview(workspace: sampleWorkspace(), sessions: [], enrollmentCount: 0),
                units: [],
                slots: [],
              ),
            ),
          ]);
        }
        await pumpScreen(tester, entry.value, overrides: overrides);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: entry.key);
        if (state == 'error') {
          expect(find.text('Thử lại'), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
