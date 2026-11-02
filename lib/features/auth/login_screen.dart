import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/session/session_controller.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/ui/staff/staff_input.dart';
import '../../core/ui/staff/staff_theme.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../../core/ui/staff/sym.dart';
import 'auth_validators.dart';

/// Login dùng chung mọi role - thiết kế `MINDY-BE/Login (1).html` (quyết định owner 02/11).
///
/// Khác thiết kế (theo quyết định owner): giữ link "Đăng ký" cho học viên;
/// ẩn "Quên mật khẩu?" và "Tiếp tục với Google" tới khi backend có luồng mobile.
/// Đăng nhập xong router tự chuyển: STUDENT -> /home, MENTOR -> /mentor.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError, _passwordError;
  Object? _failure;
  bool _pending = false;
  bool _remember = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return; // chống bấm lặp
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.loginPassword(_password.text);
      _failure = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _pending = true);
    try {
      await ref.read(sessionProvider.notifier).login(_email.text.trim(), _password.text, remember: _remember);
    } catch (e) {
      if (mounted) setState(() => _failure = e);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);

    return Scaffold(
      body: StaffBackground(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(children: [
            // ---- Header teal + ếch
            StaffHeader(
                padding: const EdgeInsets.fromLTRB(24, 36, 16, 96),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 24),
                      Text(t('home.brand.name'),
                          style: const TextStyle(
                              fontFamily: StaffText.family, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(t('auth.login.slogan'), style: StaffText.body.copyWith(color: StaffColors.onTealMuted)),
                    ]),
                  ),
                  ExcludeSemantics(
                    child: Image.asset('assets/illustrations/mindy-frog-teacher.png', height: 124),
                  ),
                ]),
              ),
            // ---- Thẻ form phủ lên header
            Transform.translate(
              offset: const Offset(0, -64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(t('auth.login.title'), style: StaffText.title.copyWith(fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(t('auth.login.subtitle'), style: StaffText.caption),
                      const SizedBox(height: 20),
                      StaffInput(
                        label: t('auth.fields.email'),
                        controller: _email,
                        icon: Sym.mail,
                        hint: t('auth.placeholders.loginEmail'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        error: _emailError != null ? t(_emailError!) : (_failure != null ? '' : null),
                        enabled: !_pending,
                        onChanged: (_) => setState(() {
                          _emailError = null;
                          _failure = null;
                        }),
                      ),
                      StaffInput(
                        label: t('auth.fields.password'),
                        controller: _password,
                        icon: Sym.lock,
                        password: true,
                        hint: t('auth.placeholders.loginPassword'),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        error: _passwordError != null ? t(_passwordError!) : (_failure != null ? '' : null),
                        enabled: !_pending,
                        showPasswordLabel: t('common.showPassword'),
                        hidePasswordLabel: t('common.hidePassword'),
                        onSubmitted: (_) => _submit(),
                        onChanged: (_) => setState(() {
                          _passwordError = null;
                          _failure = null;
                        }),
                      ),
                      if (_failure != null) _errorBanner(t, _failure!),
                      // Ghi nhớ đăng nhập (Quên mật khẩu? ẩn - chưa có API)
                      Pressable(
                        onTap: _pending ? null : () => setState(() => _remember = !_remember),
                        selected: _remember,
                        semanticLabel: t('auth.login.remember'),
                        child: SizedBox(
                          height: 44,
                          child: Row(children: [
                            Icon(_remember ? Sym.checkBox : Sym.checkBoxOutlineBlank,
                                fill: _remember ? 1 : 0, size: 22, color: StaffColors.teal700),
                            const SizedBox(width: 8),
                            Text(t('auth.login.remember'), style: StaffText.label),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StaffButton(
                        label: _pending ? t('auth.login.submitting') : t('auth.login.submit'),
                        loading: _pending,
                        onPressed: _submit,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            // ---- Học viên vẫn tự đăng ký được (quyết định owner)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(t('auth.login.registerPrompt'), style: StaffText.caption),
              TextButton(
                onPressed: _pending ? null : () => context.push(Routes.register),
                child: Text(t('auth.login.registerAction'), style: StaffText.link),
              ),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _errorBanner(Translator t, Object e) {
    final id = requestIdOf(e);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: StaffColors.redBg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Sym.error, size: 20, color: StaffColors.redFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              id == null ? t(errorKey(e)) : '${t(errorKey(e))}\n${t('common.requestId', {'id': id})}',
              style: StaffText.label.copyWith(color: StaffColors.redFg),
            ),
          ),
        ]),
      ),
    );
  }
}
