import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Chuyển động - `src/theme/motion.ts`
class Motion {
  Motion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
  static const pressScale = 0.97;
  static const stagger = Duration(milliseconds: 40);
  static const staggerLimit = 8;

  /// Người dùng bật giảm chuyển động
  static bool reduced(BuildContext context) => MediaQuery.of(context).disableAnimations;
}

/// Kiểu chữ dùng chung (global.css @layer components).
/// Font Nunito: w400 Regular, w600 SemiBold, w700 Bold, w800 ExtraBold.
class AppText {
  AppText._();

  static TextStyle sectionTitle(Color c) =>
      TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c);
  static TextStyle eyebrow([Color c = AppColors.mint]) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.7, color: c);
  static TextStyle link([Color c = AppColors.mint]) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c);
  static TextStyle body(Color c) => TextStyle(fontSize: 16, color: c);
  static TextStyle caption(Color c) => TextStyle(fontSize: 14, color: c);
  static TextStyle title(Color c) => TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c);
  static TextStyle label(Color c) => TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c);
}

/// App chỉ dùng light theme (ADR-0005), kể cả khi máy bật dark mode.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.forest,
    onPrimary: AppColors.canvas,
    secondary: AppColors.mint,
    surface: AppColors.canvas,
    onSurface: AppColors.forest,
    error: AppColors.headsup,
    outline: AppColors.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: AppColors.canvas,
    splashFactory: NoSplash.splashFactory,
    textTheme: const TextTheme().apply(bodyColor: AppColors.forest, displayColor: AppColors.forest),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
  );
}
