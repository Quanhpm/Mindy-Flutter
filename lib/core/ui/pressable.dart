import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thu nhỏ 0.97 khi nhấn - `components/common/PressableScale.tsx`.
/// Tắt hiệu ứng khi người dùng bật giảm chuyển động.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.isButton = true,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool isButton;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || Motion.reduced(context)) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.isButton,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? Motion.pressScale : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}
