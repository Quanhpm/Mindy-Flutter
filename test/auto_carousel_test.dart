import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/ui/auto_carousel.dart';

Widget _carousel(ValueChanged<int> changed) => AutoCarousel(
  labels: const ['Go 1', 'Go 2', 'Go 3'],
  pauseLabel: 'Pause',
  resumeLabel: 'Resume',
  onChanged: changed,
  children: const [
    SizedBox(height: 100, child: Text('First')),
    SizedBox(height: 180, child: Text('Second')),
    SizedBox(height: 80, child: Text('Third')),
  ],
);

Future<void> _tick(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Dừng thủ công được giữ khi cuộn khỏi carousel rồi trở lại', (tester) async {
    final changed = <int>[];
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(controller: scroll, children: [_carousel(changed.add), const SizedBox(height: 2400)]),
        ),
      ),
    );
    await tester.tap(find.text('Pause'));
    await tester.pump();
    scroll.jumpTo(1600);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    scroll.jumpTo(0);
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(changed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
  });
  testWidgets('Tự chuyển 1→2→3→1; dispose không để timer', (tester) async {
    final changed = <int>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _carousel(changed.add))));
    await _tick(tester);
    expect(changed.last, 1);
    await _tick(tester);
    expect(changed.last, 2);
    await _tick(tester);
    expect(changed.last, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(changed, [1, 2, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App nền dừng, quay lại chạy tiếp; dừng thủ công được giữ', (tester) async {
    final changed = <int>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _carousel(changed.add))));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(changed, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _tick(tester);
    expect(changed.last, 1);
    await tester.tap(find.text('Pause'));
    await tester.pump(const Duration(seconds: 20));
    expect(changed, [1]);
    await tester.tap(find.text('Resume'));
    await _tick(tester);
    expect(changed.last, 2);
  });

  testWidgets('Trang bị che dừng autoplay và pop thì tiếp tục', (tester) async {
    final changed = <int>[];
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: _carousel(changed.add)),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Detail'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(changed, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await _tick(tester);
    expect(changed.last, 1);
  });

  testWidgets('Giảm chuyển động và screen reader không tự chuyển; chọn dot vẫn được', (tester) async {
    final semantics = tester.ensureSemantics();
    final changed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true, accessibleNavigation: true),
          child: Scaffold(body: _carousel(changed.add)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 20));
    expect(changed, isEmpty);
    expect(find.text('Pause'), findsNothing);
    expect(find.semantics.byLabel('First'), findsOneWidget);
    expect(find.semantics.byLabel('Second'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Go 2'));
    await tester.pumpAndSettle();
    expect(changed, [1]);
    expect(find.semantics.byLabel('Second'), findsOneWidget);
    expect(find.semantics.byLabel('First'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Giữ ngón tay khi vuốt không bị autoplay giành trang', (tester) async {
    final changed = <int>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _carousel(changed.add))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('First')));
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump(const Duration(seconds: 10));
    expect(changed, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    await _tick(tester);
    expect(changed, isNotEmpty);
  });
}
