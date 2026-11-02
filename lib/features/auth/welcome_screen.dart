import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/ui/ui.dart';
import 'auth_shell.dart';

/// `modules/auth/WelcomeScreen.tsx` + `StaffSession` trong `AuthRoutes.tsx`.
/// - Khách: chào mừng + Đăng nhập / Tạo tài khoản.
/// - Đã đăng nhập nhưng không phải STUDENT: báo lỗi + nút Đăng xuất.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _signingOut = false;
  Object? _logoutError;

  Future<void> _logout() async {
    setState(() {
      _signingOut = true;
      _logoutError = null;
    });
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (e) {
      if (mounted) setState(() => _logoutError = e);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider).user;

    if (user != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScreenState(title: t('auth.brandName'), description: t('auth.session.staff')),
                if (_logoutError != null) ...[
                  const SizedBox(height: 24),
                  ScreenState(
                    title: t('auth.session.logout'),
                    description: t('errors.generic'),
                    requestId: requestIdOf(_logoutError!),
                  ),
                ],
                const SizedBox(height: 24),
                MindyButton(label: t('auth.session.logout'), onPressed: _signingOut ? null : _logout),
              ],
            ),
          ),
        ),
      );
    }

    return AuthShell(
      title: t('auth.welcome.title'),
      description: t('auth.welcome.description'),
      children: [
        MindyButton(label: t('auth.welcome.login'), onPressed: () => context.push(Routes.login)),
        const SizedBox(height: 12),
        MindyButton(
          label: t('auth.welcome.register'),
          variant: ButtonVariant.outline,
          onPressed: () => context.push(Routes.register),
        ),
      ],
    );
  }
}
