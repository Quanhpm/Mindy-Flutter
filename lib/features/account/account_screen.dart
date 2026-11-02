import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/session/session_controller.dart';
import '../../core/ui/ui.dart';

/// Tài khoản - `account/AccountScreen.tsx`.
/// Hồ sơ chỉ đọc · đổi ngôn ngữ · Lớp của tôi · Đăng xuất (sheet xác nhận).
/// Các mục chưa có API giữ trạng thái disabled.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const _disabledItems = [
    'account.orders', 'account.editProfile', 'account.certificates', 'account.attendance',
    'account.push', 'account.help', 'account.policy',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider).user;
    final locale = ref.watch(localeProvider);

    if (user == null) {
      return Scaffold(
        body: ScreenState(title: t('account.state.empty'), description: t('account.state.description')),
      );
    }

    Widget field(String label, String? value) => ListTile(
          title: Text(t(label), style: AppText.caption(AppColors.muted)),
          subtitle: Text(value ?? t('account.notUpdated'), style: AppText.label(AppColors.forest)),
        );

    return Scaffold(
      bottomNavigationBar: const AppTabBar(selected: HomeTab.account),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(t('account.title'), style: AppText.sectionTitle(AppColors.forest)),
            const SizedBox(height: 16),
            Center(
              child: Semantics(
                label: t('account.avatar', {'name': user.displayName}),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.mint,
                  child: Text(user.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.canvas)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t('account.profile'), style: AppText.title(AppColors.forest)),
            field('account.fields.displayName', user.displayName),
            field('account.fields.email', user.email),
            field('account.fields.phone', user.phone),
            field('account.fields.role', t('account.roles.${user.role.name}')),
            const Divider(),
            ListTile(
              leading: const MindyIcon(MindyIconName.folder),
              title: Text(t('myClasses.title')),
              onTap: () => context.push(Routes.myClasses('account')),
            ),
            ListTile(
              leading: const MindyIcon(MindyIconName.globe),
              title: Text(t('account.language')),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'vi', label: Text(t('account.languages.vi-VN'))),
                  ButtonSegment(value: 'en', label: Text(t('account.languages.en-EN'))),
                ],
                selected: {locale.languageCode},
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).change(Locale(s.first)),
              ),
            ),
            for (final key in _disabledItems)
              ListTile(
                enabled: false,
                title: Text(t(key)),
                subtitle: Text(t('account.unavailable')),
              ),
            const SizedBox(height: 16),
            MindyButton(
              label: t('account.logout'),
              variant: ButtonVariant.outline,
              icon: const MindyIcon(MindyIconName.logout, color: AppColors.black),
              onPressed: () => showAppSheet<void>(context, initialSize: 0.4, (_) => const _LogoutSheet()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet xác nhận đăng xuất. Logout lỗi thì báo lỗi, KHÔNG giả vờ thành công.
class _LogoutSheet extends ConsumerStatefulWidget {
  const _LogoutSheet();

  @override
  ConsumerState<_LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends ConsumerState<_LogoutSheet> {
  bool _pending = false;
  Object? _error;

  Future<void> _logout() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      // Thành công: router redirect về /login và tự gỡ sheet này, không cần pop.
      await ref.read(sessionProvider.notifier).logout();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(t('account.confirmLogout'), style: AppText.title(AppColors.forest)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ScreenState(title: t('auth.session.logout'), description: t('errors.generic'), requestId: requestIdOf(_error!)),
        ],
        const SizedBox(height: 16),
        MindyButton(label: t('account.logout'), loading: _pending, onPressed: _logout),
        const SizedBox(height: 8),
        MindyButton(
          label: t('learning.cancel'),
          variant: ButtonVariant.ghost,
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
