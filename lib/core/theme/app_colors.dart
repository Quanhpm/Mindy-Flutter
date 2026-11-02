import 'package:flutter/widgets.dart';

/// Token màu - copy từ `src/theme/colors.ts` + `global.css`.
/// Dùng: `AppColors.forest`. Không viết màu literal trong widget.
class AppColors {
  AppColors._();

  static const ember = Color(0xFFC2410C);
  static const ribbon = Color(0xFFEC4A3C);
  static const ribbonDeep = Color(0xFFC8281D);
  static const ribbonFold = Color(0xFF8E1A12);
  static const canvas = Color(0xFFFFFFFF);
  static const mint = Color(0xFF338A85);
  static const forest = Color(0xFF1D5B57);
  static const coral = Color(0xFFFF7F50);
  static const headsup = Color(0xFFFF5400);
  static const sunshine = Color(0xFFFFDDAE);
  static const logoSoft = Color(0xFFD8F0FA);
  static const black = Color(0xFF000000);
  static const soft = Color(0xFFF1F7F6);
  static const line = Color(0xFFD8E9E8);
  static const muted = Color(0xFF346B68);
  static const peach = Color(0xFFFFEEE8);
  static const action = Color(0xFFFF9973);
  static const actionHover = Color(0xFFFFA584);
  static const banner = Color(0xFFCAE1DF);
  static const catalogInk = Color(0xFF262626);
  static const statusGreen = Color(0xFF15803D);
  static const statusYellow = Color(0xFFA16207);
  static const statusRed = Color(0xFFB91C1C);
  static const pastelRed = Color(0xFFD57777);
  static const inkSoft = Color(0xFF2E2E2E);
  static const inkGray = Color(0xFF6B6B6B);
  static const forestDeep = Color(0xFF12302E);
  static const forestNight = Color(0xFF0C2422);
  static const teal = Color(0xFF1F9184);
  static const aqua = Color(0xFF7FD6C9);
  static const cream = Color(0xFFFFF1D6);
  static const tape = Color(0xFF78F0E8);
  static const coverA = Color(0xFFA6DED4);
  static const coverASoft = Color(0xFFDAF6F0);
  static const coverB = Color(0xFFEFC8AA);
  static const coverBSoft = Color(0xFFFEEADB);
  static const coverC = Color(0xFFF6C3BA);
  static const coverCSoft = Color(0xFFFFE8E3);
  static const coverD = Color(0xFFB6DDBD);
  static const coverDSoft = Color(0xFFE1F5E4);

  /// 4 cặp màu bìa khoá học (CourseCover)
  static const covers = [
    (coverA, coverASoft),
    (coverB, coverBSoft),
    (coverC, coverCSoft),
    (coverD, coverDSoft),
  ];
}

/// Màu chữ theo vùng - thay `src/theme/regions.ts` (NativeWind vars).
/// Bọc một vùng: `RegionColors.home(child: ...)`, đọc: `RegionColors.of(context).foreground`.
class RegionColors extends InheritedWidget {
  const RegionColors._({
    required super.child,
    required this.forest,
    required this.muted,
    required this.mint,
    required this.foreground,
    required this.mutedForeground,
  });

  final Color forest;
  final Color muted;
  final Color mint;
  final Color foreground;
  final Color mutedForeground;

  static const _base = RegionColors._(
    forest: AppColors.forest,
    muted: AppColors.muted,
    mint: AppColors.mint,
    foreground: AppColors.forest,
    mutedForeground: AppColors.muted,
    child: SizedBox.shrink(),
  );

  /// Trang chủ: forest/muted thành đen
  factory RegionColors.home({required Widget child}) => RegionColors._(
        forest: AppColors.black,
        muted: AppColors.black,
        mint: AppColors.mint,
        foreground: AppColors.black,
        mutedForeground: AppColors.black,
        child: child,
      );

  /// Giỏ hàng: các *-foreground thành đen
  factory RegionColors.cart({required Widget child}) => RegionColors._(
        forest: AppColors.forest,
        muted: AppColors.muted,
        mint: AppColors.mint,
        foreground: AppColors.black,
        mutedForeground: AppColors.black,
        child: child,
      );

  /// Chi tiết khoá học: forest/muted/mint thành đen
  factory RegionColors.courseDetail({required Widget child}) => RegionColors._(
        forest: AppColors.black,
        muted: AppColors.black,
        mint: AppColors.black,
        foreground: AppColors.black,
        mutedForeground: AppColors.black,
        child: child,
      );

  /// Danh sách khoá học: thành catalogInk (bộ lọc đặt ngoài vùng này)
  factory RegionColors.catalog({required Widget child}) => RegionColors._(
        forest: AppColors.catalogInk,
        muted: AppColors.catalogInk,
        mint: AppColors.catalogInk,
        foreground: AppColors.catalogInk,
        mutedForeground: AppColors.catalogInk,
        child: child,
      );

  static RegionColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RegionColors>() ?? _base;

  @override
  bool updateShouldNotify(RegionColors old) =>
      forest != old.forest || foreground != old.foreground || mint != old.mint;
}
