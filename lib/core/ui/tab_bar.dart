import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'icon.dart';
import 'pressable.dart';

/// Thanh tab đáy 5 ô, nút Home tròn nổi ở giữa - `components/common/AppTabBar.tsx`.
/// `notifications` luôn disabled (chưa có API).
class AppTabBar extends ConsumerWidget {
  const AppTabBar({super.key, required this.selected, this.onHomeTop});

  final HomeTab selected;

  /// Bấm Home khi đang ở Home: cuộn lên đầu.
  final VoidCallback? onHomeTop;

  static const _icons = {
    HomeTab.courses: MindyIconName.grid,
    HomeTab.schedule: MindyIconName.calendar,
    HomeTab.home: MindyIconName.home,
    HomeTab.notifications: MindyIconName.bell,
    HomeTab.account: MindyIconName.user,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final mq = MediaQuery.of(context);
    final roomy = mq.size.width <= 360 || mq.textScaler.scale(1) >= 1.3;
    final barH = roomy ? 88.0 : 68.0;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barH + 28,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: barH,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [BoxShadow(color: Color(0x331D5B57), blurRadius: 24, offset: Offset(0, 8))],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final tab in HomeTab.values)
                  Expanded(
                    child: tab == HomeTab.home
                        ? _homeButton(context, t)
                        : SizedBox(height: barH, child: Center(child: _tab(context, t, tab, roomy))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeButton(BuildContext context, Translator t) {
    final active = selected == HomeTab.home;
    return Align(
      alignment: Alignment.topCenter,
      child: Pressable(
        semanticLabel: t('home.tabs.home'),
        selected: active,
        onTap: () => active ? onHomeTop?.call() : goTab(context, HomeTab.home),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.action : AppColors.mint,
            border: Border.all(color: AppColors.canvas, width: 6),
            boxShadow: const [BoxShadow(color: Color(0x4D1D5B57), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: const Center(child: MindyIcon(MindyIconName.home, size: 30, color: AppColors.canvas)),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, Translator t, HomeTab tab, bool roomy) {
    final active = tab == selected;
    final enabled = tab != HomeTab.notifications;
    final fg = active ? AppColors.canvas : AppColors.muted;
    return Pressable(
      semanticLabel: t('home.tabs.${tab.name}'),
      selected: active,
      onTap: enabled ? () => goTab(context, tab) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.mint : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MindyIcon(_icons[tab]!, size: 20, color: fg),
              const SizedBox(height: 3),
              Text(
                t('home.tabs.${tab.name}'),
                maxLines: roomy ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
