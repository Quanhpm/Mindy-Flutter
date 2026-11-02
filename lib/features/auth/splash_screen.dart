import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';

/// Hiện trong lúc kiểm tra phiên (GET auth/me) - giống skeleton `session-loading` bên RN.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Skeleton(height: 96)),
          ),
        ),
      );
}
