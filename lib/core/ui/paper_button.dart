import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'icon.dart';

/// Nút giấy bo viền đen, bóng cứng dịch 4px, nhấn thụt 3px - `HomeButton.tsx`.
class HomeButton extends StatefulWidget {
  const HomeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.hint,
    this.minHeight = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
  });

  final String label;
  final VoidCallback? onPressed;
  final String? hint;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<HomeButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onPressed == null || Motion.reduced(context)) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final reduced = Motion.reduced(context);

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      hint: widget.hint,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: SizedBox(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Lớp bóng đen phía sau dịch xuống 4px
              Positioned.fill(
                top: 4,
                bottom: -4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Nút phía trước nhấn thụt 3px trong 120ms
              AnimatedSlide(
                offset: _down && !reduced ? const Offset(0, 0.06) : Offset.zero,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _set(true),
                  onTapUp: (_) => _set(false),
                  onTapCancel: () => _set(false),
                  onTap: widget.onPressed,
                  child: Container(
                    constraints: BoxConstraints(minWidth: 44, minHeight: widget.minHeight),
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      border: Border.all(color: AppColors.black, width: 2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const MindyIcon(MindyIconName.arrow, size: 18, color: AppColors.black),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alias tương thích ngược cho `HomeButton`.
typedef PaperButton = HomeButton;
