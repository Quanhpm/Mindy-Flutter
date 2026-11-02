import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/i18n.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'brand_bar.dart';
import 'button.dart';
import 'states.dart';
import 'tab_bar.dart';

/// Khung màn học tập chung (Schedule, Account, MyClasses, ClassDetail)
/// Port từ `modules/my-classes/components/LearningLayout.tsx`.
class LearningLayout extends ConsumerWidget {
  const LearningLayout({
    super.key,
    required this.title,
    required this.prefix,
    required this.children,
    this.tab,
    this.onTab,
    this.onBack,
    this.refreshing = false,
    this.onRefresh,
    this.scrollController,
    this.header,
    this.showTitle = true,
    this.contentPadding,
    this.tintedStatusBar = false,
    this.statusTintTone = 'mint',
    this.footer,
    this.floatingFooter = false,
  });

  final String title;
  final String prefix;
  final Widget children;
  final HomeTab? tab;
  final void Function(HomeTab tab)? onTab;
  final VoidCallback? onBack;
  final bool refreshing;
  final RefreshCallback? onRefresh;
  final ScrollController? scrollController;
  final Widget? header;
  final bool showTitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool tintedStatusBar;
  final String statusTintTone; // 'mint' | 'forest'
  final Widget? footer;
  final bool floatingFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final insets = MediaQuery.paddingOf(context);

    final statusBg = statusTintTone == 'forest' ? AppColors.forestDeep : AppColors.mint;

    final overlayStyle = tintedStatusBar
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: statusBg,
            statusBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: AppColors.canvas,
            statusBarIconBrightness: Brightness.dark,
          );

    final effectivePadding = contentPadding ?? const EdgeInsets.fromLTRB(16, 0, 16, 24);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        key: Key('$prefix-screen'),
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            children: [
              // Tint status bar nếu bật
              if (tintedStatusBar)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: insets.top,
                  child: IgnorePointer(
                    child: Container(color: statusBg),
                  ),
                ),

              // Layout chính
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // BrandBar nếu không có onBack
                  if (onBack == null)
                    Container(
                      color: AppColors.mint,
                      child: BrandBar(
                        prefix: prefix,
                        onTop: () => onTab != null ? onTab!(HomeTab.home) : goTab(context, HomeTab.home),
                        onCart: null,
                      ),
                    ),

                  // Tiêu đề + nút back (nếu showTitle)
                  if (showTitle)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          if (onBack != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: MindyButton(
                                key: Key('$prefix-back'),
                                variant: ButtonVariant.ghost,
                                label: t('learning.back'),
                                expand: false,
                                onPressed: onBack,
                              ),
                            ),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 28 / 22,
                                  color: AppColors.forest,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Header slot
                  ?header,

                  // Vùng cuộn nội dung
                  Expanded(
                    child: onRefresh != null
                        ? RefreshIndicator(
                            color: AppColors.mint,
                            onRefresh: onRefresh!,
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: effectivePadding,
                              child: children,
                            ),
                          )
                        : SingleChildScrollView(
                            controller: scrollController,
                            padding: effectivePadding,
                            child: children,
                          ),
                  ),

                  // Footer nếu không floating
                  if (footer != null && !floatingFooter) footer!,

                  // Tab bar cố định trong luồng
                  if (tab != null)
                    AppTabBar(
                      prefix: prefix,
                      selected: tab!,
                      learningEnabled: true,
                      onTab: onTab ?? (t) => goTab(context, t),
                      onTop: () => onTab != null ? onTab!(HomeTab.home) : goTab(context, HomeTab.home),
                    ),
                ],
              ),

              // Floating footer
              if (footer != null && floatingFooter)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: insets.bottom,
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khối trạng thái của LearningLayout - `LearningState.tsx`.
class LearningState<T> extends ConsumerWidget {
  const LearningState({
    super.key,
    required this.asyncValue,
    required this.prefix,
    required this.empty,
    required this.child,
    this.onRetry,
    this.error,
  });

  final AsyncValue<T>? asyncValue;
  final String prefix;
  final bool empty;
  final Widget child;
  final VoidCallback? onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final namespace = prefix == 'my-classes'
        ? 'myClasses'
        : prefix == 'class-detail'
            ? 'classDetail'
            : prefix;

    final av = asyncValue;
    final isLoading = av?.isLoading ?? false;
    final hasError = (av?.hasError ?? false) || error != null;
    final hasData = av?.hasValue ?? false;
    final effectiveError = av?.error ?? error;

    // Loading lần đầu (chưa có data)
    if (!hasData && isLoading) {
      return Container(
        key: Key('$prefix-loading'),
        child: const Column(
          children: [
            Skeleton(height: 100, radius: 18),
            SizedBox(height: 16),
            Skeleton(height: 100, radius: 18),
            SizedBox(height: 16),
            Skeleton(height: 100, radius: 18),
          ],
        ),
      );
    }

    // Error lần đầu (chưa có data)
    if (!hasData && hasError) {
      return ScreenState(
        title: t('home.errorTitle'),
        description: t(errorKey(effectiveError ?? Object())),
        onRetry: onRetry,
        requestId: requestIdOf(effectiveError ?? Object()),
        retryKey: Key('$prefix-retry'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ScreenState(
              title: t('learning.stale'),
              description: t(errorKey(effectiveError ?? Object())),
              onRetry: onRetry,
              requestId: requestIdOf(effectiveError ?? Object()),
              retryKey: Key('$prefix-retry'),
            ),
          ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                t('learning.refreshing'),
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ),
          ),
        if (empty)
          ScreenState(
            key: Key('$prefix-empty'),
            title: t('$namespace.state.empty'),
            description: t('$namespace.state.description'),
          )
        else
          child,
      ],
    );
  }
}
