import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import 'icon.dart';
import 'pressable.dart';

/// Ô nhập có nhãn - `components/ui/Input`. Viền headsup khi có lỗi.
class MindyInput extends ConsumerStatefulWidget {
  const MindyInput({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.icon,
    this.password = false,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final MindyIconName? icon;
  final bool password;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  ConsumerState<MindyInput> createState() => _MindyInputState();
}

class _MindyInputState extends ConsumerState<MindyInput> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final hasError = widget.error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.black)),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: hasError ? AppColors.headsup : AppColors.line, width: 1.5),
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[MindyIcon(widget.icon!, size: 17), const SizedBox(width: 10)],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    obscureText: widget.password && !_visible,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onSubmitted,
                    onChanged: widget.onChanged,
                    autofillHints: widget.autofillHints,
                    cursorColor: AppColors.mint,
                    style: const TextStyle(fontSize: 15, color: AppColors.black),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.placeholder,
                      hintStyle: const TextStyle(color: AppColors.muted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (widget.password)
                  Pressable(
                    semanticLabel: t(_visible ? 'common.hidePassword' : 'common.showPassword'),
                    onTap: widget.enabled ? () => setState(() => _visible = !_visible) : null,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(child: MindyIcon(_visible ? MindyIconName.eyeOff : MindyIconName.eye, size: 18)),
                    ),
                  ),
              ],
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.error!,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headsup)),
              ),
            ),
        ],
      ),
    );
  }
}
