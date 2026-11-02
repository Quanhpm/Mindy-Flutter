import 'package:flutter/material.dart';

import 'staff_theme.dart';
import 'sym.dart';

/// Ô nhập kiểu staff: nhãn trên, viền bo tròn, icon trái, nút hiện/ẩn mật khẩu.
class StaffInput extends StatefulWidget {
  const StaffInput({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hint,
    this.error,
    this.password = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.showPasswordLabel = 'show',
    this.hidePasswordLabel = 'hide',
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hint;

  /// Có lỗi: viền đỏ nhạt + dòng lỗi (chuỗi rỗng = chỉ đổi viền)
  final String? error;
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String showPasswordLabel;
  final String hidePasswordLabel;

  @override
  State<StaffInput> createState() => _StaffInputState();
}

class _StaffInputState extends State<StaffInput> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final err = widget.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(widget.label, style: StaffText.label),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: err != null ? StaffColors.lineError : StaffColors.line),
          ),
          child: Row(children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 22, color: StaffColors.muted), const SizedBox(width: 10)],
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                obscureText: widget.password && !_visible,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                autofillHints: widget.autofillHints,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: StaffColors.teal700,
                style: StaffText.body,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: StaffText.body.copyWith(color: StaffColors.faint),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            if (widget.password)
              IconButton(
                tooltip: _visible ? widget.hidePasswordLabel : widget.showPasswordLabel,
                onPressed: widget.enabled ? () => setState(() => _visible = !_visible) : null,
                icon: Icon(_visible ? Sym.visibilityOff : Sym.visibility, size: 22, color: StaffColors.muted),
              ),
          ]),
        ),
        if (err != null && err.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(err, style: StaffText.small.copyWith(color: StaffColors.redFg)),
            ),
          ),
      ]),
    );
  }
}
