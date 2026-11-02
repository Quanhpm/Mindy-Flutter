import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'quiz_models.dart';

class QuizImport {
  const QuizImport({
    this.name = '',
    this.questions = const [],
    this.issues = const [],
    this.fatal,
  });
  final String name;
  final List<QuizQuestion> questions;
  final List<({int line, String code})> issues;
  final String? fatal;
}

Future<QuizImport?> pickQuizImport() async {
  try {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;
    final f = result.files.single, ext = f.name.split('.').last.toLowerCase();
    if (!['csv', 'txt'].contains(ext)) {
      return const QuizImport(fatal: 'importUnsupported');
    }
    if (f.size > 3 * 1024 * 1024) {
      return const QuizImport(fatal: 'importTooLarge');
    }
    if (f.path == null) return const QuizImport(fatal: 'importUnreadable');
    final bytes = await File(f.path!).readAsBytes();
    if (bytes.length > 3 * 1024 * 1024) {
      return const QuizImport(fatal: 'importTooLarge');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      return const QuizImport(fatal: 'importEncoding');
    }
    return parseQuizImport(f.name, text);
  } catch (_) {
    return const QuizImport(fatal: 'importUnreadable');
  }
}

String _header(String s) {
  s = s.toLowerCase();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final e in groups.entries) {
    for (final code in e.value.runes) {
      s = s.replaceAll(String.fromCharCode(code), e.key);
    }
  }
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

QuizImport parseQuizImport(String name, String content) {
  if (content.contains('\uFFFD')) {
    return const QuizImport(fatal: 'importEncoding');
  }
  content = content
      .replaceFirst(RegExp('^\uFEFF'), '')
      .replaceAll(RegExp(r'\r\n?'), '\n');
  if (content.trim().isEmpty) return const QuizImport(fatal: 'importEmpty');
  final questions = <QuizQuestion>[], issues = <({int line, String code})>[];
  var serial = 0;
  void add(
    int line,
    String prompt,
    Map<String, String> options,
    String correct,
  ) {
    final q = QuizQuestion(
      key: 'import-${DateTime.now().microsecondsSinceEpoch}-${serial++}',
      prompt: prompt.trim(),
      options: {
        for (final label in quizLabels) label: (options[label] ?? '').trim(),
      },
      correct: correct.trim().replaceFirst(RegExp(r'\.$'), '').toUpperCase(),
    );
    final e = questionErrors(q);
    if (e.isEmpty) {
      questions.add(q);
    } else {
      issues.add((
        line: line,
        code: e.containsKey('prompt')
            ? 'importPrompt'
            : quizLabels.any(e.containsKey)
            ? 'importOption'
            : 'importCorrect',
      ));
    }
  }

  if (name.toLowerCase().endsWith('.csv')) {
    final first = content.split('\n').first;
    var delimiter = ',';
    for (final candidate in [';', '\t']) {
      if (first.split(candidate).length > first.split(delimiter).length) {
        delimiter = candidate;
      }
    }
    final rows = <({int line, List<String> cells})>[];
    var cell = '', quoted = false, line = 1, start = 1;
    var cells = <String>[];
    void end() {
      cells.add(cell);
      if (cells.any((c) => c.trim().isNotEmpty)) {
        rows.add((line: start, cells: cells));
      }
      cells = [];
      cell = '';
    }

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (quoted) {
        if (ch == '"' && i + 1 < content.length && content[i + 1] == '"') {
          cell += '"';
          i++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          if (ch == '\n') line++;
          cell += ch;
        }
      } else if (ch == '"' && cell.isEmpty) {
        quoted = true;
      } else if (ch == delimiter) {
        cells.add(cell);
        cell = '';
      } else if (ch == '\n') {
        end();
        line++;
        start = line;
      } else {
        cell += ch;
      }
    }
    if (cell.isNotEmpty || cells.isNotEmpty) end();
    if (rows.isEmpty) return const QuizImport(fatal: 'importEmpty');
    final aliases = <String, String>{
      for (final label in quizLabels) ...{
        label.toLowerCase(): label,
        'option${label.toLowerCase()}': label,
        'luachon${label.toLowerCase()}': label,
        'dapan${label.toLowerCase()}': label,
      },
      for (final key in [
        'question',
        'prompt',
        'cauhoi',
        'noidung',
        'noidungcauhoi',
      ])
        key: 'prompt',
      for (final key in [
        'correct',
        'answer',
        'correctanswer',
        'correctoption',
        'dapan',
        'dapandung',
      ])
        key: 'correct',
    };
    final columns = rows
        .removeAt(0)
        .cells
        .map((c) => aliases[_header(c)])
        .toList();
    if ([
      'prompt',
      'correct',
      ...quizLabels,
    ].any((key) => !columns.contains(key))) {
      return const QuizImport(fatal: 'importHeader');
    }
    for (final row in rows) {
      if (row.cells.length != columns.length) {
        issues.add((line: row.line, code: 'importColumns'));
        continue;
      }
      final values = <String, String>{
        for (var i = 0; i < columns.length; i++)
          if (columns[i] != null) columns[i]!: row.cells[i],
      };
      add(row.line, values['prompt'] ?? '', {
        for (final label in quizLabels) label: values[label] ?? '',
      }, values['correct'] ?? '');
    }
  } else if (name.toLowerCase().endsWith('.txt')) {
    String? prompt, last;
    var options = <String, String>{};
    var start = 1, next = 0;
    void finish([String correct = '']) {
      if (prompt != null) add(start, prompt!, options, correct);
      prompt = null;
      last = null;
      options = {};
      next = 0;
    }

    final answer = RegExp(
      r'^\s*(?:answer|correct(?:\s+answer)?|đáp\s*án(?:\s*đúng)?|dap\s*an(?:\s*dung)?)\s*[:=-]\s*([A-Da-d])\s*\.?\s*$',
      caseSensitive: false,
    );
    final option = RegExp(r'^\s*([A-Da-d])\s*[.):]\s*(.*)$'),
        prefix = RegExp(
          r'^\s*(?:(?:câu|cau|question|q)\s*\d+\s*[.:)-]|\d+\s*[.)])\s+',
          caseSensitive: false,
        );
    for (final (i, text) in content.split('\n').indexed) {
      if (text.trim().isEmpty) continue;
      final a = answer.firstMatch(text);
      if (a != null) {
        prompt ??= '';
        finish(a[1]!);
        continue;
      }
      final o = option.firstMatch(text);
      if (prompt != null &&
          next < 4 &&
          o?[1]?.toUpperCase() == quizLabels[next]) {
        last = quizLabels[next++];
        options[last!] = o![2] ?? '';
        continue;
      }
      if (prompt != null && next == 4) finish();
      if (prompt == null) {
        start = i + 1;
        prompt = text.replaceFirst(prefix, '');
      } else if (last != null) {
        options[last!] = '${options[last!]}\n$text';
      } else {
        prompt = '$prompt\n$text';
      }
    }
    finish();
  } else {
    return const QuizImport(fatal: 'importUnsupported');
  }
  return questions.isEmpty && issues.isEmpty
      ? const QuizImport(fatal: 'importEmpty')
      : QuizImport(name: name, questions: questions, issues: issues);
}
