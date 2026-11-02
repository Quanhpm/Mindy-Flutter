import 'dart:convert';

import 'package:flutter/services.dart';

/// Thao tác soạn code thuần (test được, không phụ thuộc widget).
const codeIndent = '    ';

/// Chèn [text] vào vùng chọn hiện tại; [caret] = vị trí con trỏ tính từ đầu [text] (mặc định cuối).
/// Dùng cho thanh phím phụ: `{}` đặt con trỏ giữa cặp ngoặc.
TextEditingValue insertCode(TextEditingValue value, String text, {int? caret}) {
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final start = selection.start, end = selection.end;
  final next = value.text.replaceRange(start, end, text);
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + (caret ?? text.length)),
  );
}

/// Khoảng trắng đầu dòng chứa [offset].
String leadingWhitespace(String text, int offset) {
  if (offset <= 0) return '';
  final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
  var i = lineStart;
  while (i < text.length && (text[i] == ' ' || text[i] == '\t')) {
    i++;
  }
  return text.substring(lineStart, i < offset ? i : offset);
}

/// Xuống dòng giữ thụt lề của dòng trên; thêm một mức sau `{`, `[` hoặc `(`.
/// Chỉ xử lý khi người dùng gõ đúng một ký tự `\n` (không đụng vào dán nhiều dòng).
class CodeIndentFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final sel = newValue.selection;
    if (!sel.isCollapsed ||
        sel.start < 1 ||
        newValue.text.length != oldValue.text.length - (oldValue.selection.end - oldValue.selection.start) + 1 ||
        newValue.text[sel.start - 1] != '\n') {
      return newValue;
    }
    final before = newValue.text.substring(0, sel.start - 1);
    final indent = leadingWhitespace(before, before.length);
    final opener = before.isNotEmpty && '{[('.contains(before[before.length - 1]);
    final extra = indent + (opener ? codeIndent : '');
    if (extra.isEmpty) return newValue;
    final text = newValue.text.replaceRange(sel.start, sel.start, extra);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: sel.start + extra.length));
  }
}

/// Số dòng để vẽ cột số dòng.
int lineCount(String text) => '\n'.allMatches(text).length + 1;

/// Độ dài dòng dài nhất (ký tự) để tính bề rộng vùng cuộn ngang (không ngắt dòng code).
int longestLine(String text) {
  var longest = 0;
  for (final line in text.split('\n')) {
    if (line.length > longest) longest = line.length;
  }
  return longest;
}

const _intMin = -2147483648;
const _intMax = 2147483647;
const _maxSafe = 9007199254740991; // 2^53 - 1: JavaScript chỉ biểu diễn chính xác tới đây

/// Giống kiểm tra kiểu ở server (`code-signature.ts`) để báo lỗi ngay trên app.
bool matchesCodeType(String type, Object? value) {
  if (type.endsWith('[]')) {
    final inner = type.substring(0, type.length - 2);
    return value is List && value.every((v) => matchesCodeType(inner, v));
  }
  return switch (type) {
    'int' => value is int && value >= _intMin && value <= _intMax,
    'long' => value is int && value.abs() <= _maxSafe,
    'double' => value is num && value.isFinite,
    'boolean' => value is bool,
    'string' => value is String,
    _ => false,
  };
}

/// Ví dụ nhập cho từng kiểu (giống web).
String codeTypeExample(String type) {
  const base = {'int': '5', 'long': '10000000000', 'double': '1.5', 'boolean': 'true', 'string': '"abc"'};
  if (type.endsWith('[][]')) return '[[${base[type.substring(0, type.length - 4)] ?? '0'}]]';
  if (type.endsWith('[]')) return '[${base[type.substring(0, type.length - 2)] ?? '0'}]';
  return base[type] ?? '0';
}

/// Đọc một tham số học viên tự nhập: chuỗi gõ thẳng (không cần nháy), kiểu khác là JSON
/// (`5`, `true`, `[1, 2]`, `[["a"]]`). `null` = không hợp lệ.
({Object? value})? parseCodeArg(String type, String text) {
  final raw = text.trim();
  if (type == 'string' && !raw.startsWith('"')) return (value: text);
  if (raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    return matchesCodeType(type, value) ? (value: value) : null;
  } on FormatException {
    return null;
  }
}
