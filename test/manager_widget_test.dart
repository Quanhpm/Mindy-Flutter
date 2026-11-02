import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/app/router.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/ui/mdy/mdy.dart';
import 'package:mindy_flutter/core/ui/staff/staff_widgets.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/preview/manager_fixtures.dart';

Future<void> flushManager(WidgetTester tester) async {
  // Real asynchronous Dio adapter/microtasks, with no network or fake-clock timers.
  for (var n = 0; n < 4; n++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<({ProviderContainer scope, ManagerFixtureAdapter wire})> pumpManager(
  WidgetTester tester,
  String path, {
  String language = 'vi',
  ManagerFixtureAdapter? adapter,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final wire = adapter ?? ManagerFixtureAdapter(),
      client = managerFixtureClient(wire);
  final scope = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      apiClientProvider.overrideWithValue(client),
      sessionProvider.overrideWith(ManagerFixtureSession.new),
      initialLocaleProvider.overrideWithValue(Locale(language)),
    ],
  );
  addTearDown(() => {scope.dispose(), client.dio.close(force: true)});
  final router = scope.read(routerProvider);
  router.go(path);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: RepaintBoundary(
        key: const ValueKey('manager-capture'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: router,
          locale: Locale(language),
          supportedLocales: I18n.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await flushManager(tester);
  return (scope: scope, wire: wire);
}

Finder button(String text) => find.byWidgetPredicate(
  (w) =>
      (w is StaffButton && w.label == text) ||
      (w is MdyButton && w.label == text),
  description: 'button "$text"',
);
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await flushManager(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    initTimeZones();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
    for (final entry in {
      'Nunito': [
        'Nunito-Regular.ttf',
        'Nunito-SemiBold.ttf',
        'Nunito-Bold.ttf',
        'Nunito-ExtraBold.ttf',
      ],
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
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });
  final pages = <String, ({String path, bool golden})>{
    'home': (path: Routes.manager, golden: true),
    'utilities': (path: Routes.managerUtilities, golden: false),
    'leaves': (path: Routes.managerLeaves, golden: false),
    'leave': (path: Routes.managerLeave(mgLeave), golden: true),
    'materials': (path: Routes.managerMaterials, golden: true),
    'material': (path: Routes.managerMaterial(mgMaterial), golden: true),
    'editor': (path: Routes.managerMaterialEdit(mgDraft), golden: true),
    'new': (path: '${Routes.managerMaterialNew}?unitId=$mgUnit', golden: false),
    'collections': (path: Routes.managerCollections, golden: false),
    'cash': (path: Routes.managerOrder(mgOrder), golden: true),
    'classes': (path: Routes.managerClasses, golden: false),
    'class': (path: Routes.managerClass(mgClass), golden: false),
    'mentors': (path: Routes.managerPeople('MENTOR'), golden: false),
    'student': (
      path: Routes.managerPerson('STUDENT', mgStudent),
      golden: false,
    ),
    'mentor': (path: Routes.managerPerson('MENTOR', mgMentor), golden: false),
    'incomplete': (path: Routes.managerIncomplete, golden: false),
    'report': (path: '${Routes.managerReports}?classId=$mgClass', golden: true),
    'audits': (path: Routes.managerAudit(mgSession), golden: false),
    'makeup': (
      path: '${Routes.managerMakeupDetail(mgConflict)}?classId=$mgClass',
      golden: true,
    ),
  };
  for (final language in ['vi', 'en']) {
    for (final entry in pages.entries) {
      testWidgets(
        'Manager ${entry.key} 320 text1.3 $language real router/API',
        (tester) async {
          final s = await pumpManager(
            tester,
            entry.value.path,
            language: language,
          );
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Không thể tải'), findsNothing);
          expect(find.textContaining('Could not load'), findsNothing);
          expect(
            s.wire.requests.where(
              (r) => r.path.startsWith('mentor/') || r.path.startsWith('me/'),
            ),
            isEmpty,
          );
          if (entry.value.golden) {
            await expectLater(
              find.byKey(const ValueKey('manager-capture')),
              matchesGoldenFile(
                'goldens/manager_${entry.key}_320_$language.png',
              ),
            );
          }
          // Lower content and actions must also lay out without overflow.
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isNotEmpty) {
            await tester.drag(scrolls.first, const Offset(0, -1100));
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
  testWidgets(
    'Leave approval stays blocked while student schedule conflicts remain',
    (tester) async {
      final s = await pumpManager(tester, Routes.managerLeave(mgLeave));
      final approve = find.byKey(const Key('leave-review-approve'));
      expect(approve, findsOneWidget);
      expect(tester.widget<MdyButton>(approve).disabled, isTrue);
      expect(
        find.byKey(const Key('leave-review-conflict-block')),
        findsOneWidget,
      );
      expect(s.wire.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'CASH confirm checks entered full amount, explicit receipt and updates paid UI',
    (tester) async {
      final s = await pumpManager(tester, Routes.managerOrder(mgOrder));
      final t = s.scope.read(trProvider);
      await tapVisible(tester, button(t('manager.cashConfirm')));
      await tester.enterText(find.byType(TextField).last, '999999');
      await tester.pump();
      await tapVisible(tester, find.byType(CheckboxListTile));
      expect(
        tester.widget<StaffButton>(button(t('manager.confirm'))).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).last, '1000000');
      await tester.pump();
      await tapVisible(tester, button(t('manager.confirm')));
      expect(s.wire.cashPaid, true);
      expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Material edit preserves canonical HTML and sends expectedRevision',
    (tester) async {
      final s = await pumpManager(tester, Routes.managerMaterialEdit(mgDraft)),
          t = s.scope.read(trProvider);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller?.text)
            .any((v) => v?.contains('<strong>') ?? false),
        true,
      );
      await tester.enterText(find.byType(TextField).first, 'Bản sửa Manager');
      await tapVisible(tester, button(t('manager.saveDraft')));
      expect(s.wire.materials[mgDraft]!['revision'], 2);
      final write = s.wire.requests.singleWhere((r) => r.method == 'PATCH');
      expect((write.body! as Map)['contentHtml'], contains('<strong>'));
      expect((write.body! as Map)['expectedRevision'], 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Account change closes confirmation sheet before any mutation', (
    tester,
  ) async {
    final s = await pumpManager(tester, Routes.managerOrder(mgOrder)),
        t = s.scope.read(trProvider);
    await tapVisible(tester, button(t('manager.cashConfirm')));
    (s.scope.read(sessionProvider.notifier) as ManagerFixtureSession).change();
    await flushManager(tester);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(s.wire.requests.where((r) => r.method == 'POST'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Assign primary mentor uses server candidate and version after confirmation',
    (tester) async {
      final s = await pumpManager(tester, Routes.managerClass(mgClass)),
          t = s.scope.read(trProvider);
      await tapVisible(tester, button(t('manager.assignPrimary')));
      await tapVisible(tester, find.byType(DropdownButton<String>).last);
      await tapVisible(tester, find.text('Giảng viên thay thế').last);
      await tapVisible(tester, button(t('manager.assignMentor')));
      await tester.enterText(find.byType(TextField).last, 'Đổi lịch phân công');
      await tapVisible(tester, button(t('manager.confirm')));
      final write = s.wire.requests.singleWhere((r) => r.method == 'PATCH');
      expect((write.body! as Map)['expectedVersion'], 3);
      expect((write.body! as Map)['mentorId'], mgId(20));
      expect(write.headers['Idempotency-Key'], isNotEmpty);
      expect(s.wire.classVersion, 4);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Makeup placement requires equivalence checkbox, then cancel uses placement version',
    (tester) async {
      final s = await pumpManager(
        tester,
        '${Routes.managerMakeupDetail(mgConflict)}?classId=$mgClass',
      );
      await tapVisible(
        tester,
        find.byKey(Key('makeup-placement-candidate-$mgTarget')),
      );
      await tester.enterText(
        find.byType(TextField).last,
        'Đã đối chiếu nội dung',
      );
      await tester.pump();
      expect(
        tester
            .widget<MdyButton>(find.byKey(const Key('makeup-placement-submit')))
            .disabled,
        isTrue,
      );
      await tapVisible(
        tester,
        find.byKey(const Key('makeup-placement-content-check')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('makeup-placement-submit')),
      );
      expect(s.wire.conflictStatus, 'MAKEUP_ASSIGNED');
      await tapVisible(
        tester,
        find.byKey(const Key('makeup-placement-cancel')),
      );
      await tester.enterText(find.byType(TextField).last, 'Đổi sang lịch khác');
      await tapVisible(
        tester,
        find.byKey(const Key('makeup-placement-cancel-send')),
      );
      expect(s.wire.conflictStatus, 'OPEN');
      final writes = s.wire.requests.where((r) => r.method == 'POST').toList();
      expect(writes.length, 2);
      expect((writes[0].body! as Map)['contentMatchConfirmed'], true);
      expect((writes[1].body! as Map)['expectedVersion'], 1);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );
  testWidgets('Material review approval publishes the displayed revision', (
    tester,
  ) async {
    final s = await pumpManager(tester, Routes.managerMaterial(mgMaterial));
    await tapVisible(tester, find.byKey(const Key('review-detail-approve')));
    await tapVisible(tester, find.byKey(const Key('approve-confirm')));
    expect(s.wire.materials[mgMaterial]!['reviewStatus'], 'APPROVED');
    expect(s.wire.materials[mgMaterial]!['publishedAt'], isNotNull);
    expect(s.wire.requests.where((r) => r.method == 'POST').length, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
