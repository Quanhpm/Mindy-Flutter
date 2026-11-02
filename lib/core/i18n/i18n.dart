import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Dùng lại NGUYÊN file dịch của RN (`assets/i18n/vi.json`, `en.json`) với cùng key,
/// nên port màn hình chỉ cần đổi `t('auth.login.title')` y như bên RN.
///
/// Trong widget:
///   final t = ref.watch(trProvider);
///   Text(t('common.requestId', {'id': requestId}))
class Translator {
  Translator(this._data, this.locale);
  final Map<String, dynamic> _data;
  final Locale locale;

  static final _param = RegExp(r'\{\{\s*(\w+)\s*\}\}');
  static final _nested = RegExp(r'\$t\(([\w.]+)\)');

  String call(String key, [Map<String, Object?> params = const {}]) {
    Object? node = _data;
    for (final part in key.split('.')) {
      if (node is Map && node.containsKey(part)) {
        node = node[part];
      } else {
        return key; // thiếu key: hiện luôn key để dễ phát hiện
      }
    }
    if (node is! String) return key;
    return node
        .replaceAllMapped(_nested, (m) => call(m.group(1)!))
        .replaceAllMapped(_param, (m) => '${params[m.group(1)] ?? ''}');
  }

  /// Key dạng mảng, vd `schedule.days` -> ['T2', ..., 'CN']
  List<String> list(String key) {
    Object? node = _data;
    for (final part in key.split('.')) {
      node = node is Map ? node[part] : null;
    }
    return node is List ? node.map((e) => '$e').toList() : const [];
  }
}

/// 2 ngôn ngữ, tiếng Việt mặc định (ADR-0006)
class I18n {
  I18n._();
  static const supported = [Locale('vi'), Locale('en')];
  static final Map<String, Map<String, dynamic>> _bundles = {};
  static const _prefKey = 'language';

  /// Gọi 1 lần trong main() trước runApp.
  static Future<Locale> load() async {
    // Header tháng dùng tên tháng theo locale, phải nạp trước mọi màn/preview.
    await initializeDateFormatting();
    for (final l in supported) {
      final raw = await rootBundle.loadString('assets/i18n/${l.languageCode}.json');
      _bundles[l.languageCode] = jsonDecode(raw) as Map<String, dynamic>;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    return saved == 'en' ? const Locale('en') : const Locale('vi');
  }

  static Map<String, dynamic> bundle(Locale l) => _bundles[l.languageCode] ?? _bundles['vi']!;
}

/// Override trong main() bằng locale đã lưu.
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('vi'));

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => ref.watch(initialLocaleProvider);

  Future<void> change(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(I18n._prefKey, locale.languageCode);
  }
}

final trProvider = Provider<Translator>((ref) {
  final locale = ref.watch(localeProvider);
  return Translator(I18n.bundle(locale), locale);
});
