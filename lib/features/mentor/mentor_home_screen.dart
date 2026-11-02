import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/session/session_controller.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/ui/staff/staff_theme.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../../core/ui/staff/sym.dart';
import 'mentor_providers.dart';
import 'mentor_utilities.dart';

/// Home Mentor - `Mentor Mobile UI.html` (MF1: khung + tiện ích; dữ liệu lịch gắn ở MF2).
///
/// Header (avatar, tên, email, chuông) · thẻ buổi dạy · Tiện ích yêu thích (Sửa) ·
/// Tính năng gần đây · Tính năng mới. Thiết kế không có màn tài khoản nên chạm avatar
/// mở sheet Tài khoản để Đăng xuất.
class MentorHomeScreen extends ConsumerStatefulWidget {
  const MentorHomeScreen({super.key});

  @override
  ConsumerState<MentorHomeScreen> createState() => _MentorHomeScreenState();
}

class _MentorHomeScreenState extends ConsumerState<MentorHomeScreen> {
  bool _editing = false;

  bool get _substituteOnly => ref.watch(mentorSubstituteOnlyProvider).value ?? false;

  /// Mở tiện ích: trang con, hoặc báo cần mở từ buổi đang dạy (sheet ở MF2/MF3).
  void _open(MentorUtil u) {
    final t = ref.read(trProvider);
    if (u.sessionOnly) {
      showStaffToast(context, t('mentor.util.sessionOnly'));
      return;
    }
    context.push(Routes.mentorPage(u.name));
  }

  Future<void> _toggleFav(MentorUtil u) async {
    final t = ref.read(trProvider);
    final error = await ref.read(mentorFavoritesProvider.notifier).toggle(u);
    if (error != null && mounted) showStaffToast(context, t(error));
  }

  void _onTile(MentorUtil u) => _editing ? _toggleFav(u) : _open(u);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final user = ref.watch(sessionProvider).user;
    final chosen = ref.watch(mentorFavoritesProvider).value ?? const <MentorUtil>[];
    final favs = displayFavorites(chosen, substituteOnly: _substituteOnly);

    return Scaffold(
      body: StaffBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(mentorSubstituteOnlyProvider),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(t, user?.displayName ?? '', user?.email ?? ''),
              Transform.translate(offset: const Offset(0, -56), child: _nextSessionCard(t)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionTitle(
                    t('mentor.home.favorites'),
                    action: TextButton.icon(
                      onPressed: () => setState(() => _editing = !_editing),
                      icon: Icon(_editing ? Sym.check : Sym.edit, size: 18, color: StaffColors.teal600),
                      label: Text(_editing ? t('mentor.home.done') : t('mentor.home.edit'), style: StaffText.link),
                    ),
                  ),
                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(t('mentor.home.favCount', {'count': favs.length}), style: StaffText.small),
                    ),
                  Wrap(spacing: 4, runSpacing: 12, children: [
                    for (var i = 0; i < favs.length; i++)
                      UtilityTile(
                        icon: favs[i].icon,
                        label: t(favs[i].labelKey),
                        highlighted: i == 0 && !_editing,
                        mark: _editing && !fixedFavorites.contains(favs[i]) ? Sym.close : null,
                        onTap: () => _onTile(favs[i]),
                      ),
                    for (var i = favs.length; i < maxFavorites; i++) _emptySlot(t),
                  ]),
                  for (final (titleKey, items) in utilityGroups) ...[
                    const SizedBox(height: 24),
                    _sectionTitle(
                      t(titleKey),
                      action: TextButton(
                        onPressed: () => context.push(Routes.mentorUtilities),
                        child: Text(t('mentor.home.viewAll'), style: StaffText.link),
                      ),
                    ),
                    Wrap(spacing: 4, runSpacing: 16, children: [
                      for (final u in items.where((u) => isUtilVisible(u, substituteOnly: _substituteOnly)))
                        UtilityTile(
                          icon: u.icon,
                          label: t(u.labelKey),
                          isNew: u.isNew && !_editing,
                          mark: _editing ? _markFor(u, chosen) : null,
                          onTap: () => _onTile(u),
                        ),
                    ]),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _markFor(MentorUtil u, List<MentorUtil> chosen) =>
      fixedFavorites.contains(u) ? Sym.lock : (chosen.contains(u) ? Sym.check : Sym.add);

  Widget _header(Translator t, String name, String email) => StaffHeader(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        child: Row(children: [
          Pressable(
            onTap: () => _openAccount(t, name, email),
            semanticLabel: t('mentor.account.title'),
            child: InitialsAvatar(name: name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: StaffText.title.copyWith(color: Colors.white)),
              Text(email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StaffText.caption.copyWith(color: StaffColors.onTealMuted)),
            ]),
          ),
          // Chuông: danh sách thông báo gắn API ở MF2
          IconButton(
            tooltip: t('mentor.notifications'),
            onPressed: () => showStaffToast(context, t('staff.comingSoon')),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x33FFFFFF),
              side: const BorderSide(color: Color(0x59FFFFFF)),
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Sym.notifications, color: Colors.white),
          ),
        ]),
      );

  /// MF2 sẽ thay bằng buổi tiếp theo thật (`/mentor/schedule` + `/class-sessions/:id/context`).
  Widget _nextSessionCard(Translator t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(clipBehavior: Clip.none, children: [
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(t('mentor.home.nextTitle'), style: StaffText.title)),
                TextButton(
                  onPressed: () => context.push(Routes.mentorPage(MentorUtil.schedule.name)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t('mentor.home.viewSchedule'), style: StaffText.link),
                    const Icon(Sym.chevronRight, size: 18, color: StaffColors.teal600),
                  ]),
                ),
              ]),
              const SizedBox(height: 4),
              Text(t('mentor.home.nextDescription'), style: StaffText.caption),
            ]),
          ),
          Positioned(
            left: -14,
            top: -54,
            child: ExcludeSemantics(child: Image.asset('assets/illustrations/mindy-frog-peek.png', width: 112)),
          ),
        ]),
      );

  Widget _sectionTitle(String title, {Widget? action}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: StaffText.section)),
          ?action,
        ]),
      );

  Widget _emptySlot(Translator t) => Pressable(
        onTap: () => setState(() => _editing = true),
        semanticLabel: t('mentor.home.edit'),
        child: SizedBox(
          width: 76,
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: StaffColors.faint, style: BorderStyle.solid),
              ),
              child: const Icon(Sym.add, color: StaffColors.subtle),
            ),
          ),
        ),
      );

  void _openAccount(Translator t, String name, String email) =>
      openStaffSheet(context, title: t('mentor.account.title'), builder: (_) => _AccountSheet(name: name, email: email));
}

/// Sheet Tài khoản: thông tin + Đăng xuất. Logout lỗi thì báo, không giả vờ thành công.
class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.name, required this.email});
  final String name;
  final String email;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  bool _pending = false;
  Object? _error;

  Future<void> _logout() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      // Thành công: router chuyển về /login và gỡ sheet này
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        InitialsAvatar(name: widget.name, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name, style: StaffText.bodyStrong),
            Text(widget.email, style: StaffText.caption),
          ]),
        ),
        StatusChip(t('mentor.roleChip')),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          requestIdOf(_error!) == null
              ? t('mentor.account.logoutError')
              : '${t('mentor.account.logoutError')}\n${t('common.requestId', {'id': requestIdOf(_error!)})}',
          style: StaffText.label.copyWith(color: StaffColors.redFg),
        ),
      ],
      const SizedBox(height: 20),
      StaffButton(label: t('mentor.account.logout'), icon: Sym.logout, loading: _pending, onPressed: _logout),
    ]);
  }
}
