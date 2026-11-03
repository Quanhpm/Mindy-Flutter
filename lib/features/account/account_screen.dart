import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/learning_layout.dart';
import '../../core/ui/states.dart';
import '../../core/utils/mindy_haptics.dart';

/// Tài khoản học viên - port 1:1 từ `MindyMobile/src/modules/account/AccountScreen.tsx`.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final locale = ref.watch(localeProvider);

    return LearningLayout(
      title: t('account.title'),
      prefix: 'account',
      showTitle: false,
      tintedStatusBar: true,
      contentPadding: EdgeInsets.zero,
      tab: HomeTab.account,
      onRefresh: () => ref.read(sessionProvider.notifier).reload(),
      children: LearningState<SessionUser>(
        asyncValue: null,
        prefix: 'account',
        empty: user == null,
        onRetry: () => ref.read(sessionProvider.notifier).reload(),
        child: user == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(context, t, user),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: _buildBody(
                      context,
                      ref,
                      t,
                      user,
                      locale,
                      session.biometricEnabled,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static String _avatarInitial(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .toList();
    if (parts.isEmpty) return '?';
    final slice = parts.length > 2 ? parts.sublist(parts.length - 2) : parts;
    return slice.join().toUpperCase();
  }

  Widget _buildHero(BuildContext context, Translator t, SessionUser user) {
    return Container(
      key: const Key('account-profile-hero'),
      color: AppColors.mint,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: t('account.avatar', {'name': user.displayName}),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sunshine,
                    border: Border.all(color: AppColors.canvas, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _avatarInitial(user.displayName),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Semantics(
                    button: true,
                    label: t('account.changeAvatar'),
                    hint: t('account.unavailable'),
                    enabled: false,
                    child: Container(
                      key: const Key('account-avatar-camera'),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.canvas,
                        border: Border.all(color: AppColors.line),
                      ),
                      alignment: Alignment.center,
                      child: const MindyIcon(MindyIconName.camera, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('account-profile'),
            onTap: () =>
                _openSheet(context, _AccountSheetType.profile, user: user),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 26 / 20,
                    color: AppColors.canvas,
                  ),
                ),
              ),
            ),
          ),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              height: 20 / 13.5,
              color: AppColors.canvas,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Translator t,
    SessionUser user,
    Locale locale,
    bool biometricEnabled,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nhóm 1: Đơn hàng
          Container(
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _AccountRow(
              testId: 'account-orders',
              icon: MindyIconName.bag,
              label: t('account.orders'),
              disabled: true,
            ),
          ),
          const SizedBox(height: 12),

          // Nhóm 2: Hồ sơ, Lớp của tôi, Chứng chỉ, Điểm danh
          Container(
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _AccountRow(
                  testId: 'account-edit-profile',
                  icon: MindyIconName.edit,
                  label: t('account.editProfile'),
                  disabled: true,
                ),
                _AccountRow(
                  testId: 'account-my-classes',
                  icon: MindyIconName.monitor,
                  label: t('myClasses.title'),
                  onPress: () => context.push(Routes.myClasses('account')),
                ),
                _AccountRow(
                  testId: 'account-certificates',
                  icon: MindyIconName.award,
                  label: t('account.certificates'),
                  disabled: true,
                ),
                _AccountRow(
                  testId: 'account-attendance',
                  icon: MindyIconName.checkCalendar,
                  label: t('account.attendance'),
                  disabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nhóm 3: Thông báo đẩy, Ngôn ngữ, Trợ giúp, Điều khoản
          Container(
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _AccountRow(
                  testId: 'account-push',
                  icon: MindyIconName.bell,
                  label: t('account.push'),
                  disabled: true,
                  trailing: Semantics(
                    label: t('account.push'),
                    hint: t('account.unavailable'),
                    enabled: false,
                    child: const Switch(
                      key: Key('account-push-switch'),
                      value: false,
                      onChanged: null,
                      inactiveTrackColor: AppColors.line,
                      activeTrackColor: AppColors.mint,
                      inactiveThumbColor: AppColors.canvas,
                    ),
                  ),
                ),
                _AccountRow(
                  testId: 'account-biometric-login',
                  icon: MindyIconName.lock,
                  label: t('auth.login.biometricSetting'),
                  onPress: () =>
                      _toggleBiometric(context, ref, !biometricEnabled),
                  trailing: Switch(
                    value: biometricEnabled,
                    onChanged: (enabled) =>
                        _toggleBiometric(context, ref, enabled),
                    inactiveTrackColor: AppColors.line,
                    activeTrackColor: AppColors.mint,
                    inactiveThumbColor: AppColors.canvas,
                  ),
                ),
                _AccountRow(
                  testId: 'account-language',
                  icon: MindyIconName.globe,
                  label: t('account.language'),
                  value: t(
                    locale.languageCode == 'vi'
                        ? 'account.languages.vi-VN'
                        : 'account.languages.en-EN',
                  ),
                  onPress: () =>
                      _openSheet(context, _AccountSheetType.language),
                ),
                _AccountRow(
                  testId: 'account-help',
                  icon: MindyIconName.help,
                  label: t('account.help'),
                  disabled: true,
                ),
                _AccountRow(
                  testId: 'account-policy',
                  icon: MindyIconName.document,
                  label: t('account.policy'),
                  disabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nhóm 4: Đăng xuất
          Container(
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _AccountRow(
              testId: 'account-logout',
              icon: MindyIconName.logout,
              label: t('account.logout'),
              destructive: true,
              onPress: () => _openSheet(context, _AccountSheetType.logout),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final t = ref.read(trProvider);
    try {
      final changed = await ref
          .read(sessionProvider.notifier)
          .setBiometricLogin(enabled, reason: t('auth.login.biometricReason'));
      if (!context.mounted) return;
      if (changed) await MindyHaptics.selection();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              changed
                  ? (enabled
                        ? 'auth.login.biometricEnabled'
                        : 'auth.login.biometricDisabled')
                  : 'auth.login.biometricUnavailable',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('auth.login.biometricUnavailable'))),
      );
    }
  }

  void _openSheet(
    BuildContext context,
    _AccountSheetType type, {
    SessionUser? user,
  }) {
    switch (type) {
      case _AccountSheetType.profile:
        if (user != null) {
          showAppSheet<void>(
            context,
            (_) => _ProfileSheet(user: user),
            initialSize: 0.55,
          );
        }
      case _AccountSheetType.language:
        showAppSheet<void>(
          context,
          (_) => const _LanguageSheet(),
          initialSize: 0.45,
        );
      case _AccountSheetType.logout:
        showAppSheet<void>(
          context,
          (_) => const _LogoutSheet(),
          initialSize: 0.4,
        );
    }
  }
}

enum _AccountSheetType { profile, language, logout }

class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.testId,
    required this.icon,
    required this.label,
    this.value,
    this.onPress,
    this.trailing,
    this.disabled = false,
    this.destructive = false,
  });

  final String testId;
  final MindyIconName icon;
  final String label;
  final String? value;
  final VoidCallback? onPress;
  final Widget? trailing;
  final bool disabled;
  final bool destructive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final a11yLabel = value != null ? '$label, $value' : label;
    final a11yHint = disabled ? t('account.unavailable') : null;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: MindyIcon(
              icon,
              size: 17,
              color: destructive ? AppColors.headsup : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: destructive ? AppColors.headsup : AppColors.black,
              ),
            ),
          ),
          if (value != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                value!,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          trailing ??
              ExcludeSemantics(
                child: Text(
                  t('schedule.next'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.muted,
                  ),
                ),
              ),
        ],
      ),
    );

    if (disabled) {
      content = Opacity(opacity: 0.6, child: content);
    }

    return Semantics(
      button: true,
      label: a11yLabel,
      hint: a11yHint,
      enabled: !disabled,
      child: InkWell(
        key: Key(testId),
        onTap: disabled ? null : onPress,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: content,
        ),
      ),
    );
  }
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final fields = [
      ('displayName', user.displayName),
      ('email', user.email),
      ('phone', user.phone),
      ('role', t('account.roles.${user.role.name}')),
    ];

    return ListView(
      shrinkWrap: true,
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            t('account.profile'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.forest,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          key: const Key('account-profile-fields'),
          decoration: BoxDecoration(
            color: AppColors.soft,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Text(
                  t('account.fields.${fields[i].$1}'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  (fields[i].$2 != null && fields[i].$2!.isNotEmpty)
                      ? fields[i].$2!
                      : t('account.notUpdated'),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        MindyButton(
          key: const Key('account-sheet-close'),
          label: t('common.close'),
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _LanguageSheet extends ConsumerStatefulWidget {
  const _LanguageSheet();

  @override
  ConsumerState<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<_LanguageSheet> {
  String? _error;

  Future<void> _changeLanguage(String lang) async {
    setState(() => _error = null);
    try {
      final code = lang == 'vi-VN' ? 'vi' : 'en';
      await ref.read(localeProvider.notifier).change(Locale(code));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        final t = ref.read(trProvider);
        setState(() => _error = t('errors.generic'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final locale = ref.watch(localeProvider);
    final currentLang = locale.languageCode == 'vi' ? 'vi-VN' : 'en-EN';

    return ListView(
      shrinkWrap: true,
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            t('account.language'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.forest,
            ),
          ),
        ),
        const SizedBox(height: 16),
        MindyButton(
          key: const Key('account-language-vi-VN'),
          label: t('account.languages.vi-VN'),
          variant: currentLang == 'vi-VN'
              ? ButtonVariant.primary
              : ButtonVariant.outline,
          onPressed: () => _changeLanguage('vi-VN'),
        ),
        const SizedBox(height: 12),
        MindyButton(
          key: const Key('account-language-en-EN'),
          label: t('account.languages.en-EN'),
          variant: currentLang == 'en-EN'
              ? ButtonVariant.primary
              : ButtonVariant.outline,
          onPressed: () => _changeLanguage('en-EN'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: AppColors.headsup,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        MindyButton(
          key: const Key('account-sheet-close'),
          label: t('common.close'),
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _LogoutSheet extends ConsumerStatefulWidget {
  const _LogoutSheet();

  @override
  ConsumerState<_LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends ConsumerState<_LogoutSheet> {
  bool _pending = false;
  String? _error;

  Future<void> _logout() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).logout();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final t = ref.read(trProvider);
        final reqId = requestIdOf(e);
        setState(() {
          _error = reqId != null
              ? t('common.requestId', {'id': reqId})
              : t('errors.generic');
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);

    return ListView(
      shrinkWrap: true,
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            t('account.confirmLogout'),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.forest,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: AppColors.headsup,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        MindyButton(
          key: const Key('account-logout-confirm'),
          label: t('account.logout'),
          loading: _pending,
          variant: ButtonVariant.solid,
          backgroundColor: AppColors.headsup,
          onPressed: _logout,
        ),
        const SizedBox(height: 12),
        MindyButton(
          key: const Key('account-sheet-close'),
          label: t('learning.cancel'),
          variant: ButtonVariant.outline,
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
