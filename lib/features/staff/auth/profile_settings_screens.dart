import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_user.dart';
import '../../../core/ui/mdy/mdy.dart';
import 'account_page.dart';

void _back(BuildContext context, SessionUser user) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(user.role == Role.MANAGER ? '/manager' : '/mentor');
  }
}

/// Clone `screens/ProfileScreen.tsx`.
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    final c = context.mdy;
    return StaffAccountPage(
      page: 'profile',
      title: t('mdy.foundation.profileTitle'),
      subtitle: t('mdy.foundation.profileSubtitle'),
      onBack: () => _back(context, user),
      children: [
        MdyCard(
          center: true,
          margin: EdgeInsets.zero,
          gap: MdySpace.s10,
          children: [
            MdyAvatar(key: const Key('profile-avatar'), name: user.displayName, profile: true),
            Text(
              user.displayName,
              key: const Key('profile-name'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MdyType.size(18, MdyType.w600).copyWith(color: c.ink),
            ),
            Text(
              user.email,
              key: const Key('profile-email'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MdyType.size(13).copyWith(color: c.secondary),
            ),
            Container(
              key: const Key('profile-role-chip'),
              constraints: const BoxConstraints(minHeight: MdySpace.s24),
              padding: const EdgeInsets.symmetric(horizontal: MdySpace.s10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(MdyRadius.r99)),
              child: Text(
                t(user.role == Role.MENTOR ? 'mdy.foundation.MENTOR' : 'mdy.foundation.MANAGER'),
                style: MdyType.size(12, MdyType.w600).copyWith(color: c.primary),
              ),
            ),
          ],
        ),
        StaffAccountGroup(
          label: t('mdy.foundation.profileInfo'),
          children: [
            StaffAccountList(
              children: [
                _InformationRow(
                  key: const Key('profile-info-email'),
                  icon: MdyIcons.mail,
                  label: t('mdy.foundation.email'),
                  value: user.email,
                ),
                _InformationRow(
                  key: const Key('profile-info-phone'),
                  icon: MdyIcons.call,
                  label: t('mdy.foundation.phone'),
                  value: (user.phone ?? '').isEmpty ? t('mdy.foundation.phoneEmpty') : user.phone!,
                  empty: (user.phone ?? '').isEmpty,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({super.key, required this.icon, required this.label, required this.value, this.empty = false});
  final MdyIcons icon;
  final String label;
  final String value;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Padding(
      padding: const EdgeInsets.all(MdySpace.s10),
      child: Row(
        spacing: MdySpace.s12,
        children: [
          Container(
            width: MdySpace.s40,
            height: MdySpace.s40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.tint2, shape: BoxShape.circle),
            child: MdyIcon(icon, size: 20, color: c.link),
          ),
          Expanded(
            child: Semantics(
              label: '$label, $value',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MdyType.size(12).copyWith(color: c.secondary)),
                  SelectableText(
                    value,
                    style: empty
                        ? MdyType.size(14).copyWith(color: c.secondary)
                        : MdyType.size(14, MdyType.w500).copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clone `screens/SettingsScreen.tsx`: ngôn ngữ, giao diện sáng/tối/hệ thống, đăng xuất 1 / mọi phiên.
class StaffSettingsScreen extends ConsumerStatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  ConsumerState<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends ConsumerState<StaffSettingsScreen> {
  bool _busy = false;

  void _toast(String text) => ref.read(mdyToastProvider.notifier).show(text);

  Future<void> _language(String code) async {
    if (ref.read(localeProvider).languageCode == code) return;
    await ref.read(localeProvider.notifier).change(Locale(code));
    if (!mounted) return;
    _toast(ref.read(trProvider)('mdy.foundation.languageChanged'));
  }

  void _appearance(MdyThemeChoice value) {
    if (ref.read(mdyThemeChoiceProvider) == value) return;
    ref.read(mdyThemeChoiceProvider.notifier).change(value);
    final t = ref.read(trProvider);
    _toast(t('mdy.foundation.themeChanged', {'name': t('mdy.foundation.${value.name}')}));
  }

  Future<void> _confirm(SessionUser user, bool all) async {
    await showMdyDialog<void>(
      context,
      builder: (dialogContext) => _LogoutDialog(
        all: all,
        email: user.email,
        onBusy: (value) {
          if (mounted) setState(() => _busy = value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    final language = ref.watch(localeProvider).languageCode;
    final choice = ref.watch(mdyThemeChoiceProvider);
    final c = context.mdy;
    return StaffAccountPage(
      page: 'settings',
      title: t('mdy.foundation.settingsTitle'),
      subtitle: t('mdy.foundation.settingsSubtitle'),
      busy: _busy,
      onBack: () => _back(context, user),
      children: [
        StaffAccountGroup(
          top: false,
          label: t('mdy.foundation.language'),
          children: [
            StaffAccountList(
              children: [
                MdyRow(
                  key: const Key('settings-language-vi'),
                  compact: true,
                  code: 'VI',
                  label: 'Tiếng Việt',
                  subtitle: t('mdy.foundation.languageViSub'),
                  checked: language == 'vi',
                  onPress: () => _language('vi'),
                ),
                MdyRow(
                  key: const Key('settings-language-en'),
                  compact: true,
                  code: 'EN',
                  label: 'English',
                  subtitle: t('mdy.foundation.languageEnSub'),
                  checked: language == 'en',
                  onPress: () => _language('en'),
                ),
              ],
            ),
          ],
        ),
        StaffAccountGroup(
          label: t('mdy.foundation.appearance'),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MdySpace.s8,
              children: [
                for (final value in const [MdyThemeChoice.light, MdyThemeChoice.dark, MdyThemeChoice.system])
                  Expanded(
                    child: MdyThemeCard(
                      value: value,
                      label: t('mdy.foundation.${value.name}'),
                      checked: choice == value,
                      onPress: () => _appearance(value),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MdySpace.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MdySpace.s6,
                children: [
                  MdyIcon(MdyIcons.info, size: 16, color: c.link),
                  Expanded(
                    child: Text(
                      t(choice == MdyThemeChoice.system ? 'mdy.foundation.themeNoteSystem' : 'mdy.foundation.themeNoteFixed'),
                      key: const Key('settings-theme-note'),
                      style: MdyType.size(12, MdyType.w400, 18).copyWith(color: c.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        StaffAccountGroup(
          label: t('mdy.foundation.sessions'),
          children: [
            StaffAccountList(
              children: [
                MdyRow(
                  key: const Key('settings-logout-row'),
                  compact: true,
                  chevron: false,
                  icon: MdyIcons.logout,
                  label: t('mdy.foundation.logout'),
                  subtitle: t('mdy.foundation.logoutSub'),
                  onPress: () => _confirm(user, false),
                ),
                MdyRow(
                  key: const Key('settings-logout-all-row'),
                  compact: true,
                  chevron: false,
                  icon: MdyIcons.devices,
                  label: t('mdy.foundation.logoutAll'),
                  subtitle: t('mdy.foundation.logoutAllSub'),
                  danger: true,
                  onPress: () => _confirm(user, true),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _LogoutDialog extends ConsumerStatefulWidget {
  const _LogoutDialog({required this.all, required this.email, required this.onBusy});
  final bool all;
  final String email;
  final ValueChanged<bool> onBusy;

  @override
  ConsumerState<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends ConsumerState<_LogoutDialog> {
  bool _busy = false;
  bool _error = false;

  Future<void> _submit() async {
    final t = ref.read(trProvider);
    final toast = ref.read(mdyToastProvider.notifier);
    final session = ref.read(sessionProvider.notifier);
    setState(() {
      _busy = true;
      _error = false;
    });
    widget.onBusy(true);
    try {
      await session.logout(all: widget.all);
      toast.show(t(widget.all ? 'mdy.foundation.signedOutAll' : 'mdy.foundation.signedOut'));
    } catch (_) {
      // Phiên đã hết hạn trong lúc gửi: router đã đưa về Login, không báo lỗi.
      if (ref.read(sessionProvider).user == null) return;
      if (mounted) setState(() => _error = true);
    } finally {
      widget.onBusy(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final all = widget.all;
    return MdyConfirmationDialog(
      key: const Key('logout-sheet'),
      title: t(all ? 'mdy.foundation.logoutAllTitle' : 'mdy.foundation.logoutTitle'),
      icon: all ? MdyIcons.devices : MdyIcons.logout,
      busy: _busy,
      children: [
        Transform.translate(
          offset: const Offset(0, -MdySpace.s8),
          child: Text(
            t(all ? 'mdy.foundation.logoutAllBody' : 'mdy.foundation.logoutBody', {'email': widget.email}),
            textAlign: TextAlign.center,
            style: MdyType.text.copyWith(color: c.secondary),
          ),
        ),
        if (_error) MdyAlert(t('mdy.foundation.logoutError'), key: const Key('logout-sheet-error')),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MdySpace.s8,
          children: [
            MdyButton(
              key: const Key('logout-sheet-confirm'),
              variant: MdyButtonVariant.danger,
              busy: _busy,
              label: t(_busy ? 'mdy.foundation.loggingOut' : (all ? 'mdy.foundation.logoutAll' : 'mdy.foundation.logout')),
              onPressed: _submit,
            ),
            MdyButton(
              key: const Key('logout-sheet-cancel'),
              variant: MdyButtonVariant.secondary,
              borderColor: c.disabled,
              foreground: c.primary,
              disabled: _busy,
              label: t('mdy.foundation.cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
