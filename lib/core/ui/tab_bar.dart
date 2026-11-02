import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'icon.dart';
import 'pressable.dart';

/// Thanh tab 5 ô - port từ `components/common/AppTabBar.tsx`.
/// Bỏ SafeArea bên trong:
/// - Màn Home / Courses đặt nổi: `Positioned(left: 12, right: 12, bottom: max(insets.bottom - 12, 0))`
/// - LearningLayout đặt trong luồng ở cuối màn hình.
class AppTabBar extends ConsumerWidget {
  const AppTabBar({
    super.key,
    this.selected = HomeTab.home,
    this.onTab,
    this.onTop,
    this.onHomeTop,
    this.prefix = 'home',
    this.learningEnabled = false,
  });

  final HomeTab selected;
  final void Function(HomeTab tab)? onTab;
  final VoidCallback? onTop;

  /// Tương thích ngược: nếu truyền onHomeTop thì dùng làm onTop khi ở Home.
  final VoidCallback? onHomeTop;
  final String prefix;
  final bool learningEnabled;

  static const _icons = {
    HomeTab.courses: MindyIconName.grid,
    HomeTab.schedule: MindyIconName.calendar,
    HomeTab.home: MindyIconName.home,
    HomeTab.notifications: MindyIconName.bell,
    HomeTab.account: MindyIconName.user,
  };

  bool _isEnabled(HomeTab id) {
    if (id == HomeTab.home) return true;
    if (id == HomeTab.notifications) return false;
    final hasOnTab = onTab != null;
    if (id == HomeTab.courses) return hasOnTab;
    return hasOnTab && learningEnabled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final mq = MediaQuery.of(context);
    final roomy = learningEnabled && (mq.size.width <= 360 || mq.textScaler.scale(1) >= 1.3);

    final totalH = roomy ? 116.0 : 96.0;
    final barH = roomy ? 88.0 : 68.0;

    final handleTop = onTop ?? onHomeTop ?? () => goTab(context, HomeTab.home);

    return SizedBox(
      height: totalH,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Nền tab bar bo 26, shadow-xl forest/20
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barH,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3312302E), // forest-deep @ 20%
                    blurRadius: 25,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final tab in HomeTab.values)
                  Expanded(
                    child: tab == HomeTab.home
                        ? SizedBox(
                            height: totalH,
                            child: Center(
                              child: _homeButton(context, t, handleTop),
                            ),
                          )
                        : SizedBox(
                            height: barH,
                            child: Center(
                              child: _tabButton(context, t, tab, roomy),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeButton(BuildContext context, Translator t, VoidCallback handleTop) {
    final active = selected == HomeTab.home;
    return Pressable(
      key: Key('$prefix-tab-home'),
      semanticLabel: t('home.tabs.home'),
      selected: active,
      onTap: handleTop,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.action : AppColors.mint,
          border: Border.all(color: AppColors.canvas, width: 6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D12302E), // forest-deep @ 30%
              blurRadius: 15,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: MindyIcon(MindyIconName.home, size: 30, color: AppColors.canvas),
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, Translator t, HomeTab tab, bool roomy) {
    final active = tab == selected;
    final enabled = _isEnabled(tab);
    final fg = active ? AppColors.canvas : AppColors.muted;

    return Pressable(
      key: Key('$prefix-tab-${tab.name}'),
      semanticLabel: t('home.tabs.${tab.name}'),
      selected: active,
      onTap: enabled
          ? () {
              if (onTab != null) {
                onTab!(tab);
              } else {
                goTab(context, tab);
              }
            }
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.mint : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MindyIcon(_icons[tab]!, size: 20, color: fg),
            const SizedBox(height: 3),
            Text(
              t('home.tabs.${tab.name}'),
              maxLines: roomy ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
