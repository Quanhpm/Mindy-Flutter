import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pressable.dart';
import 'staff_theme.dart';
import 'sym.dart';

/// Nền kem có 2 vệt sáng (teal trái, cát phải) như thiết kế.
class StaffBackground extends StatelessWidget {
  const StaffBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: StaffColors.bg),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1, -.1),
              radius: .9,
              colors: [StaffColors.bgGlowTeal, Color(0x00D7E9E5)],
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1, .5),
                radius: .9,
                colors: [StaffColors.bgGlowSand, Color(0x00F2E4D0)],
              ),
            ),
            child: child,
          ),
        ),
      );
}

/// Header gradient teal bo 2 góc dưới 28px.
class StaffHeader extends StatelessWidget {
  const StaffHeader({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: StaffColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0x59123236), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -8)],
        ),
        padding: padding.add(EdgeInsets.only(top: MediaQuery.of(context).padding.top)),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
      );
}

/// Thẻ kính mờ (glass) trắng trong suốt, bo 20.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6FFFFFF), Color(0xADFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xF2FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x1A1F4F55), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// Avatar chữ cái đầu + chữ cuối của tên (vd "Trần Thị Linh" -> "TL").
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 52});
  final String name;
  final double size;

  static String initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    final first = p.first.characters.first;
    return (p.length == 1 ? first : first + p.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: StaffColors.avatarBg, shape: BoxShape.circle),
        child: Text(initials(name),
            style: TextStyle(
                fontFamily: StaffText.family,
                fontSize: size * .35,
                fontWeight: FontWeight.w600,
                color: StaffColors.teal700)),
      );
}

/// Chip trạng thái nhỏ (Đang dạy, Chờ duyệt...).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = StatusTone.teal, this.icon});
  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: tone.fg), const SizedBox(width: 4)],
          Text(label,
              style: TextStyle(fontFamily: StaffText.family, fontSize: 12, fontWeight: FontWeight.w600, color: tone.fg)),
        ]),
      );
}

/// Hàng chip lọc cuộn ngang (Đang dạy (3) · Sắp mở (1) ...).
class FilterChipsBar<T> extends StatelessWidget {
  const FilterChipsBar({super.key, required this.items, required this.selected, required this.onSelected});
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final (value, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () => onSelected(value),
                selected: value == selected,
                semanticLabel: label,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: value == selected ? StaffColors.teal700 : const Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: value == selected ? StaffColors.teal700 : StaffColors.tealLine),
                  ),
                  child: Text(label,
                      style: StaffText.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value == selected ? Colors.white : StaffColors.teal700)),
                ),
              ),
            ),
        ]),
      );
}

/// Ô tiện ích tròn trên Home (icon + nhãn + badge MỚI / số đếm / dấu sửa).
class UtilityTile extends StatelessWidget {
  const UtilityTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.isNew = false,
    this.count = 0,
    this.mark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted; // ô đầu tiên của Yêu thích: nền teal
  final bool isNew;
  final int count;

  /// Chế độ Sửa: icon nhỏ ở góc (lock / check / add)
  final IconData? mark;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: highlighted
            ? const LinearGradient(colors: [StaffColors.teal500, StaffColors.teal700])
            : const LinearGradient(colors: [Color(0xE6FFFFFF), Color(0xADFFFFFF)]),
        border: Border.all(color: const Color(0xF2FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x1A1F4F55), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Icon(icon, size: 26, color: highlighted ? Colors.white : StaffColors.teal600),
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 76,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            circle,
            if (isNew)
              Positioned(
                top: -6,
                left: -8,
                child: _badge('MỚI'),
              ),
            if (count > 0)
              Positioned(top: -4, right: -4, child: _badge(count > 9 ? '9+' : '$count', round: true)),
            if (mark != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: StaffColors.teal700, shape: BoxShape.circle),
                  child: Icon(mark, size: 14, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: StaffText.small.copyWith(fontSize: 12.5, color: StaffColors.ink)),
        ]),
      ),
    );
  }

  Widget _badge(String text, {bool round = false}) => Container(
        constraints: BoxConstraints(minWidth: round ? 20 : 0, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: StaffColors.accent,
          borderRadius: BorderRadius.circular(round ? 10 : 6),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(text,
            style: const TextStyle(fontFamily: StaffText.family, fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

/// Nút chính teal đặc (cao 52, bo tròn) và nút viền.
class StaffButton extends StatelessWidget {
  const StaffButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = outlined ? StaffColors.teal700 : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Pressable(
          onTap: enabled ? onPressed : null,
          isButton: false,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: outlined ? Colors.white : (loading ? StaffColors.teal500 : StaffColors.teal700),
              borderRadius: BorderRadius.circular(999),
              border: outlined ? Border.all(color: StaffColors.line) : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                )
              else if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
              Flexible(child: Text(label, style: StaffText.button.copyWith(color: fg))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Trang con chuẩn của Mentor: header gradient (nút back, tiêu đề, phụ đề) + panel kem bo trên phủ lên.
class StaffPage extends StatelessWidget {
  const StaffPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.headerExtra,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  /// Nội dung thêm dưới tiêu đề trong header (dải ngày, ô tìm kiếm...)
  final Widget? headerExtra;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: StaffColors.teal900,
        body: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: StaffColors.headerGradient),
            padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 44),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Sym.arrowBack, color: Colors.white),
                  onPressed: onBack ?? (() => context.canPop() ? context.pop() : null),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: StaffText.pageTitle.copyWith(color: Colors.white)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: StaffText.caption.copyWith(color: StaffColors.onTealMuted)),
                  ]),
                ),
              ]),
              if (headerExtra != null) ...[const SizedBox(height: 12), headerExtra!],
            ]),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: StaffBackground(child: body),
              ),
            ),
          ),
        ]),
      );
}

/// Bottom sheet kiểu staff (bo trên 28, tay kéo, tiêu đề + phụ đề).
Future<T?> showStaffSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: StaffColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: StaffText.title.copyWith(fontSize: 18)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: StaffText.caption)],
            const SizedBox(height: 16),
            builder(ctx),
          ]),
        ),
      ),
    );

/// Toast nổi ở đáy màn, tự ẩn sau 2,2 giây.
void showStaffToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: StaffText.label.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: StaffColors.teal900,
      duration: const Duration(milliseconds: 2200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    ));
}

/// Tránh cảnh báo unawaited khi gọi showStaffSheet không cần kết quả.
void openStaffSheet(BuildContext context, {required String title, String? subtitle, required WidgetBuilder builder}) =>
    unawaited(showStaffSheet<void>(context, title: title, subtitle: subtitle, builder: builder));
