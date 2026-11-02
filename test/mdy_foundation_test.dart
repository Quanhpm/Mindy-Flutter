import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/ui/mdy/mdy.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(Widget child, {MdyThemeChoice theme = MdyThemeChoice.light}) =>
    ProviderScope(
      overrides: [initialMdyThemeProvider.overrideWithValue(theme)],
      child: MaterialApp(
        builder: (context, c) => MdyTheme(child: MdyToastHost(child: c!)),
        home: child,
      ),
    );

class _Gallery extends StatelessWidget {
  const _Gallery({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MdyScreen(
    app: true,
    children: [
      MdyBrandHeader(
        child: Text(
          'header',
          style: MdyType.title.copyWith(color: context.mdy.onBrand),
        ),
      ),
      MdyCard(
        overlap: true,
        children: [
          MdyButton(
            key: const Key('overlap-button'),
            label: 'Overlap',
            onPressed: onTap,
          ),
          const MdyAlert('Lỗi'),
          const MdyAlert('Cảnh báo', warning: true),
          const MdyChip('Đang dạy', variant: MdyChipVariant.success),
          const MdyAvatar(name: 'Trần Thị Linh'),
          const MdyCircleIcon(MdyIcons.school),
          MdyRow(
            label: 'Hàng',
            subtitle: 'phụ',
            icon: MdyIcons.settings,
            onPress: onTap,
          ),
          MdyRow(
            label: 'Radio',
            icon: MdyIcons.translate,
            checked: true,
            onPress: () {},
          ),
          const MdyTextField(
            label: 'Email',
            icon: MdyIcons.mail,
            fieldId: 'email',
            error: 'Sai email',
          ),
          MdyButton(
            label: 'Phụ',
            variant: MdyButtonVariant.secondary,
            onPressed: onTap,
          ),
          MdyButton(label: 'Đang gửi', busy: true, onPressed: onTap),
          const MdyButton(label: 'Khoá', onPressed: null),
          Row(
            children: [
              for (final v in MdyThemeChoice.values)
                Expanded(
                  child: MdyThemeCard(
                    value: v,
                    label: v.name,
                    checked: v == MdyThemeChoice.light,
                    onPress: () {},
                  ),
                ),
            ],
          ),
          Wrap(
            children: [
              MdyHomeTile(
                label: 'Lớp',
                icon: MdyIcons.coPresent,
                compact: true,
                badge: 120,
                onPress: onTap,
              ),
              MdyHomeTile(
                label: 'Lịch',
                icon: MdyIcons.calendarMonth,
                featured: true,
                compact: true,
                onPress: onTap,
              ),
            ],
          ),
          const MdySkeleton(label: 'Đang tải', child: SizedBox(height: 40)),
        ],
      ),
      const MdyCard(
        skeletonLabel: 'Đang kiểm tra',
        children: [SizedBox(height: 300)],
      ),
    ],
  );
}

void main() {
  test('Palette có đủ màu RN và phân biệt sáng/tối', () {
    expect(MdyPalette.light.primary, const Color(0xFF1F4F55));
    expect(MdyPalette.dark.primary, const Color(0xFF2B767C));
    expect(MdyPalette.light.scrim, const Color(0x66141818));
    expect(MdyIcons.values.length, greaterThanOrEqualTo(81));
    expect(MdyIcons.lightMode.filledPath, isNotNull);
    expect(MdyIcons.mail.filledPath, isNull);
  });

  test('Chữ cái avatar giống RN', () {
    expect(MdyAvatar.initials('Trần Thị Linh'), 'TL');
    expect(MdyAvatar.initials('  linh '), 'L');
    expect(MdyAvatar.initials(''), '');
  });

  test('Lựa chọn giao diện đọc/ghi giống localStore RN', () async {
    SharedPreferences.setMockInitialValues({'theme': 'dark'});
    expect(await MdyThemeController.load(), MdyThemeChoice.dark);
    expect(MdyThemeController.parse('weird'), MdyThemeChoice.system);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(mdyThemeChoiceProvider.notifier)
        .change(MdyThemeChoice.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme'), 'light');
  });

  for (final theme in [MdyThemeChoice.light, MdyThemeChoice.dark]) {
    testWidgets('Gallery primitive render được ở ${theme.name}', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(_Gallery(onTap: () => taps++), theme: theme),
      );
      await tester.pump(MdyMotion.base);
      expect(tester.takeException(), isNull);
      final context = tester.element(find.text('header'));
      expect(context.mdyDark, theme == MdyThemeChoice.dark);
      await tester.tap(find.byKey(const Key('overlap-button')));
      await tester.ensureVisible(find.text('Hàng'));
      await tester.pump();
      await tester.tap(find.text('Hàng'));
      expect(taps, 2);
      await tester.ensureVisible(find.text('99+'));
      expect(find.text('99+'), findsOneWidget);
      expect(find.byKey(const Key('email-error')), findsOneWidget);
    });
  }

  testWidgets('Phần card bị kéo lên vẫn nhận chạm', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 200),
              MdyOverlap(
                by: 64,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(
                    key: Key('pulled'),
                    height: 100,
                    width: 100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(const Key('pulled')));
    expect(box.top, 136);
    await tester.tapAt(Offset(box.center.dx, box.top + 10));
    expect(taps, 1);
  });

  testWidgets('ListPage: back, hàng, làm mới', (tester) async {
    var back = 0;
    await tester.pumpWidget(
      host(
        MdyListPage<String>(
          title: 'Lớp của tôi',
          subtitle: '3 lớp',
          backLabel: 'Quay lại',
          onBack: () => back++,
          rows: const ['A', 'B', 'C'],
          rowKey: (r) => r,
          renderRow: (context, r, i) => MdyText('row $r'),
          refresh: () async {},
        ),
      ),
    );
    expect(find.text('row C'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subpage-back')));
    expect(back, 1);
  });

  testWidgets('Toast tự ẩn sau 2200ms, sheet và dialog mở được', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showMdySheet<void>(
                      context,
                      builder: (_) => const MdySheet(
                        title: 'Sheet',
                        children: [Text('nội dung sheet')],
                      ),
                    ),
                    child: const Text('open sheet'),
                  ),
                  TextButton(
                    onPressed: () => showMdyDialog<void>(
                      context,
                      builder: (_) => const MdyConfirmationDialog(
                        title: 'Đăng xuất?',
                        children: [Text('xác nhận')],
                      ),
                    ),
                    child: const Text('open dialog'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    ref.read(mdyToastProvider.notifier).show('Đã lưu');
    await tester.pump();
    expect(find.text('Đã lưu'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('Đã lưu'), findsNothing);

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('nội dung sheet'), findsOneWidget);
    Navigator.of(tester.element(find.text('nội dung sheet'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất?'), findsOneWidget);
  });
}
