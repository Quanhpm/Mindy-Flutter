import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import 'auth_api.dart';
import 'auth_shell.dart';
import 'auth_validators.dart';

/// `modules/auth/RegisterScreen.tsx` + `useRegisterController`.
/// Đăng ký xong hiện "Kiểm tra email" + nút gửi lại email.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String?> _errors = {};
  Object? _failure;
  bool _pending = false;

  // Sau khi đăng ký thành công
  String? _sentTo;
  bool _resending = false, _resent = false;
  Object? _resendError;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    final errors = {
      'name': AuthValidators.displayName(_name.text),
      'email': AuthValidators.email(_email.text),
      'phone': AuthValidators.phone(_phone.text),
      'password': AuthValidators.newPassword(_password.text),
      'confirm': AuthValidators.confirm(_password.text, _confirm.text),
    };
    setState(() {
      _errors = errors;
      _failure = null;
    });
    if (errors.values.any((e) => e != null)) return;

    setState(() => _pending = true);
    try {
      await ref
          .read(authApiProvider)
          .register(displayName: _name.text, email: _email.text, password: _password.text, phone: _phone.text);
      if (!mounted) return;
      setState(() => _sentTo = _email.text.trim());
      for (final c in [_name, _email, _phone, _password, _confirm]) {
        c.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _failure = e);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _sentTo == null) return;
    setState(() {
      _resending = true;
      _resent = false;
      _resendError = null;
    });
    try {
      await ref.read(authApiProvider).resend(_sentTo!);
      if (mounted) setState(() => _resent = true);
    } catch (e) {
      if (mounted) setState(() => _resendError = e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    if (_sentTo != null) return _checkEmail(t);

    String? err(String k) => _errors[k] == null ? null : t(_errors[k]!);
    return AuthShell(
      title: t('auth.register.title'),
      description: t('auth.register.description'),
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.login),
      children: [
        MindyInput(
          label: t('auth.fields.displayName'),
          controller: _name,
          icon: MindyIconName.user,
          placeholder: t('auth.placeholders.displayName'),
          error: err('name'),
          enabled: !_pending,
        ),
        MindyInput(
          label: t('auth.fields.email'),
          controller: _email,
          icon: MindyIconName.mail,
          placeholder: t('auth.placeholders.email'),
          keyboardType: TextInputType.emailAddress,
          error: err('email'),
          enabled: !_pending,
        ),
        MindyInput(
          label: t('auth.fields.phone'),
          controller: _phone,
          icon: MindyIconName.phone,
          keyboardType: TextInputType.phone,
          error: err('phone'),
          enabled: !_pending,
        ),
        MindyInput(
          label: t('auth.fields.password'),
          controller: _password,
          icon: MindyIconName.lock,
          password: true,
          error: err('password'),
          enabled: !_pending,
        ),
        MindyInput(
          label: t('auth.fields.confirmPassword'),
          controller: _confirm,
          icon: MindyIconName.lock,
          password: true,
          error: err('confirm'),
          enabled: !_pending,
          onSubmitted: (_) => _submit(),
        ),
        if (_failure != null) FormFeedback(message: t(errorKey(_failure!)), requestId: requestIdOf(_failure!)),
        MindyButton(label: t('auth.register.submit'), loading: _pending, onPressed: _submit),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(t('auth.register.loginPrompt'), style: AppText.caption(AppColors.inkGray)),
            const SizedBox(width: 4),
            TextLink(t('auth.register.loginAction'), onTap: () => context.go(Routes.login)),
          ],
        ),
      ],
    );
  }

  Widget _checkEmail(Translator t) => AuthShell(
    title: t('auth.register.checkEmailTitle'),
    description: t('auth.register.checkEmailDescription'),
    children: [
      if (_resent) FormFeedback(message: t('auth.register.resendSuccess'), success: true),
      if (_resendError != null)
        FormFeedback(message: t(errorKey(_resendError!)), requestId: requestIdOf(_resendError!)),
      MindyButton(label: t('auth.register.backToLogin'), onPressed: () => context.go(Routes.login)),
      const SizedBox(height: 12),
      MindyButton(
        label: t('auth.register.resend'),
        variant: ButtonVariant.outline,
        loading: _resending,
        onPressed: _resend,
      ),
    ],
  );
}
