import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mdy_basics.dart';
import 'mdy_icon.dart';
import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';
import 'mdy_type.dart';

/// Clone `components/ui/primitives.tsx`. Mỗi widget giữ đúng số đo/màu của RN.

enum MdyGradientVariant { header, glass, background }

/// `Gradient`: header (chéo headerStart→Mid→End), glass (glass→glassEnd), background (bg + 2 quầng sáng).
class MdyGradient extends StatelessWidget {
  const MdyGradient({super.key, this.variant = MdyGradientVariant.header, this.app = false});
  final MdyGradientVariant variant;
  final bool app;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    if (variant != MdyGradientVariant.background) {
      final header = variant == MdyGradientVariant.header;
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, .55, 1],
              colors: header ? [c.headerStart, c.headerMid, c.headerEnd] : [c.glass, c.glass, c.glassEnd],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.bg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1,
              colors: [c.glow.withValues(alpha: .7), c.bg.withValues(alpha: 0)],
              transform: _Ellipse(0, app ? .45 : .6, 1, .65),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1,
                colors: [c.warm.withValues(alpha: .5), c.bg.withValues(alpha: 0)],
                transform: _Ellipse(1, app ? .75 : .9, 1, .6),
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// RadialGradient elip giống SVG `cx/cy/rx/ry` theo objectBoundingBox.
class _Ellipse extends GradientTransform {
  const _Ellipse(this.cx, this.cy, this.rx, this.ry);
  final double cx, cy, rx, ry;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final s = bounds.shortestSide == 0 ? 1.0 : bounds.shortestSide;
    final centerNow = bounds.center;
    final target = Offset(bounds.left + cx * bounds.width, bounds.top + cy * bounds.height);
    // Dời tâm mặc định (giữa) tới (cx, cy) rồi giãn bán kính s -> (rx*w, ry*h).
    return Matrix4.translationValues(target.dx, target.dy, 0)
        .multiplied(Matrix4.diagonal3Values(rx * bounds.width / s, ry * bounds.height / s, 1))
        .multiplied(Matrix4.translationValues(-centerNow.dx, -centerNow.dy, 0));
  }
}

/// `Screen`: nền gradient, cuộn, safe area, pull-to-refresh, status bar chữ sáng.
class MdyScreen extends StatelessWidget {
  const MdyScreen({
    super.key,
    required this.children,
    this.app = false,
    this.flushBottom = false,
    this.onRefresh,
    this.controller,
  });

  final List<Widget> children;

  /// `variant="app"` (quầng sáng dịch lên); mặc định là `login`.
  final bool app;
  final bool flushBottom;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final insets = MediaQuery.paddingOf(context);
    Widget scroll = SingleChildScrollView(
      controller: controller,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: EdgeInsets.only(
        left: insets.left,
        right: insets.right,
        bottom: flushBottom ? 0 : (insets.bottom > MdySpace.s24 ? insets.bottom : MdySpace.s24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, color: c.primary, child: scroll);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Positioned.fill(child: MdyGradient(variant: MdyGradientVariant.background, app: app)),
            Positioned.fill(child: scroll),
          ],
        ),
      ),
    );
  }
}

/// `BrandHeader`: auth (có tagline + mascot), workspace (mặc định) hoặc subpage.
class MdyBrandHeader extends StatelessWidget {
  const MdyBrandHeader({super.key, this.tagline, this.child, this.subpage = false, this.flush = false});

  final String? tagline;
  final Widget? child;
  final bool subpage;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final top = MediaQuery.paddingOf(context).top;
    final auth = tagline != null;
    final padding = subpage
        ? EdgeInsets.fromLTRB(MdySpace.s16, top + MdySpace.s16, MdySpace.s16, flush ? 0 : MdySpace.s48)
        : auth
        ? EdgeInsets.fromLTRB(MdySpace.s24, top + MdySpace.s32, MdySpace.s24, MdySpace.s96)
        : EdgeInsets.fromLTRB(MdySpace.s16, top + MdySpace.s20, MdySpace.s16, MdySpace.s120);
    final radius = subpage
        ? BorderRadius.zero
        : const BorderRadius.vertical(bottom: Radius.circular(MdyRadius.r28));
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          const Positioned.fill(child: MdyGradient()),
          if (auth)
            const Positioned(
              right: MdySpace.s20,
              bottom: MdySpace.s63,
              width: MdySpace.s96,
              height: MdySpace.s121,
              child: ExcludeSemantics(
                child: Image(image: AssetImage('assets/images/mdy-mascot-login.png'), fit: BoxFit.contain),
              ),
            ),
          Padding(
            padding: padding,
            child: auth
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mindy',
                        textScaler: mdyMaxScale(context),
                        style: MdyType.wordmark.copyWith(color: c.onBrand),
                      ),
                      const SizedBox(height: MdySpace.s16),
                      FractionallySizedBox(
                        widthFactor: .65,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(tagline!, style: MdyType.tagline.copyWith(color: c.onBrandMuted)),
                      ),
                    ],
                  )
                : (child ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

/// `Card`: thẻ kính bo 20, viền glassBorder, đổ bóng 0/8/24; `overlap` kéo lên 64 và làm mờ nền.
class MdyCard extends StatelessWidget {
  const MdyCard({
    super.key,
    required this.children,
    this.overlap = false,
    this.center = false,
    this.animate = false,
    this.frosted = false,
    this.skeletonLabel,
    this.padding,
    this.margin,
    this.gap = MdySpace.s16,
  });

  final List<Widget> children;
  final bool overlap;
  final bool center;
  final bool animate;
  final bool frosted;
  final String? skeletonLabel;

  /// Đè `pt-24 px-16 pb-20` mặc định (tương đương `className` override bên RN).
  final EdgeInsetsGeometry? padding;

  /// Đè `mx-16` mặc định.
  final EdgeInsetsGeometry? margin;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final radius = BorderRadius.circular(MdyRadius.r20);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      spacing: gap,
      children: children,
    );
    final body = skeletonLabel == null
        ? content
        : Semantics(
            label: skeletonLabel,
            liveRegion: true,
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  Opacity(opacity: 0, child: content),
                  Positioned.fill(child: _CardSkeleton(color: c.muted)),
                ],
              ),
            ),
          );
    Widget card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: MdySpace.s16),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [mdyShadow(c.shadow, MdyLayout.cardShadowY, MdyLayout.cardShadowBlur)],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (frosted || overlap)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: MdyLayout.glassBlur, sigmaY: MdyLayout.glassBlur),
                  child: const SizedBox.expand(),
                ),
              ),
            const Positioned.fill(child: MdyGradient(variant: MdyGradientVariant.glass)),
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: c.glassBorder),
              ),
              padding:
                  padding ?? const EdgeInsets.fromLTRB(MdySpace.s16, MdySpace.s24, MdySpace.s16, MdySpace.s20),
              child: body,
            ),
          ],
        ),
      ),
    );
    if (animate) card = MdyFadeIn(child: card);
    return overlap ? MdyOverlap(child: card) : card;
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.color});
  final Color color;

  Widget _block(double? height, {double width = 1, double radius = MdyRadius.r7, bool end = false}) =>
      FractionallySizedBox(
        widthFactor: width,
        alignment: end ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxHeight < 220
        // Nội dung thấp hơn bộ khung: 1 khối mờ thay vì tràn.
        ? _block(null, radius: MdyRadius.r12)
        : Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: MdySpace.s16,
    children: [
      _block(MdySpace.s24, width: .5),
      _block(MdySpace.s16, width: .75),
      Expanded(child: _block(null, radius: MdyRadius.r12)),
      Expanded(child: _block(null, radius: MdyRadius.r12)),
      _block(MdySpace.s44, width: .5, end: true),
      _block(MdySpace.s52, radius: MdyRadius.r99),
    ],
  ),
  );
}

/// `Alert`: lỗi (dangerSoft) hoặc cảnh báo (warningBg).
class MdyAlert extends StatelessWidget {
  const MdyAlert(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final fg = warning ? c.warning : c.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: MdySpace.s12, vertical: MdySpace.s10),
        decoration: BoxDecoration(
          color: warning ? c.warningBg : c.dangerSoft,
          borderRadius: BorderRadius.circular(MdyRadius.r12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MdySpace.s8,
          children: [
            MdyIcon(warning ? MdyIcons.warning : MdyIcons.error, size: 18, color: fg),
            Expanded(child: Text(text, style: MdyType.alert.copyWith(color: fg))),
          ],
        ),
      ),
    );
  }
}

/// `CircleIcon`: tròn 56, nền tint2 (hoặc dangerBg), icon 26.
class MdyCircleIcon extends StatelessWidget {
  const MdyCircleIcon(this.name, {super.key, this.danger = false});
  final MdyIcons name;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Container(
      width: MdySpace.s56,
      height: MdySpace.s56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: danger ? c.dangerBg : c.tint2, shape: BoxShape.circle),
      child: MdyIcon(name, size: 26, color: danger ? c.danger : c.primary),
    );
  }
}

/// `Avatar`: chữ cái đầu + cuối, mặc định 52; `profile` = 84.
class MdyAvatar extends StatelessWidget {
  const MdyAvatar({super.key, required this.name, this.profile = false, this.size});
  final String name;
  final bool profile;

  /// RN cho phép 28 | 36 | 40 | 52 | 60.
  final double? size;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String first(String w) => w.characters.first;
    final value = words.isEmpty
        ? ''
        : words.length > 1
        ? first(words.first) + first(words.last)
        : first(words.first);
    return value.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final d = profile ? MdySpace.s84 : (size ?? MdySpace.s52);
    var style = MdyType.title.copyWith(color: c.avatarText);
    if (profile) style = style.copyWith(fontSize: 28, height: 42 / 28);
    if (!profile && size == 28) style = style.copyWith(fontSize: 11, height: 16 / 11);
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.avatar, shape: BoxShape.circle),
      child: Text(initials(name), style: style),
    );
  }
}

enum MdyChipVariant { brand, neutral, header, success, warning, danger, info }

/// `Chip`: nhãn trạng thái bo tròn, cao tối thiểu 22.
class MdyChip extends StatelessWidget {
  const MdyChip(this.text, {super.key, this.variant = MdyChipVariant.brand});
  final String text;
  final MdyChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final (bg, fg) = switch (variant) {
      MdyChipVariant.header => (c.headerGlass, c.onBrand),
      MdyChipVariant.neutral => (c.muted, c.secondary),
      MdyChipVariant.success => (c.successBg, c.success),
      MdyChipVariant.warning => (c.warningBg, c.warning),
      MdyChipVariant.danger => (c.dangerBg, c.danger),
      MdyChipVariant.info => (c.infoBg, c.info),
      MdyChipVariant.brand => (c.tint2, c.link),
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: MdySpace.s22),
        padding: const EdgeInsets.symmetric(horizontal: MdySpace.s9),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MdyRadius.r99)),
        child: Text(text, style: MdyType.chip.copyWith(color: fg)),
      ),
    );
  }
}

/// `Row`: dòng hành động (icon tròn + nhãn + chevron) hoặc dòng radio (`checked != null`).
class MdyRow extends StatelessWidget {
  const MdyRow({
    super.key,
    required this.label,
    required this.onPress,
    this.subtitle,
    this.icon,
    this.checked,
    this.danger = false,
    this.code,
    this.compact = false,
    this.chevron = true,
  });

  final String label;
  final String? subtitle;
  final MdyIcons? icon;
  final VoidCallback onPress;
  final bool? checked;
  final bool danger;
  final String? code;
  final bool compact;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final action = checked == null;
    final hPad = compact ? MdySpace.s10 : (action ? MdySpace.s8 : MdySpace.s16);
    final hMargin = compact ? 0.0 : (action ? MdySpace.s8 : 0.0);
    final rounded = compact || action;
    Widget circle(Widget child, Color bg) => Container(
      width: MdySpace.s40,
      height: MdySpace.s40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MdyRadius.r20)),
      child: child,
    );
    return Semantics(
      button: action,
      checked: checked,
      inMutuallyExclusiveGroup: !action,
      label: subtitle == null ? label : '$label. $subtitle',
      onTap: onPress,
      excludeSemantics: true,
      child: MdyPressed(
        onTap: onPress,
        builder: (context, pressed) => Padding(
          padding: EdgeInsets.symmetric(horizontal: hMargin),
          child: DecoratedBox(
            // Tách viền dưới khỏi nền bo góc: Flutter không cho borderRadius với viền 1 cạnh.
            decoration: BoxDecoration(
              border: compact ? null : Border(bottom: BorderSide(color: c.divider, width: mdyHairline(context))),
            ),
            child: Container(
          constraints: const BoxConstraints(minHeight: MdySpace.s56),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: MdySpace.s10),
          decoration: BoxDecoration(
            color: pressed ? c.muted : (checked == true ? c.tint : c.transparent),
            borderRadius: rounded ? BorderRadius.circular(MdyRadius.r14) : null,
          ),
          child: Row(
            spacing: MdySpace.s12,
            children: [
              if (code != null)
                circle(
                  Text(
                    code!,
                    style: MdyType.size(12, MdyType.w700).copyWith(
                      color: c.primary,
                      letterSpacing: MdyLetterSpacing.group,
                    ),
                  ),
                  c.tint2,
                ),
              if (icon != null)
                action
                    ? circle(
                        MdyIcon(icon!, size: 22, color: danger ? c.danger : c.primary),
                        danger ? c.dangerSoft : c.tint2,
                      )
                    : MdyIcon(icon!, size: 22, color: c.secondary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: (action || compact ? MdyType.actionLabel : MdyType.rowLabel).copyWith(
                        color: danger ? c.danger : c.ink,
                      ),
                    ),
                    if (subtitle != null) Text(subtitle!, style: MdyType.caption.copyWith(color: c.secondary)),
                  ],
                ),
              ),
              if (!action || chevron)
                MdyIcon(
                  action
                      ? MdyIcons.chevronRight
                      : (checked! ? MdyIcons.radioButtonChecked : MdyIcons.radioButtonUnchecked),
                  size: action ? 20 : 22,
                  color: action ? c.tertiary : (checked! ? c.primary : c.iconDisabled),
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `FocusHeading`: tiêu đề semibold 17/25 có vai trò header.
class MdyFocusHeading extends StatelessWidget {
  const MdyFocusHeading(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: MdyType.title.copyWith(color: context.mdy.ink).merge(style)),
  );
}

/// `<Text>` mặc định của RN: 14/21 màu ink.
class MdyText extends StatelessWidget {
  const MdyText(this.text, {super.key, this.style, this.maxLines, this.textAlign, this.maxScale});
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  /// `maxFontSizeMultiplier`.
  final double? maxScale;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    textAlign: textAlign,
    textScaler: maxScale == null ? null : mdyMaxScale(context, maxScale!),
    style: MdyType.text.copyWith(color: context.mdy.ink).merge(style),
  );
}
