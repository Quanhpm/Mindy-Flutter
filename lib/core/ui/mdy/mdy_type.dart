import 'package:flutter/widgets.dart';

import 'mdy_tokens.g.dart';

/// Typography RN (`components/ui/classes.ts` + tailwind `font-bvp-*`, `text-size-*`, `leading-line-*`).
/// Không gắn màu: màu lấy từ `context.mdy` tại chỗ dùng (sáng/tối).
abstract final class MdyType {
  static const family = 'BeVietnamPro';

  static TextStyle _s(double size, FontWeight weight, [double? line, double? spacing]) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: line == null ? null : line / size,
    letterSpacing: spacing,
  );

  static const w400 = FontWeight.w400;
  static const w500 = FontWeight.w500;
  static const w600 = FontWeight.w600;
  static const w700 = FontWeight.w700;

  /// `ui.text`: regular 14/21 (mặc định của `<Text>`).
  static final text = _s(14, w400, 21);

  /// `ui.title`: semibold 17/25.
  static final title = _s(17, w600, 25);

  /// `ui.heading`: semibold 20/30.
  static final heading = _s(20, w600, 30);

  /// `ui.caption`: 12/18.
  static final caption = _s(12, w400, 18);

  /// `ui.rowLabel`: medium 15.
  static final rowLabel = _s(15, w500);

  /// `ui.actionLabel` (đè rowLabel): 14.
  static final actionLabel = _s(14, w500);

  /// `ui.chipText`: semibold 11/16.
  static final chip = _s(11, w600, 16);

  /// `ui.buttonText`: semibold 15.
  static final button = _s(15, w600);

  /// `ui.alertText`: 13/20.
  static final alert = _s(13, w400, 20);

  /// `ui.tagline`: medium 17/26.
  static final tagline = _s(17, w500, 26);

  /// `ui.wordmark`: bold 30/42, tracking -0.3.
  static final wordmark = _s(30, w700, 42, MdyLetterSpacing.wordmark);

  /// `ui.body`: 14/21 (căn giữa ở chỗ dùng).
  static final body = _s(14, w400, 21);

  /// Kích thước tự do: `MdyType.size(13, w600)` = `text-size-13 font-bvp-semibold`.
  static TextStyle size(double size, [FontWeight weight = w400, double? line]) => _s(size, weight, line);
}

/// `maxFontSizeMultiplier={1.3}` của RN.
TextScaler mdyMaxScale(BuildContext context, [double max = 1.3]) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: max);
