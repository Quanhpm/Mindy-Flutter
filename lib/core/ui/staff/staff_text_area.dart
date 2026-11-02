import 'package:flutter/material.dart';
import 'staff_theme.dart';

class StaffTextArea extends StatelessWidget {
  const StaffTextArea({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.maxLength = 5000,
  });
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int maxLength;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: StaffText.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 3,
          maxLines: 6,
          maxLength: maxLength,
          style: StaffText.body,
          cursorColor: StaffColors.teal700,
          decoration: InputDecoration(
            filled: true,
            fillColor: StaffColors.surface,
            counterStyle: StaffText.small,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: StaffColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: StaffColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: StaffColors.teal700),
            ),
          ),
        ),
      ],
    ),
  );
}
