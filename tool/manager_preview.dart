import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindy_flutter/app/app.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'preview/manager_fixtures.dart';

Future<void> main() async {
  if (const bool.fromEnvironment('dart.vm.product')) throw StateError('Debug preview only');
  WidgetsFlutterBinding.ensureInitialized();
  initTimeZones();
  final locale = await I18n.load(), adapter = ManagerFixtureAdapter();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        initialLocaleProvider.overrideWithValue(locale),
        sessionProvider.overrideWith(ManagerFixtureSession.new),
        apiClientProvider.overrideWithValue(managerFixtureClient(adapter)),
      ],
      child: const MindyApp(),
    ),
  );
}
