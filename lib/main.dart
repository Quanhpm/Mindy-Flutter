import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/i18n/i18n.dart';
import 'core/utils/format.dart';

/// Chạy:  flutter run --dart-define-from-file=env/dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.validate();
  initTimeZones();
  final locale = await I18n.load();

  runApp(
    ProviderScope(
      // Riverpod 3 mặc định tự retry provider lỗi. App RN tắt retry (retry: false)
      // để không gọi lặp API thanh toán/giỏ, nên tắt hẳn ở đây.
      retry: (retryCount, error) => null,
      overrides: [initialLocaleProvider.overrideWithValue(locale)],
      child: const MindyApp(),
    ),
  );
}
