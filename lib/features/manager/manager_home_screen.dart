import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session/session_controller.dart';
import 'collections/collections_providers.dart';
import 'leave/leave_providers.dart';
import 'materials/materials_api.dart';
import 'materials/materials_providers.dart';
import 'manager_providers.dart';
import 'manager_widgets.dart';

String managerUtilityRoute(ManagerUtility utility) => switch (utility) {
  ManagerUtility.leaves => Routes.managerLeaves,
  ManagerUtility.materials => Routes.managerMaterials,
  ManagerUtility.collections => Routes.managerCollections,
  ManagerUtility.classes => Routes.managerClasses,
  ManagerUtility.mentors => Routes.managerPeople('MENTOR'),
  ManagerUtility.students => Routes.managerPeople('STUDENT'),
  ManagerUtility.incomplete => Routes.managerIncomplete,
  ManagerUtility.reports => Routes.managerReports,
  ManagerUtility.makeup => Routes.managerMakeup,
};
void refreshManagerHome(WidgetRef ref) {
  ref.invalidate(managerLeaveCountProvider);
  ref.invalidate(managerMaterialCountProvider);
  ref.invalidate(managerCashCountProvider);
}

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key});
  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends ConsumerState<ManagerHomeScreen> with WidgetsBindingObserver {
  bool _editing = false, _wasCurrent = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)) {
        refreshManagerHome(ref);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && ModalRoute.of(context)?.isCurrent == true) {
      refreshManagerHome(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        user = ref.watch(sessionProvider).user,
        fav = ref.watch(managerFavoritesProvider),
        current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshManagerHome(ref);
      });
    }
    _wasCurrent = current;
    return Scaffold(
      body: StaffBackground(
        child: RefreshIndicator(
          onRefresh: () async => refreshManagerHome(ref),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              StaffHeader(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 64),
                child: TextButton(
                  onPressed: () => showStaffSheet<void>(
                    context,
                    title: t('manager.account'),
                    builder: (_) => const SessionSheetGuard(child: SessionBoundView(child: ManagerAccountSheet())),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(name: user?.displayName ?? '', size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '',
                              style: StaffText.bodyStrong.copyWith(color: StaffColors.surface),
                            ),
                            Text(t('manager.role'), style: StaffText.caption.copyWith(color: StaffColors.onTealMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text(t('manager.workQueue'), style: StaffText.title),
                    _CountCard(
                      title: t('manager.pendingLeaves'),
                      value: ref.watch(managerLeaveCountProvider),
                      onRetry: () => ref.invalidate(managerLeaveCountProvider),
                      onTap: () => context.push(Routes.managerLeaves),
                    ),
                    for (final status in MaterialReviewStatus.values.where((s) => s != MaterialReviewStatus.REJECTED))
                      _CountCard(
                        title: t('manager.materialCount.${status.name}'),
                        value: ref.watch(managerMaterialCountProvider(status)),
                        onRetry: () => ref.invalidate(managerMaterialCountProvider(status)),
                        onTap: () => context.push('${Routes.managerMaterials}?status=${status.name}'),
                      ),
                    _CountCard(
                      title: t('manager.pendingCash'),
                      value: ref.watch(managerCashCountProvider),
                      onRetry: () => ref.invalidate(managerCashCountProvider),
                      onTap: () => context.push(Routes.managerCollections),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text(t('manager.favorites'), style: StaffText.section)),
                        TextButton(
                          onPressed: () => setState(() => _editing = !_editing),
                          child: Text(t(_editing ? 'manager.done' : 'manager.edit')),
                        ),
                      ],
                    ),
                    if (fav.hasError) managerFailure(t, fav.error!),
                    Wrap(
                      spacing: 4,
                      runSpacing: 12,
                      children: [
                        for (final u in fav.value ?? managerFixedFavorites)
                          UtilityTile(
                            icon: u.icon,
                            label: t(u.labelKey),
                            mark: _editing && !managerFixedFavorites.contains(u) ? Icons.close : null,
                            onTap: () => _editing
                                ? ref.read(managerFavoritesProvider.notifier).toggle(u)
                                : context.push(managerUtilityRoute(u)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Text(t('manager.utilities'), style: StaffText.section)),
                        TextButton(
                          onPressed: () => context.push(Routes.managerUtilities),
                          child: Text(t('manager.viewAll')),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 16,
                      children: [
                        for (final u in ManagerUtility.values)
                          UtilityTile(
                            icon: u.icon,
                            label: t(u.labelKey),
                            mark: _editing
                                ? (fav.value ?? managerFixedFavorites).contains(u)
                                      ? Icons.star
                                      : Icons.star_border
                                : null,
                            onTap: () => _editing
                                ? ref.read(managerFavoritesProvider.notifier).toggle(u)
                                : context.push(managerUtilityRoute(u)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCard extends ConsumerWidget {
  const _CountCard({required this.title, required this.value, required this.onRetry, required this.onTap});
  final String title;
  final AsyncValue<int> value;
  final VoidCallback onRetry, onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: GlassCard(
      onTap: onTap,
      child: ManagerData(
        value: value,
        onRetry: onRetry,
        data: (count) => Row(
          children: [
            Expanded(child: Text(title, style: StaffText.bodyStrong)),
            const SizedBox(width: 12),
            Text('$count', style: StaffText.title),
          ],
        ),
      ),
    ),
  );
}

class ManagerUtilitiesScreen extends ConsumerWidget {
  const ManagerUtilitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return StaffPage(
      title: t('manager.utilities'),
      onBack: () => managerBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          for (final u in ManagerUtility.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => context.push(managerUtilityRoute(u)),
                child: Row(
                  children: [
                    Icon(u.icon, color: StaffColors.teal700),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t(u.labelKey), style: StaffText.bodyStrong)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ManagerAccountSheet extends ConsumerStatefulWidget {
  const ManagerAccountSheet({super.key});
  @override
  ConsumerState<ManagerAccountSheet> createState() => _AccountState();
}

class _AccountState extends ConsumerState<ManagerAccountSheet> {
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider), u = ref.watch(sessionProvider).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(u?.displayName ?? '', style: StaffText.title),
        SelectableText(u?.email ?? '', style: StaffText.body),
        Text(t('manager.role'), style: StaffText.caption),
        if (u?.phone != null) SelectableText(u!.phone!, style: StaffText.body),
        const SizedBox(height: 20),
        if (_error != null) managerFailure(t, _error!),
        StaffButton(
          label: t('manager.logout'),
          loading: _busy,
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await ref.read(sessionProvider.notifier).logout();
                  } catch (e) {
                    if (mounted) setState(() => _error = e);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ],
    );
  }
}
