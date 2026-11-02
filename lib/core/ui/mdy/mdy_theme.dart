import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mdy_tokens.g.dart';

/// Lựa chọn giao diện của app staff, clone `components/ui/theme.tsx` (system | light | dark).
enum MdyThemeChoice { system, light, dark }

/// Override trong main() bằng giá trị đã lưu (giống `localStore.getTheme()` của RN).
final initialMdyThemeProvider = Provider<MdyThemeChoice>((ref) => MdyThemeChoice.system);

final mdyThemeChoiceProvider = NotifierProvider<MdyThemeController, MdyThemeChoice>(MdyThemeController.new);

class MdyThemeController extends Notifier<MdyThemeChoice> {
  static const prefKey = 'theme';

  static MdyThemeChoice parse(String? value) => switch (value) {
    'light' => MdyThemeChoice.light,
    'dark' => MdyThemeChoice.dark,
    _ => MdyThemeChoice.system,
  };

  /// Gọi 1 lần trong main() trước runApp.
  static Future<MdyThemeChoice> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return parse(prefs.getString(prefKey));
    } catch (_) {
      return MdyThemeChoice.system;
    }
  }

  @override
  MdyThemeChoice build() => ref.watch(initialMdyThemeProvider);

  Future<void> change(MdyThemeChoice value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, value.name);
    } catch (_) {
      // Như RN: lựa chọn vẫn áp dụng trong bộ nhớ nếu không lưu được.
    }
  }
}

/// Bọc ở `MaterialApp.builder`: gắn [MdyPalette] (sáng/tối) vào Theme hiện tại.
/// Chỉ widget `Mdy*` đọc palette này nên giao diện Học viên không đổi.
class MdyTheme extends ConsumerWidget {
  const MdyTheme({super.key, required this.child});
  final Widget child;

  static bool isDark(MdyThemeChoice choice, Brightness platform) =>
      choice == MdyThemeChoice.dark || (choice == MdyThemeChoice.system && platform == Brightness.dark);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(mdyThemeChoiceProvider);
    final dark = isDark(choice, MediaQuery.platformBrightnessOf(context));
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        extensions: [
          ...base.extensions.values.where((e) => e is! MdyPalette),
          dark ? MdyPalette.dark : MdyPalette.light,
        ],
      ),
      child: child,
    );
  }
}

extension MdyContext on BuildContext {
  /// Bảng màu RN hiện hành: `context.mdy.primary`.
  MdyPalette get mdy => Theme.of(this).extension<MdyPalette>() ?? MdyPalette.light;

  bool get mdyDark => identical(mdy, MdyPalette.dark);

  /// `useReducedMotion()` của RN.
  bool get mdyReducedMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// Toast toàn cục, clone `useAuth().toast` + `<Toast/>` của AuthApp (tự ẩn sau 2200ms).
final mdyToastProvider = NotifierProvider<MdyToastController, String?>(MdyToastController.new);

class MdyToastController extends Notifier<String?> {
  static const duration = Duration(milliseconds: 2200);
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String text) {
    _timer?.cancel();
    state = text;
    _timer = Timer(duration, () {
      if (ref.mounted) state = null;
    });
  }

  void clear() {
    _timer?.cancel();
    state = null;
  }
}
