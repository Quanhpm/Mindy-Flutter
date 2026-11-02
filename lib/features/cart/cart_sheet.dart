import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import '../../core/ui/cover_image.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/states.dart';
import '../../core/utils/format.dart';
import '../courses/courses_providers.dart';
import 'cart_controller.dart';
import 'cart_models.dart';

/// Mở bottom sheet giỏ hàng.
Future<void> showCartSheet(BuildContext context) async {
  final router = GoRouter.of(context);
  final orderId = await showAppSheet<String>(context, (_) => const CartSheet());
  if (orderId != null) router.push(Routes.payment(orderId));
}

/// Bottom sheet giỏ hàng - port từ `CartSheet.tsx`.
class CartSheet extends ConsumerStatefulWidget {
  const CartSheet({super.key});

  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  bool _busy = false;
  String? _removingId;
  bool _checkingOut = false;
  String? _error;

  List<String>? get _unknownClassIds => ref.read(checkoutPendingProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).refresh().catchError((_) => Cart.empty));
  }

  Future<void> _guard(Future<void> Function() task) async {
    if (_busy) return;
    _busy = true;
    try {
      await task();
    } finally {
      if (mounted) _busy = false;
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
          if (mounted) {
            await ref.read(cartProvider.notifier).refresh().catchError((_) => Cart.empty);
            setState(() => _removingId = null);
          }
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
        } on CheckoutUnknown {
          if (mounted) setState(() => _error = null);
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
    final cartAsync = ref.watch(cartProvider);
    ref.watch(checkoutPendingProvider);

    return RegionColors.cart(
      child: SingleChildScrollView(
        controller: PrimaryScrollController.maybeOf(context),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          key: const Key('cart-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('cart.title', {'count': cartAsync.value?.items.length ?? 0}),
              key: const Key('cart-title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.44,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 10),
            if (cartAsync.isLoading)
              const Padding(
                key: Key('cart-loading'),
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Skeleton(height: 78, radius: 12),
                    SizedBox(height: 12),
                    Skeleton(height: 78, radius: 12),
                    SizedBox(height: 12),
                    Skeleton(height: 40, radius: 12),
                  ],
                ),
              )
            else if (cartAsync.hasError)
              Padding(
                key: const Key('cart-error'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ScreenState(
                  title: t('home.errorTitle'),
                  description: t('errors.generic'),
                  retryKey: const Key('cart-retry'),
                  onRetry: () => ref.invalidate(cartProvider),
                ),
              )
            else
              _buildCartContent(t, cartAsync.value ?? Cart.empty),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(Translator t, Cart cart) {
    final unavailable = cart.items.any((item) => !item.isPurchasable);
    final pending = _checkingOut || _removingId != null;
    final checkoutUnknown = _unknownClassIds != null;
    final checkoutDisabled =
        pending || cart.items.isEmpty || unavailable || checkoutUnknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cart.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              t('cart.empty'),
              key: const Key('cart-empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          )
        else
          for (var i = 0; i < cart.items.length; i++)
            _buildCartItem(t, cart.items[i], i, pending),

        // Hàng tổng cộng
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t('cart.total'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatVnd(cart.totalAmount),
                key: const Key('cart-total'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),

        // Thông báo lỗi checkout hoặc không khả dụng
        if (unavailable || _error != null) ...[
          Text(
            _error ?? t('cart.errors.unavailable'),
            key: const Key('cart-checkout-error'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.statusRed,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Trạng thái đơn chưa rõ
        if (checkoutUnknown) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('cart.checkoutUnknown'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusRed,
                  ),
                ),
                const SizedBox(height: 8),
                MindyButton(
                  key: const Key('cart-checkout-verify'),
                  variant: ButtonVariant.outline,
                  label: t('cart.checkoutVerify'),
                  loading: _checkingOut,
                  onPressed: pending ? null : _verify,
                ),
              ],
            ),
          ),
        ],

        // Nút thanh toán
        MindyButton(
          key: const Key('cart-checkout'),
          label: t(_checkingOut ? 'cart.checkoutPending' : 'cart.checkout'),
          variant: ButtonVariant.action,
          loading: _checkingOut,
          minHeight: 52,
          radius: 14,
          onPressed: checkoutDisabled ? null : _checkout,
        ),
      ],
    );
  }

  Widget _buildCartItem(Translator t, CartItem item, int index, bool pending) {
    final imgUrl = ref.watch(courseDetailProvider(item.courseId)).value?.imgUrl;
    final isRemoving = _removingId == item.classId;

    return Container(
      key: Key('cart-item-${item.classId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Opacity(
        opacity: item.isPurchasable ? 1.0 : 0.6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CoverImage(
                  url: imgUrl,
                  label: item.courseTitle,
                  hideLabel: true,
                  fallback: CourseCover(index: index),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    t('cart.item.meta', {
                      'name': item.className,
                      'mode': item.deliveryMode.name,
                      'date': Dates.dateOnly(item.startDate),
                    }),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatVnd(item.currentPriceAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                      if (item.currentPriceAmount != item.priceSnapshot)
                        Text(
                          formatVnd(item.priceSnapshot),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  if (item.currentPriceAmount != item.priceSnapshot)
                    Text(
                      t('cart.item.priceChanged'),
                      key: Key('cart-item-price-changed-${item.classId}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusYellow,
                      ),
                    ),
                  if (!item.isPurchasable)
                    Text(
                      t('cart.item.unavailable'),
                      key: Key('cart-item-unavailable-${item.classId}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusRed,
                      ),
                    ),
                ],
              ),
            ),
            Pressable(
              key: Key('cart-item-remove-${item.classId}'),
              semanticLabel: t('cart.item.removeLabel', {
                'course': item.courseTitle,
                'name': item.className,
              }),
              onTap: pending ? null : () => _remove(item.classId),
              child: Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                alignment: Alignment.center,
                child: isRemoving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.headsup),
                      )
                    : Text(
                        t('cart.item.remove'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headsup,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
