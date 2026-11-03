import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/mdy/mdy.dart';
import 'router.dart';

class MindyApp extends ConsumerWidget {
  const MindyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mindy',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      // Bảng màu sáng/tối + toast của bộ UI clone RN (staff). Học viên không đọc palette này.
      // `Material` trong suốt ở gốc: mọi `Text` có DefaultTextStyle, không còn gạch chân vàng khi thiếu Scaffold.
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        child: MdyTheme(child: MdyToastHost(child: child ?? const SizedBox.shrink())),
      ),
      locale: ref.watch(localeProvider),
      supportedLocales: I18n.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
