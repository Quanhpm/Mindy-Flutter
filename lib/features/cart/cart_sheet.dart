import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import 'cart_controller.dart';
import 'cart_models.dart';

/// Mở giỏ hàng. Checkout thành công -> đóng sheet, mở màn Thanh toán.
Future<void> showCartSheet(BuildContext context) async {
  final router = GoRouter.of(context);
  final orderId = await showAppSheet<String>(context, (_) => const CartSheet());
  if (orderId != null) router.push(Routes.payment(orderId));
}

/// `cart/components/CartSheet.tsx` + `hooks/useCartController.ts`.
/// TODO(UI): port ảnh lớp, badge giá đổi, layout tổng tiền cố định đáy.
class CartSheet extends ConsumerStatefulWidget {
  const CartSheet({super.key});

  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  bool _busy = false; // khoá mọi thao tác khi đang chạy (chống bấm lặp)
  String? _removingId;
  bool _checkingOut = false;
  String? _error;
  List<String>? _unknownClassIds; // checkout mất response

  @override
  void initState() {
    super.initState();
    // Luôn hiện giỏ thật của server khi mở sheet
    Future.microtask(() => ref.read(cartProvider.notifier).refresh().catchError((_) => Cart.empty));
  }

  Future<void> _guard(Future<void> Function() task) async {
    if (_busy) return;
    _busy = true;
    try {
      await task();
    } finally {
      _busy = false;
    }
  }

  Future<void> _remove(String classId) => _guard(() async {
        final t = ref.read(trProvider);
        setState(() {
          _removingId = classId;
          _error = null;
        });
        try {
          await ref.read(cartProvider.notifier).remove(classId);
        } catch (e) {
          if (mounted) setState(() => _error = t(cartErrorKey(e)));
        } finally {
          await ref.read(cartProvider.notifier).refresh().catchError((_) => Cart.empty);
          if (mounted) setState(() => _removingId = null);
        }
      });

  Future<void> _checkout() => _guard(() async {
        final t = ref.read(trProvider);
        if (_unknownClassIds != null) return;
        setState(() {
          _checkingOut = true;
          _error = null;
        });
        try {
          final orderId = await ref.read(cartProvider.notifier).checkout();
          if (mounted) Navigator.of(context).pop(orderId);
        } on CheckoutUnknown catch (u) {
          if (mounted) setState(() => _unknownClassIds = u.classIds);
        } catch (e) {
          if (mounted) setState(() => _error = t(cartErrorKey(e)));
        } finally {
          if (mounted) setState(() => _checkingOut = false);
        }
      });

  Future<void> _verify() => _guard(() async {
        final t = ref.read(trProvider);
        setState(() {
          _checkingOut = true;
          _error = null;
        });
        try {
          final orderId = await ref.read(cartProvider.notifier).verifyCheckout(_unknownClassIds!);
          if (!mounted) return;
          if (orderId != null) {
            Navigator.of(context).pop(orderId);
            return;
          }
          final latest = ref.read(cartProvider).value ?? Cart.empty;
          setState(() {
            _unknownClassIds = null;
            if (latest.items.isEmpty) _error = t('cart.errors.generic');
          });
        } catch (_) {
          if (mounted) setState(() => _error = t('cart.errors.generic'));
        } finally {
          if (mounted) setState(() => _checkingOut = false);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final cart = ref.watch(cartProvider);

    return RegionColors.cart(
      child: AsyncView(
        value: cart,
        onRetry: () => ref.invalidate(cartProvider),
        data: (c) => ListView(
          controller: PrimaryScrollController.of(context),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(t('cart.title', {'count': c.items.length}), style: AppText.title(AppColors.black)),
            const SizedBox(height: 16),
            if (c.items.isEmpty) Text(t('cart.empty'), style: AppText.body(AppColors.black)),
            for (final item in c.items) _row(t, item),
            if (c.items.any((i) => !i.isPurchasable))
              Text(t('cart.errors.unavailable'), style: const TextStyle(color: AppColors.headsup)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.headsup, fontWeight: FontWeight.w700)),
              ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(child: Text(t('cart.total'), style: AppText.label(AppColors.black))),
                Text(formatVnd(c.totalAmount), style: AppText.title(AppColors.black)),
              ],
            ),
            const SizedBox(height: 16),
            if (_unknownClassIds != null) ...[
              Text(t('cart.checkoutUnknown'), style: const TextStyle(color: AppColors.headsup)),
              const SizedBox(height: 8),
              MindyButton(label: t('cart.checkoutVerify'), loading: _checkingOut, onPressed: _verify),
            ] else
              MindyButton(
                label: _checkingOut ? t('cart.checkoutPending') : t('cart.checkout'),
                loading: _checkingOut,
                onPressed: c.items.isEmpty || c.items.any((i) => !i.isPurchasable) ? null : _checkout,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(Translator t, CartItem item) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.courseTitle, style: AppText.label(AppColors.black)),
                  Text(
                    t('cart.item.meta', {
                      'name': item.className,
                      'mode': t('home.delivery.${item.deliveryMode.name}'),
                      'date': Dates.dateOnly(item.startDate),
                    }),
                    style: AppText.caption(AppColors.black),
                  ),
                  Text(formatVnd(item.currentPriceAmount), style: AppText.label(AppColors.black)),
                  if (item.priceChanged)
                    Text(t('cart.item.priceChanged'), style: const TextStyle(color: AppColors.statusYellow)),
                  if (!item.isPurchasable)
                    Text(t('cart.item.unavailable'), style: const TextStyle(color: AppColors.headsup)),
                ],
              ),
            ),
            TextLink(
              t('cart.item.remove'),
              onTap: _removingId != null || _checkingOut ? null : () => _remove(item.classId),
            ),
          ],
        ),
      );
}
