import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> flatten(Map<String, dynamic> value, [String prefix = '']) => {
  for (final entry in value.entries)
    if (entry.value is Map<String, dynamic>)
      ...flatten(entry.value as Map<String, dynamic>, '$prefix${entry.key}.')
    else
      '$prefix${entry.key}': entry.value,
};

void main() {
  final bundles = {
    for (final lang in ['vi', 'en'])
      lang: flatten(jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()) as Map<String, dynamic>),
  };
  test('Hai ngôn ngữ có cùng key, kiểu dữ liệu và tham số nội suy', () {
    final vi = bundles['vi']!, en = bundles['en']!;
    expect(en.keys.toSet(), vi.keys.toSet());
    final parameter = RegExp(r'\{\{\s*(\w+)\s*\}\}');
    for (final key in vi.keys) {
      expect(en[key].runtimeType, vi[key].runtimeType, reason: key);
      if (vi[key] is String) {
        Set<String?> params(Object? value) => parameter.allMatches(value! as String).map((m) => m.group(1)).toSet();
        expect(params(en[key]), params(vi[key]), reason: key);
        expect((en[key]! as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('Key dịch literal dùng trong lib đều tồn tại', () {
    final literal = RegExp(r"\bt\('([\w.]+)'");
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        expect(bundles['vi']!.containsKey(match.group(1)), isTrue, reason: '${file.path}: ${match.group(1)}');
      }
    }
  });
}
