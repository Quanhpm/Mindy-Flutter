import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import 'icon.dart';
import 'pressable.dart';

/// Header brand mint - `components/common/BrandBar.tsx`.
/// Row: ô trống 44 | giữa tên brand (bấm về đầu) | nút giỏ hàng 44×44.
class BrandBar extends ConsumerWidget {
  const BrandBar({
    super.key,
    required this.onTop,
    this.onCart,
    this.compact = false,
    this.prefix = 'home',
    this.cartCount = 0,
  });

  final VoidCallback? onTop;
  final VoidCallback? onCart;
  final bool compact;
  final String prefix;
  final int cartCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);

    final logoKey = Key(compact ? 'home-compact-logo' : 'home-logo');
    final cartKey = Key(
      prefix == 'home'
          ? (compact ? 'home-compact-cart-button' : 'home-cart-button')
          : 'courses-cart-button',
    );
    final badgeKey = Key(compact ? 'home-compact-cart-badge' : '$prefix-cart-badge');

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Center(
              child: Pressable(
                key: logoKey,
                onTap: onTop,
                semanticLabel: t('home.tabs.home'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('home.brand.name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 19 / 19,
                          letterSpacing: -0.19,
                          color: AppColors.canvas,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('home.brand.subtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          height: 11 / 10.5,
                          letterSpacing: 2.52,
                          color: AppColors.sunshine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Pressable(
            key: cartKey,
            onTap: onCart,
            semanticLabel: t('home.actions.cart'),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const MindyIcon(MindyIconName.cart, size: 22, color: AppColors.canvas),
                  if (cartCount > 0)
                    Positioned(
                      right: 2,
                      top: 4,
                      child: Container(
                        key: badgeKey,
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          border: Border.all(color: AppColors.mint, width: 2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          cartCount > 9 ? '9+' : '$cartCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
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
