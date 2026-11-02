import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/theme/app_theme.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/payment/payment_api.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';
import 'package:mindy_flutter/features/payment/payment_result_ticket.dart';
import 'package:mindy_flutter/features/payment/payment_screen.dart';

class _FakePaymentApi implements PaymentApi {
  _FakePaymentApi(this.fakeOrder, this.fakePayment);

  final Order fakeOrder;
  final Payment fakePayment;

  @override
  Future<Order> order(String orderId, {CancelToken? cancel, Duration? timeout}) async => fakeOrder;

  @override
  Future<Payment> createPayos(String orderId, {CancelToken? cancel, Duration? timeout}) async => fakePayment;

  @override
  Future<Order?> findPendingPayosOrder(List<String> classIds) async => fakeOrder;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await I18n.load();
  });

  final now = DateTime.now();

  final mockOrder = Order(
    id: 'ord-123',
    orderCode: 'MINDY20261102001',
    paymentType: PaymentType.PAYOS,
    status: OrderStatus.PENDING,
    totalAmount: 3500000,
    expiresAt: now.add(const Duration(minutes: 15)),
    details: const [
      (classId: 'cls-1', courseTitle: 'Flutter Foundation'),
      (classId: 'cls-2', courseTitle: 'React Native Masterclass'),
    ],
  );

  final mockPayment = Payment(
    status: PaymentStatus.PENDING,
    qrCode: '00020101021238540010A00000072701260006970422011201234567895303704540735000005802VN6304ABCD',
    expiresAt: now.add(const Duration(minutes: 15)),
    amount: 3500000,
  );

  Widget buildSubject({
    Order? order,
    Payment? payment,
  }) {
    final ord = order ?? mockOrder;
    final pay = payment ?? mockPayment;

    return ProviderScope(
      overrides: [
        paymentApiProvider.overrideWithValue(_FakePaymentApi(ord, pay)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: PaymentScreen(orderId: ord.id),
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

  testWidgets('PaymentScreen renders header, amount, countdown, QR and transfer info', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Screen shell & header
    expect(find.byKey(const Key('payment-screen')), findsOneWidget);
    expect(find.byKey(const Key('payment-back')), findsOneWidget);
    expect(find.byKey(const Key('payment-amount')), findsOneWidget);
    expect(find.text(formatVnd(3500000)), findsWidgets);

    // Countdown pill
    expect(find.byKey(const Key('payment-expiry')), findsOneWidget);

    // QR box
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);

    // Transfer info box and rows
    expect(find.byKey(const Key('payment-info')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-courses')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-bank')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-account')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-owner')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-amount')), findsOneWidget);
    expect(find.byKey(const Key('payment-info-row-note')), findsOneWidget);

    // Copy buttons
    expect(find.byKey(const Key('payment-copy-account')), findsOneWidget);
    expect(find.byKey(const Key('payment-copy-note')), findsOneWidget);

    // Note
    expect(find.byKey(const Key('payment-note'), skipOffstage: false), findsOneWidget);
  });

  testWidgets('Tapping copy button shows toast', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap copy account
    await tester.tap(find.byKey(const Key('payment-copy-account')));
    await tester.pump();

    // Toast visible
    expect(find.byKey(const Key('payment-toast')), findsOneWidget);
    expect(find.textContaining('số tài khoản'), findsOneWidget);
  });

  testWidgets('Tapping back button shows leave confirmation sheet', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap back button
    await tester.tap(find.byKey(const Key('payment-back')));
    await tester.pumpAndSettle();

    // Leave sheet elements
    expect(find.byKey(const Key('payment-leave-stay')), findsOneWidget);
    expect(find.byKey(const Key('payment-leave-confirm')), findsOneWidget);

    // Tap stay button
    await tester.tap(find.byKey(const Key('payment-leave-stay')));
    await tester.pumpAndSettle();

    // Sheet closed, still on payment screen
    expect(find.byKey(const Key('payment-screen')), findsOneWidget);
    expect(find.byKey(const Key('payment-leave-stay')), findsNothing);
  });

  testWidgets('PaymentResultTicket renders success and retry variants', (tester) async {
    configureViewport(tester);

    // Test PAID result
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: PaymentResultTicket(
            status: OrderStatus.PAID,
            orderCode: 'MINDY20261102001',
            amount: 3500000,
            onHome: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('payment-result-surface')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-ticket')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-title')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-description')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-order')), findsOneWidget);
    expect(find.text('MINDY20261102001'), findsOneWidget);
    expect(find.byKey(const Key('payment-result-home')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-retry')), findsNothing);

    // Test EXPIRED result
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: PaymentResultTicket(
            status: OrderStatus.EXPIRED,
            orderCode: 'MINDY20261102001',
            amount: 3500000,
            onHome: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('payment-result-retry')), findsOneWidget);
    expect(find.byKey(const Key('payment-result-home')), findsNothing);
  });
}
