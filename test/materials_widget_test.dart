import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/network/file_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_screen.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_screen.dart';
import 'package:mindy_flutter/features/mentor/materials/material_reader.dart';
import 'package:mindy_flutter/features/mentor/materials/material_edit_sheet.dart';
import 'package:mindy_flutter/features/mentor/materials/material_actions.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/file_picker_service.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
import 'package:mindy_flutter/features/mentor/schedule/schedule_providers.dart';
import '../tool/preview/classes_fixtures.dart';
import '../tool/preview/materials_fixtures.dart';
import '../tool/preview/mentor_fixtures.dart';
import 'mentor_mf2_test.dart' show pumpScreen;

class _Epoch extends Notifier<int> {
  @override
  int build() => 1;
  void change() => state++;
}

final _epochProvider = NotifierProvider<_Epoch, int>(_Epoch.new);

class _Picker extends MentorFilePicker {
  @override
  Future<PickedUploadFile?> pick(UploadCategory category) async => PickedUploadFile(
    name: 'New lesson.pdf',
    size: 4,
    mimeType: 'application/pdf',
    openRead: () => Stream.value([1, 2, 3, 4]),
  );
}

List<Override> _overrides({MemoryMaterialsApi? api}) => [
  mentorPrimaryClassesProvider.overrideWith((ref) async => sampleClasses()),
  mentorClockProvider.overrideWithValue(() => previewNow),
  ...materialsPreviewOverrides(api: api),
  mentorFilePickerProvider.overrideWithValue(_Picker()),
  materialLauncherProvider.overrideWithValue((uri) async {}),
];
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
  final screens = <String, Widget>{
    'materials_classes': const MentorMaterialsScreen(),
    'upload_classes': const MentorUploadScreen(),
    'materials': MentorMaterialsScreen(classId: fixtureClassId),
    'upload': MentorUploadScreen(classId: fixtureClassId),
  };
  for (final lang in ['vi', 'en']) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} 320×640 chữ 1.3 $lang', (tester) async {
        await pumpScreen(tester, entry.value, language: lang, overrides: _overrides());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/mf5_${entry.key}_320_$lang.png'));
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Chọn file → tạo nháp, chưa tự gửi duyệt; lost response chỉ kiểm tra kết quả', (tester) async {
    final api = sampleMaterialsApi()..loseCreateResponse = true;
    await pumpScreen(
      tester,
      MentorUploadScreen(classId: fixtureClassId),
      height: 1000,
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chọn file'));
    await tester.tap(find.text('Chọn file'));
    await tester.pumpAndSettle();
    expect(find.text('New lesson.pdf'), findsWidgets);
    await tester.ensureVisible(find.text('Tải lên và tạo nháp'));
    await tester.tap(find.text('Tải lên và tạo nháp'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kiểm tra kết quả'));
    await tester.tap(find.text('Kiểm tra kết quả'));
    await tester.pumpAndSettle();
    expect(api.creates, 1);
    expect(api.commands, isEmpty);
    expect(api.rows.last.material.reviewStatus, MaterialReviewStatus.DRAFT);
    expect(find.text('Đã tạo bản nháp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Bài viết render HTML, không gọi access khi không có file chính', (tester) async {
    final api = sampleMaterialsApi(),
        article = api.rows.firstWhere((r) => r.material.type == MaterialContentType.ARTICLE && r.material.published);
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MaterialReaderContent(query: (classId: fixtureClassId, materialId: article.material.id)),
        ),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('My first trip abroad', findRichText: true), findsWidgets);
    expect(api.accesses, 0);
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('goldens/mf5_article_320_vi.png'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tên rỗng giữ form để sửa, chưa tạo intent hay khóa flow', (tester) async {
    final api = sampleMaterialsApi();
    await pumpScreen(
      tester,
      MentorUploadScreen(classId: fixtureClassId),
      height: 1000,
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.ensureVisible(find.text('Tải lên và tạo nháp'));
    await tester.tap(find.text('Tải lên và tạo nháp'));
    await tester.pumpAndSettle();
    expect(api.creates, 0);
    expect(find.text('Tên tài liệu cần từ 1–250 ký tự; mô tả tối đa 5.000 ký tự.'), findsOneWidget);
    expect(find.text('Tải lên và tạo nháp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Mỗi lần mở file xin URL ký mới, không dùng URL của lần trước', (tester) async {
    final api = sampleMaterialsApi(), material = api.rows.first.material;
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MaterialReaderContent(query: (classId: fixtureClassId, materialId: material.id)),
        ),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở file'));
    await tester.pumpAndSettle();
    expect(api.accesses, 2);
    expect(find.textContaining('storage.example.test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Đã duyệt nhưng chưa published không hiện nút mở binary', (tester) async {
    final api = sampleMaterialsApi(), m = api.rows.last.material;
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: MaterialReaderContent(query: (classId: fixtureClassId, materialId: m.id))),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mở file'), findsNothing);
    expect(find.textContaining('Chưa thể xem file này'), findsOneWidget);
    expect(api.accesses, 0);
  });
  testWidgets('Ảnh inline lỗi có nút lấy link mới, không hiển thị URL ký', (tester) async {
    final api = sampleMaterialsApi(), base = api.rows[2];
    final image = BinaryFileSummary(
      id: fixtureId(950),
      name: 'photo.png',
      mimeType: 'image/png',
      size: 4,
      kind: FileKind.IMAGE,
    );
    api.rows[2] = MentorMaterialDetail(
      material: base.material,
      html: '<p>Ảnh bài học</p><img data-file-id="${image.id}" alt="Ảnh minh họa">',
      inlineImages: [image],
      attachments: [],
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MaterialReaderContent(query: (classId: fixtureClassId, materialId: base.material.id)),
        ),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    expect(api.accesses, 1);
    expect(find.text('Tải lại hình ảnh'), findsOneWidget);
    await tester.tap(find.text('Tải lại hình ảnh'));
    await tester.pumpAndSettle();
    expect(api.accesses, 2);
    expect(find.textContaining('storage.example.test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Gửi lô có xác nhận, chỉ gửi các DRAFT; bản bị từ chối giữ nguyên', (tester) async {
    final api = sampleMaterialsApi();
    await pumpScreen(
      tester,
      MentorUploadScreen(classId: fixtureClassId),
      height: 1000,
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi duyệt 2 bản nháp'));
    await tester.tap(find.text('Gửi duyệt 2 bản nháp'));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    await tester.tap(find.descendant(of: find.byType(BottomSheet).last, matching: find.text('Gửi duyệt')));
    await tester.pumpAndSettle();
    expect(api.commands.map((c) => c.kind), ['submit', 'submit']);
    expect(api.rows.where((r) => r.material.reviewStatus == MaterialReviewStatus.REJECTED), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Deep link lớp đã kết thúc chỉ đọc, không có picker và lệnh ghi', (tester) async {
    final api = sampleMaterialsApi();
    await pumpScreen(
      tester,
      MentorUploadScreen(classId: fixtureId(12)),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lớp chỉ đọc; các thao tác ghi đã được khóa.'), findsOneWidget);
    expect(find.text('Chọn file'), findsNothing);
    expect(find.text('Gửi duyệt'), findsNothing);
  });
  testWidgets('Sửa bản bị từ chối lưu DRAFT, đóng sheet sau xác nhận, không tự submit', (tester) async {
    final api = sampleMaterialsApi(),
        m = api.rows.firstWhere((r) => r.material.reviewStatus == MaterialReviewStatus.REJECTED).material;
    await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (ctx, ref, _) => TextButton(
            onPressed: () => showMaterialEditor(ctx, ref, fixtureClassId, m),
            child: const Text('Edit fixture'),
          ),
        ),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fixture'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Đã bổ sung đáp án');
    await tester.pump();
    await tester.ensureVisible(find.text('Lưu nháp'));
    await tester.tap(find.text('Lưu nháp'));
    await tester.pumpAndSettle();
    expect(api.commands.map((c) => c.kind), ['edit']);
    final result = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
      listen: false,
    ).read(materialActionsProvider(fixtureClassId));
    expect(result.error, isNull, reason: '${result.error}; busy=${result.busy}, changed=${result.changed}');
    expect(api.rows.singleWhere((r) => r.material.id == m.id).material.reviewStatus, MaterialReviewStatus.DRAFT);
    expect(find.byType(MaterialEditContent), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Đổi phiên khi có sheet xác nhận bỏ nháp đóng cả hai modal', (tester) async {
    final api = sampleMaterialsApi(), m = api.rows[2].material;
    await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (ctx, ref, _) => TextButton(
            onPressed: () => showMaterialEditor(ctx, ref, fixtureClassId, m),
            child: const Text('Edit fixture'),
          ),
        ),
      ),
      overrides: [
        ..._overrides(api: api),
        sessionEpochProvider.overrideWith((ref) => ref.watch(_epochProvider)),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fixture'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chưa lưu');
    await tester.pump();
    await Navigator.of(tester.element(find.byType(MaterialEditContent))).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    final scope = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first), listen: false);
    scope.read(_epochProvider.notifier).change();
    await tester.pumpAndSettle();
    expect(find.byType(MaterialEditContent), findsNothing);
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsNothing);
    expect(api.commands, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('409 giữ text đang sửa, cho xem phiên bản mới trước khi dùng revision mới', (tester) async {
    final api = sampleMaterialsApi(), old = api.rows.first;
    api.rows[0] = MentorMaterialDetail(
      material: copyPreviewMaterial(old.material, title: 'Tên từ thiết bị khác', revision: 2),
      html: old.html,
      inlineImages: old.inlineImages,
      attachments: old.attachments,
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (ctx, ref, _) => TextButton(
            onPressed: () => showMaterialEditor(ctx, ref, fixtureClassId, old.material),
            child: const Text('Edit fixture'),
          ),
        ),
      ),
      overrides: _overrides(api: api),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fixture'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Thay đổi đang nhập');
    await tester.pump();
    await tester.ensureVisible(find.text('Lưu nháp'));
    await tester.tap(find.text('Lưu nháp'));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(1));
    await tester.ensureVisible(find.text('Xem phiên bản mới'));
    await tester.tap(find.text('Xem phiên bản mới'));
    await tester.pumpAndSettle();
    expect(find.text('Tên từ thiết bị khác'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, 'Thay đổi đang nhập');
    await expectLater(find.byType(BottomSheet).last, matchesGoldenFile('goldens/mf5_edit_conflict_320_vi.png'));
    await tester.ensureVisible(find.text('Tôi đã xem, tiếp tục sửa'));
    await tester.tap(find.text('Tôi đã xem, tiếp tục sửa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu nháp'));
    await tester.tap(find.text('Lưu nháp'));
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.revision, 2);
    expect(api.rows.first.material.revision, 3);
    expect(find.byType(MaterialEditContent), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final scenario in ['loading', 'error', 'empty']) {
    testWidgets('Tài liệu/upload có state $scenario và không overflow', (tester) async {
      for (final upload in [false, true]) {
        final pending = Completer<MentorMaterials>();
        final overrides = [
          ..._overrides(),
          mentorMaterialsProvider.overrideWith((ref, id) {
            if (scenario == 'loading') {
              return pending.future;
            }
            if (scenario == 'error') {
              throw ApiError.network();
            }
            return Future.value(MentorMaterials(workspace: sampleWorkspace(), groups: []));
          }),
        ];
        await pumpScreen(
          tester,
          upload ? MentorUploadScreen(classId: fixtureClassId) : MentorMaterialsScreen(classId: fixtureClassId),
          overrides: overrides,
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        if (scenario == 'error') {
          expect(find.text('Thử lại'), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
