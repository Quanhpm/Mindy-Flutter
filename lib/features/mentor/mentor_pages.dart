import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/ui/staff/staff_theme.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../../core/ui/staff/sym.dart';
import 'mentor_providers.dart';
import 'mentor_utilities.dart';

/// "Tất cả tiện ích" (P10): tìm kiếm, nhóm, gắn sao yêu thích.
class MentorUtilitiesScreen extends ConsumerStatefulWidget {
  const MentorUtilitiesScreen({super.key});

  @override
  ConsumerState<MentorUtilitiesScreen> createState() => _MentorUtilitiesScreenState();
}

class _MentorUtilitiesScreenState extends ConsumerState<MentorUtilitiesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final substituteOnly = ref.watch(mentorSubstituteOnlyProvider).value ?? false;
    final chosen = ref.watch(mentorFavoritesProvider).value ?? const <MentorUtil>[];
    final favs = displayFavorites(chosen, substituteOnly: substituteOnly);
    final q = _q.trim().toLowerCase();

    final groups = [
      for (final (titleKey, items) in utilityGroups)
        (
          titleKey,
          items
              .where((u) => isUtilVisible(u, substituteOnly: substituteOnly))
              .where((u) => q.isEmpty || t(u.labelKey).toLowerCase().contains(q))
              .toList(),
        ),
    ].where((g) => g.$2.isNotEmpty).toList();
    final total = utilityGroups
        .expand((g) => g.$2)
        .where((u) => isUtilVisible(u, substituteOnly: substituteOnly))
        .length;

    return StaffPage(
      title: t('mentor.utilities.title'),
      subtitle: t('mentor.utilities.count', {'count': total}),
      headerExtra: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          style: StaffText.body,
          decoration: InputDecoration(
            hintText: t('mentor.utilities.search'),
            hintStyle: StaffText.body.copyWith(color: StaffColors.faint),
            prefixIcon: const Icon(Sym.search, color: StaffColors.muted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
          ),
        ),
      ),
      body: groups.isEmpty
          ? Center(child: Text(t('mentor.utilities.empty'), style: StaffText.caption))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
              children: [
                for (final (titleKey, items) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text(t(titleKey).toUpperCase(), style: StaffText.eyebrow),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final u in items) _row(t, u, favs.contains(u)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _row(Translator t, MentorUtil u, bool fav) => ListTile(
        onTap: () => u.sessionOnly
            ? showStaffToast(context, t('mentor.util.sessionOnly'))
            : context.push(Routes.mentorPage(u.name)),
        leading: CircleAvatar(
          backgroundColor: StaffColors.tealSoft,
          child: Icon(u.icon, color: StaffColors.teal600),
        ),
        title: Text(t(u.labelKey), style: StaffText.body),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (u.isNew) StatusChip(t('mentor.utilities.newBadge'), tone: StatusTone.red),
          IconButton(
            tooltip: t('mentor.home.favorites'),
            onPressed: () async {
              final error = await ref.read(mentorFavoritesProvider.notifier).toggle(u);
              if (error != null && mounted) showStaffToast(context, t(error));
            },
            icon: Icon(Sym.star, fill: fav ? 1 : 0, color: fav ? StaffColors.star : StaffColors.faint),
          ),
        ]),
      );
}

/// Trang tạm cho tiện ích chưa làm (MF2–MF5). Tiêu đề đúng tên tiện ích để duyệt luồng điều hướng.
class MentorPlaceholderPage extends ConsumerWidget {
  const MentorPlaceholderPage({super.key, required this.utilKey});
  final String utilKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final u = MentorUtil.byName(utilKey);
    return StaffPage(
      title: u == null ? t('staff.comingSoon') : t(u.labelKey),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: GlassCard(
            child: Row(children: [
              Icon(u?.icon ?? Sym.info, size: 32, color: StaffColors.teal600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('staff.comingSoon'), style: StaffText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(t('staff.comingSoonDescription', {'phase': u?.phase ?? '—'}), style: StaffText.caption),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
