import 'package:flutter/material.dart';

import 'mdy_basics.dart';
import 'mdy_icon.dart';
import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';
import 'mdy_type.dart';

enum MdyButtonVariant { primary, secondary, danger, text }

enum MdyButtonSize { lg, sm }

/// Clone `components/ui/button.tsx` (cva variants, busy, pressed, disabled).
/// Truyền [label] (chữ) hoặc [child] (nội dung tuỳ ý, vd chỉ 1 icon như nút back).
class MdyButton extends StatelessWidget {
  const MdyButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.variant = MdyButtonVariant.primary,
    this.size = MdyButtonSize.lg,
    this.busy = false,
    this.icon,
    this.disabled = false,
    this.semanticLabel,
    this.padding,
    this.expand = false,
    this.borderColor,
    this.foreground,
  }) : assert(label != null || child != null);

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final MdyButtonVariant variant;
  final MdyButtonSize size;
  final bool busy;
  final MdyIcons? icon;
  final bool disabled;
  final String? semanticLabel;

  /// Đè `px-20 py-12` (vd `className="px-space-8"`).
  final EdgeInsetsGeometry? padding;

  /// `className="flex-1"`/`w-full`: chiếm hết bề ngang được cấp.
  final bool expand;

  /// Đè màu viền / màu chữ (vd nút Hủy `border-mdy-disabled` + chữ `text-mdy-primary`).
  final Color? borderColor;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final isDisabled = disabled || onPressed == null;
    final dimPrimary = isDisabled && !busy && variant == MdyButtonVariant.primary;
    final fg = foreground != null && !dimPrimary
        ? foreground!
        : dimPrimary
        ? c.disabledInk
        : switch (variant) {
            MdyButtonVariant.primary || MdyButtonVariant.danger => c.onBrand,
            MdyButtonVariant.text => c.link,
            MdyButtonVariant.secondary => c.ink,
          };
    final sm = size == MdyButtonSize.sm;
    return Semantics(
      button: true,
      enabled: !isDisabled && !busy,
      label: semanticLabel,
      child: MdyPressed(
        onTap: isDisabled || busy ? null : onPressed,
        builder: (context, pressed) {
          final bg = busy
              ? c.loading
              : dimPrimary
              ? c.disabled
              : pressed
              ? switch (variant) {
                  MdyButtonVariant.primary => c.pressed,
                  MdyButtonVariant.secondary => c.muted2,
                  MdyButtonVariant.danger => c.dangerButton,
                  MdyButtonVariant.text => c.tint2,
                }
              : switch (variant) {
                  MdyButtonVariant.primary => c.primary,
                  MdyButtonVariant.secondary => c.surface,
                  MdyButtonVariant.danger => c.dangerButton,
                  MdyButtonVariant.text => c.transparent,
                };
          final border = borderColor ?? (variant == MdyButtonVariant.secondary ? c.border : c.transparent);
          final textStyle = MdyType.button.copyWith(color: fg);
          return LayoutBuilder(builder: (context, box) {
          // Flexible chỉ hợp lệ khi bề ngang có giới hạn (nút đặt trong Row không Expanded thì không).
          final bounded = box.hasBoundedWidth;
          return Container(
            constraints: BoxConstraints(minHeight: sm ? MdySpace.s44 : MdySpace.s52),
            padding:
                padding ??
                EdgeInsets.symmetric(horizontal: MdySpace.s20, vertical: sm ? MdySpace.s8 : MdySpace.s12),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(sm ? MdyRadius.r22 : MdyRadius.r99),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: MdySpace.s8,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else if (icon != null)
                  MdyIcon(icon!, size: 20, color: fg),
                if (label != null)
                  bounded
                      ? Flexible(child: _label(context, textStyle))
                      : _label(context, textStyle)
                else
                  DefaultTextStyle.merge(style: textStyle, child: child!),
              ],
            ),
          );
          });
        },
      ),
    );
  }

  Widget _label(BuildContext context, TextStyle style) =>
      Text(label!, textAlign: TextAlign.center, textScaler: mdyMaxScale(context), style: style);
}
