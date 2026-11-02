import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'code_editing.dart';

/// Editor code không phụ thuộc package ngoài: số dòng, không ngắt dòng (cuộn ngang),
/// tự thụt lề khi xuống dòng, tắt gợi ý/autocorrect của bàn phím.
/// (Kế hoạch ban đầu dùng `re_editor`; v1 chọn bản tự viết để không thêm dependency, ghi ở REMAINING_WORK_PLAN §15.)
class CodeEditorField extends StatelessWidget {
  const CodeEditorField({
    super.key,
    required this.controller,
    required this.undo,
    required this.label,
    this.focusNode,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final UndoHistoryController undo;
  final String label;
  final FocusNode? focusNode;
  final bool readOnly;

  static const style = TextStyle(fontFamily: 'RobotoMono', fontSize: 13, height: 1.5, color: AppColors.inkSoft);
  static const strut = StrutStyle(fontFamily: 'RobotoMono', fontSize: 13, height: 1.5, forceStrutHeight: true);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final painter = TextPainter(
          text: const TextSpan(text: 'M', style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final charWidth = painter.width;
        painter.dispose();
        final lines = lineCount(value.text);
        final numbers = List.generate(lines, (i) => '${i + 1}').join('\n');
        return LayoutBuilder(
          builder: (context, box) {
            final gutter = math.max(28.0, '$lines'.length * charWidth + 16);
            final width = math.max(box.maxWidth - gutter - 1, longestLine(value.text) * charWidth + 48);
            return ColoredBox(
              color: AppColors.soft,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: gutter,
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          numbers,
                          textAlign: TextAlign.right,
                          strutStyle: strut,
                          style: style.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ),
                    Container(width: 1, color: AppColors.line),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: width,
                          child: TextField(
                              key: const Key('code-editor-field'),
                              controller: controller,
                              undoController: undo,
                              focusNode: focusNode,
                              readOnly: readOnly,
                              maxLines: null,
                              minLines: 12,
                              style: style,
                              strutStyle: strut,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              autocorrect: false,
                              enableSuggestions: false,
                              enableIMEPersonalizedLearning: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              textCapitalization: TextCapitalization.none,
                              inputFormatters: [CodeIndentFormatter()],
                              decoration: InputDecoration.collapsed(hintText: label),
                            ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Thanh phím phụ nằm trên bàn phím: Tab, cặp ngoặc, ký tự hay dùng, Undo/Redo.
class CodeKeyBar extends StatelessWidget {
  const CodeKeyBar({
    super.key,
    required this.controller,
    required this.undo,
    required this.undoLabel,
    required this.redoLabel,
    required this.tabLabel,
  });

  final TextEditingController controller;
  final UndoHistoryController undo;
  final String undoLabel, redoLabel, tabLabel;

  static const _keys = <(String label, String text, int? caret)>[
    ('{ }', '{}', 1),
    ('( )', '()', 1),
    ('[ ]', '[]', 1),
    (';', ';', null),
    ('"', '""', 1),
    ('=', '=', null),
    ('<', '<', null),
    ('>', '>', null),
    ('.', '.', null),
  ];

  void _insert(String text, int? caret) => controller.value = insertCode(controller.value, text, caret: caret);

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas,
    child: Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      height: 48,
      child: ListView(
        key: const Key('code-key-bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _Key(label: '⇥', semantic: tabLabel, onTap: () => _insert(codeIndent, null)),
          for (final key in _keys) _Key(label: key.$1, semantic: key.$1, onTap: () => _insert(key.$2, key.$3)),
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: undo,
            builder: (context, value, _) => Row(
              children: [
                _Key(label: '↶', semantic: undoLabel, onTap: value.canUndo ? undo.undo : null),
                _Key(label: '↷', semantic: redoLabel, onTap: value.canRedo ? undo.redo : null),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.semantic, required this.onTap});
  final String label, semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: semantic,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: CodeEditorField.style.copyWith(
            fontSize: 15,
            color: onTap == null ? AppColors.line : AppColors.forest,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
