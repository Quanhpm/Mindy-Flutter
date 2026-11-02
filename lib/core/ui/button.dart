import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

enum ButtonVariant { primary, outline, solid, action, ghost }

/// `components/ui/Button` - cao tối thiểu 54, bo tròn, primary là gradient mint→forest.
class MindyButton extends StatelessWidget {
  const MindyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.icon,
    this.minHeight,
    this.padding,
    this.radius,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool loading;
  final bool expand;
  final Widget? icon;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;
  final double? radius;

  bool get _darkText =>
      variant == ButtonVariant.outline || variant == ButtonVariant.ghost || variant == ButtonVariant.action;

  @override
  Widget build(BuildContext context) {
    final blocked = loading || onPressed == null;
    final textColor = _darkText ? AppColors.black : AppColors.canvas;

    final r = BorderRadius.all(Radius.circular(radius ?? 999));
    final decoration = switch (variant) {
      ButtonVariant.primary => BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.mint, AppColors.forest]),
          borderRadius: r,
          boxShadow: const [BoxShadow(color: Color(0x401D5B57), blurRadius: 16, offset: Offset(0, 8))],
        ),
      ButtonVariant.outline => BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.banner, width: 1.5),
          borderRadius: r,
        ),
      ButtonVariant.solid => BoxDecoration(
          color: AppColors.forest, borderRadius: r),
      ButtonVariant.action => BoxDecoration(
          color: AppColors.action, borderRadius: r),
      ButtonVariant.ghost => const BoxDecoration(),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _darkText ? AppColors.forest : AppColors.canvas),
            ),
          )
        else if (icon != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: icon),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
          ),
        ),
      ],
    );

    return Semantics(
      enabled: !blocked,
      label: label,
      excludeSemantics: true,
      button: true,
      // Con bị exclude nên action trợ năng phải gắn ở node nút này.
      onTap: blocked ? null : onPressed,
      child: Opacity(
        opacity: blocked ? 0.5 : 1,
        child: Pressable(
          onTap: blocked ? null : onPressed,
          isButton: false,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight ?? 54, minWidth: 44),
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: decoration,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Link chữ mint đậm (`.text-link`)
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mint)),
          ),
        ),
      );
}
