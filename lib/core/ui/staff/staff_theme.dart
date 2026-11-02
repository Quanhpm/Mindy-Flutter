import 'package:flutter/material.dart';

/// Màu giao diện staff (Login chung + Mentor), lấy từ file Claude Design.
/// Khác hẳn bảng màu Học viên (`AppColors`). Không viết màu literal trong widget.
class StaffColors {
  StaffColors._();

  // Teal (header gradient, nút chính)
  static const teal900 = Color(0xFF123236);
  static const teal700 = Color(0xFF1F4F55);
  static const teal600 = Color(0xFF1F5F66);
  static const teal500 = Color(0xFF2B6A71);
  static const tealSoft = Color(0xFFE4EFED);
  static const tealTint = Color(0xFFEEF4F3);
  static const tealLine = Color(0xFFD6E3E1);
  static const mint = Color(0xFF9FE3D6);
  static const onTealMuted = Color(0xFFC7DCD9);
  static const avatarBg = Color(0xFFD9E6E4);

  // Nền + chữ
  static const bg = Color(0xFFF6F5F2);
  static const bgGlowTeal = Color(0xFFD7E9E5);
  static const bgGlowSand = Color(0xFFF2E4D0);
  static const ink = Color(0xFF1C1B19);
  static const muted = Color(0xFF6B6862);
  static const subtle = Color(0xFF8A867E);
  static const faint = Color(0xFFB5B1A9);
  static const line = Color(0xFFE3E0DA);
  static const lineError = Color(0xFFE8C9BF);
  static const surface = Color(0xFFFFFFFF);
  static const chipGray = Color(0xFFEFEDE8);
  static const chipGrayAlt = Color(0xFFF1EFEB);

  // Nhấn / trạng thái
  static const accent = Color(0xFFC2410C); // badge số, chấm chưa đọc, nhãn MỚI
  static const star = Color(0xFFC98A12);
  static const greenBg = Color(0xFFE3F0E6);
  static const greenFg = Color(0xFF1D6B3A);
  static const redBg = Color(0xFFF8E1DA);
  static const redFg = Color(0xFF9A2F12);
  static const amberBg = Color(0xFFFBECD3);
  static const amberFg = Color(0xFF8A4B06);
  static const blueBg = Color(0xFFE1E8F6);
  static const blueFg = Color(0xFF274A8A);

  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [teal900, teal700, teal500],
    stops: [0, .55, 1],
  );
}

/// Kiểu chữ staff - font Be Vietnam Pro (400/500/600/700).
class StaffText {
  StaffText._();
  static const family = 'BeVietnamPro';

  static const pageTitle = TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w600);
  static const title = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, color: StaffColors.ink);
  static const section = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, color: StaffColors.ink);
  static const body = TextStyle(fontFamily: family, fontSize: 15, color: StaffColors.ink);
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600, color: StaffColors.ink);
  static const caption = TextStyle(fontFamily: family, fontSize: 13, color: StaffColors.muted);
  static const small = TextStyle(fontFamily: family, fontSize: 12, color: StaffColors.subtle);
  static const label = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w500, color: StaffColors.ink);
  static const link = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w600, color: StaffColors.teal600);
  static const eyebrow =
      TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: StaffColors.subtle);
  static const bigTime = TextStyle(fontFamily: family, fontSize: 28, fontWeight: FontWeight.w600, color: StaffColors.teal900);
  static const button = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600);
}

/// Tông màu chip trạng thái (Đang dạy, Chờ duyệt, Bị từ chối...).
enum StatusTone {
  green(StaffColors.greenBg, StaffColors.greenFg),
  teal(StaffColors.tealSoft, StaffColors.teal600),
  amber(StaffColors.amberBg, StaffColors.amberFg),
  red(StaffColors.redBg, StaffColors.redFg),
  blue(StaffColors.blueBg, StaffColors.blueFg),
  gray(StaffColors.chipGray, StaffColors.muted);

  const StatusTone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}
