import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'icon.dart';
import 'pressable.dart';

/// HomeButton.tsx: nút trắng viền đen, bóng cứng, nhãn co theo chữ lớn.
class PaperButton extends StatelessWidget {
  const PaperButton({super.key, required this.label, this.onPressed, this.hint});
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    hint: hint,
    excludeSemantics: true,
    onTap: onPressed,
    child: Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Pressable(
        onTap: onPressed,
        isButton: false,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.black, width: 2),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.black),
                ),
              ),
              const SizedBox(width: 12),
              const MindyIcon(MindyIconName.arrow, size: 18, color: AppColors.black),
            ],
          ),
        ),
      ),
    ),
  );
}
