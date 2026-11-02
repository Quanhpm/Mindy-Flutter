import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mdy_basics.dart';
import 'mdy_icon.dart';
import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';
import 'mdy_type.dart';

/// Clone `text-field.tsx`: nhãn medium 13, ô bo tròn có icon đầu dòng, lỗi caption màu danger.
class MdyTextField extends StatelessWidget {
  const MdyTextField({
    super.key,
    required this.label,
    required this.icon,
    this.fieldId,
    this.controller,
    this.focusNode,
    this.error,
    this.invalid = false,
    this.trailing,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autocorrect = true,
    this.inputFormatters,
    this.maxLength,
  });

  final String label;
  final MdyIcons icon;

  /// `fieldId` của RN: ô nhập có key `<fieldId>-input`, lỗi có key `<fieldId>-error`.
  final String? fieldId;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? error;
  final bool invalid;
  final Widget? trailing;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autocorrect;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final hasError = error != null || invalid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s6,
      children: [
        Text(label, style: MdyType.size(13, MdyType.w500).copyWith(color: c.ink)),
        Container(
          constraints: const BoxConstraints(minHeight: MdySpace.s52),
          padding: const EdgeInsets.only(left: MdySpace.s16, right: MdySpace.s4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MdyRadius.r99),
            border: Border.all(color: hasError ? c.dangerBorder : c.border),
          ),
          child: Row(
            spacing: MdySpace.s10,
            children: [
              MdyIcon(icon, size: 20),
              Expanded(
                child: Semantics(
                  label: label,
                  hint: error,
                  child: TextField(
                    key: fieldId == null ? null : Key('$fieldId-input'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    obscureText: obscureText,
                    autocorrect: autocorrect,
                    autofillHints: autofillHints,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    inputFormatters: inputFormatters,
                    maxLength: maxLength,
                    cursorColor: c.primary,
                    style: MdyType.size(14).copyWith(color: c.ink),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: MdySpace.s12),
                      constraints: const BoxConstraints(minHeight: MdySpace.s50),
                      hintText: hintText,
                      hintStyle: MdyType.size(14).copyWith(color: c.placeholder),
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              key: fieldId == null ? null : Key('$fieldId-error'),
              style: MdyType.caption.copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}

/// Clone `theme-card.tsx`: thẻ chọn giao diện có ảnh xem trước cố định (màu minh hoạ, không theo palette).
class MdyThemeCard extends StatelessWidget {
  const MdyThemeCard({super.key, required this.value, required this.label, required this.checked, required this.onPress});

  final MdyThemeChoice value;
  final String label;
  final bool checked;
  final VoidCallback onPress;

  static const _preview = {
    MdyThemeChoice.light: (Color(0xFFF6F5F2), Color(0xFF1F4F55), Color(0xFFFFFFFF)),
    MdyThemeChoice.dark: (Color(0xFF1A1D1D), Color(0xFF0F2A2D), Color(0xFF2C3131)),
    MdyThemeChoice.system: (Color(0xFFF6F5F2), Color(0xFF1F4F55), Color(0xFFB9C4C2)),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final (background, header, line) = _preview[value]!;
    final fg = checked ? c.primary : c.secondary;
    return Semantics(
      key: Key('settings-theme-${value.name}'),
      inMutuallyExclusiveGroup: true,
      checked: checked,
      label: label,
      onTap: onPress,
      excludeSemantics: true,
      child: MdyPressed(
        onTap: onPress,
        builder: (context, pressed) => AnimatedScale(
          scale: pressed ? .97 : 1,
          duration: MdyMotion.press,
          child: Container(
            padding: const EdgeInsets.fromLTRB(MdySpace.s8, MdySpace.s8, MdySpace.s8, MdySpace.s10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MdyRadius.r18),
              border: Border.all(color: checked ? c.primary : c.transparent, width: 2),
              boxShadow: [mdyShadow(const Color(0x141F4F55), 6, 18)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: MdySpace.s10,
              children: [
                Container(
                  height: MdySpace.s84,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(MdyRadius.r12),
                    border: Border.all(color: c.border),
                  ),
                  child: Stack(
                    children: [
                      if (value == MdyThemeChoice.system)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: .5,
                              heightFactor: 1,
                              child: ColoredBox(color: _preview[MdyThemeChoice.dark]!.$1),
                            ),
                          ),
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(height: MdySpace.s24, color: header),
                          Padding(
                            padding: const EdgeInsets.all(MdySpace.s8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: MdySpace.s6,
                              children: [
                                Container(
                                  height: MdySpace.s14,
                                  decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(MdyRadius.r7)),
                                ),
                                FractionallySizedBox(
                                  widthFactor: .6,
                                  child: Container(
                                    height: MdySpace.s8,
                                    decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(MdyRadius.r4)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MdySpace.s4,
                  children: [
                    MdyIcon(
                      switch (value) {
                        MdyThemeChoice.light => MdyIcons.lightMode,
                        MdyThemeChoice.dark => MdyIcons.darkMode,
                        MdyThemeChoice.system => MdyIcons.contrast,
                      },
                      size: 18,
                      filled: checked,
                      color: fg,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        textScaler: mdyMaxScale(context),
                        style: MdyType.size(13, MdyType.w600).copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clone `skeleton.tsx`: nội dung giữ kích thước nhưng ẩn, lớp mờ nhấp nháy 1 ↔ 0.55 (600ms).
class MdySkeleton extends StatefulWidget {
  const MdySkeleton({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  State<MdySkeleton> createState() => _MdySkeletonState();
}

class _MdySkeletonState extends State<MdySkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    lowerBound: .55,
    upperBound: 1,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.mdyReducedMotion) {
      _c
        ..stop()
        ..value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          children: [
            Opacity(opacity: 0, child: widget.child),
            Positioned.fill(
              child: FadeTransition(
                opacity: _c,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.mdy.muted,
                    borderRadius: BorderRadius.circular(MdyRadius.r12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Clone `modules/auth/components/HomeTile.tsx`: ô tiện ích Home (kính tròn 56 + nhãn 12).
/// `compact` = rộng 60 (lưới Mentor); không compact thì truyền [width] = 25% hàng (lưới Manager).
class MdyHomeTile extends StatelessWidget {
  const MdyHomeTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPress,
    this.featured = false,
    this.compact = false,
    this.badge,
    this.semanticLabel,
    this.width,
  });

  final String label;
  final MdyIcons icon;
  final VoidCallback onPress;
  final bool featured;
  final bool compact;
  final int? badge;
  final String? semanticLabel;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final reduced = context.mdyReducedMotion;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      onTap: onPress,
      excludeSemantics: true,
      child: MdyPressed(
        onTap: onPress,
        builder: (context, pressed) {
          Widget tile = SizedBox(
            width: compact ? 60 : width,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : MdySpace.s2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: MdySpace.s44),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: MdySpace.s8,
                      children: [
                        Container(
                          width: MdySpace.s56,
                          height: MdySpace.s56,
                          clipBehavior: featured ? Clip.none : Clip.antiAlias,
                          decoration: featured
                              ? BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(MdyRadius.r18))
                              : BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.glassBorder),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: const [0, .55, 1],
                                    colors: [c.glass, c.glass, c.glassEnd],
                                  ),
                                  boxShadow: [mdyShadow(c.tileShadow, MdyLayout.tileShadowY, MdyLayout.tileShadowBlur)],
                                ),
                          alignment: Alignment.center,
                          child: MdyIcon(icon, size: 26, color: featured ? c.onBrand : c.link),
                        ),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: MdyType.size(12).copyWith(color: c.ink, height: 16.2 / 12),
                        ),
                      ],
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: MdySpace.s18),
                          height: MdySpace.s18,
                          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.dangerButton, borderRadius: BorderRadius.circular(MdyRadius.r99)),
                          child: Text(
                            badge! > 99 ? '99+' : '$badge',
                            style: MdyType.size(11, MdyType.w700).copyWith(color: c.onBrand),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (pressed) {
            tile = reduced ? Opacity(opacity: .8, child: tile) : Transform.scale(scale: .94, child: tile);
          }
          return tile;
        },
      ),
    );
  }
}
