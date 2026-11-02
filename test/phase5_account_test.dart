import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/features/account/account_screen.dart';

class _FakeSession extends SessionController {
  _FakeSession({this.mockUser});

  final SessionUser? mockUser;

  @override
  SessionState build() => SessionState(ready: true, user: mockUser, epoch: 1);

  @override
  Future<void> logout() async {
    state = const SessionState(ready: true, user: null, epoch: 2);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  final studentUser = SessionUser(
    id: 'usr_student_1',
    email: 'student@example.com',
    displayName: 'Nguyễn Văn An',
    phone: '0901234567',
    role: Role.STUDENT,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Widget buildSubject({SessionUser? user, Locale locale = const Locale('vi')}) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(mockUser: user)),
        initialLocaleProvider.overrideWithValue(locale),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const AccountScreen(),
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('AccountScreen renders hero and menu rows with exact testIDs', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject(user: studentUser));
    await tester.pumpAndSettle();

    // Screen shell
    expect(find.byKey(const Key('account-screen')), findsOneWidget);

    // Hero
    expect(find.byKey(const Key('account-profile-hero')), findsOneWidget);
    expect(find.text('VA'), findsOneWidget); // Initials of "Nguyễn Văn An"
    expect(find.byKey(const Key('account-avatar-camera')), findsOneWidget);
    expect(find.byKey(const Key('account-profile')), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);

    // Rows
    expect(find.byKey(const Key('account-orders')), findsOneWidget);
    expect(find.byKey(const Key('account-edit-profile')), findsOneWidget);
    expect(find.byKey(const Key('account-my-classes')), findsOneWidget);
    expect(find.byKey(const Key('account-certificates')), findsOneWidget);
    expect(find.byKey(const Key('account-attendance')), findsOneWidget);
    expect(find.byKey(const Key('account-push')), findsOneWidget);
    expect(find.byKey(const Key('account-push-switch')), findsOneWidget);
    expect(find.byKey(const Key('account-language')), findsOneWidget);
    expect(find.byKey(const Key('account-help')), findsOneWidget);
    expect(find.byKey(const Key('account-policy')), findsOneWidget);
    expect(find.byKey(const Key('account-logout')), findsOneWidget);
  });

  testWidgets('Profile sheet opens and displays all fields with close button', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject(user: studentUser));
    await tester.pumpAndSettle();

    // Tap profile name in hero
    await tester.tap(find.byKey(const Key('account-profile')));
    await tester.pumpAndSettle();

    // Profile sheet fields
    expect(find.byKey(const Key('account-profile-fields')), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsWidgets);
    expect(find.text('student@example.com'), findsWidgets);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Học viên'), findsOneWidget);

    // Close button
    expect(find.byKey(const Key('account-sheet-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-sheet-close')));
    await tester.pumpAndSettle();

    // Sheet dismissed
    expect(find.byKey(const Key('account-profile-fields')), findsNothing);
  });

  testWidgets('Language sheet opens and allows switching language', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject(user: studentUser));
    await tester.pumpAndSettle();

    // Scroll to language row if needed and tap
    await tester.scrollUntilVisible(find.byKey(const Key('account-language')), 100);
    await tester.tap(find.byKey(const Key('account-language')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-language-vi-VN')), findsOneWidget);
    expect(find.byKey(const Key('account-language-en-EN')), findsOneWidget);

    // Switch to English
    await tester.tap(find.byKey(const Key('account-language-en-EN')));
    await tester.pumpAndSettle();

    // Language sheet closed
    expect(find.byKey(const Key('account-language-en-EN')), findsNothing);
  });

  testWidgets('Logout sheet opens with confirm and cancel buttons', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject(user: studentUser));
    await tester.pumpAndSettle();

    // Scroll to logout row and tap
    await tester.scrollUntilVisible(find.byKey(const Key('account-logout')), 150);
    await tester.tap(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-logout-confirm')), findsOneWidget);
    expect(find.byKey(const Key('account-sheet-close')), findsOneWidget);

    // Cancel closes sheet
    await tester.tap(find.byKey(const Key('account-sheet-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-logout-confirm')), findsNothing);
  });

  testWidgets('Empty state renders when user is null', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject(user: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-empty')), findsOneWidget);
  });
}
