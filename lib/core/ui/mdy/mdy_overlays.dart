import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mdy_basics.dart';
import 'mdy_icon.dart';
import 'mdy_theme.dart';
import 'mdy_tokens.g.dart';
import 'mdy_type.dart';

/// Mở [MdySheet] (clone `Sheet` của primitives.tsx): scrim, bo trên 28, tay kéo, tiêu đề.
Future<T?> showMdySheet<T>(BuildContext context, {required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: context.mdy.scrim,
  elevation: 0,
  builder: builder,
);

class MdySheet extends StatelessWidget {
  const MdySheet({super.key, required this.title, required this.children, this.busy = false, this.gap = MdySpace.s16});

  final String title;
  final List<Widget> children;

  /// Khoá đóng (scrim, back, vuốt xuống) khi đang gửi.
  final bool busy;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom > MdySpace.s24 ? mq.padding.bottom : MdySpace.s24;
    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: c.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(MdyRadius.r28)),
          ),
          padding: EdgeInsets.fromLTRB(MdySpace.s24, MdySpace.s24, MdySpace.s24, bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: MdySpace.s32),
                  alignment: Alignment.center,
                  child: Container(
                    width: MdySpace.s40,
                    height: MdySpace.s4,
                    margin: const EdgeInsets.only(bottom: MdySpace.s8),
                    decoration: BoxDecoration(color: c.handle, borderRadius: BorderRadius.circular(MdyRadius.r2)),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(title, style: MdyType.title.copyWith(color: c.ink)),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mở [MdyConfirmationDialog] với scrim RN và hiệu ứng fade (tắt khi giảm chuyển động).
Future<T?> showMdyDialog<T>(BuildContext context, {required WidgetBuilder builder}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: context.mdy.scrim,
  transitionDuration: context.mdyReducedMotion ? Duration.zero : MdyMotion.base,
  pageBuilder: (context, _, _) => builder(context),
  transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
);

/// Clone `confirmation-dialog.tsx`: hộp giữa màn rộng tối đa 360, icon tròn danger, nội dung cuộn.
class MdyConfirmationDialog extends StatelessWidget {
  const MdyConfirmationDialog({
    super.key,
    required this.title,
    required this.children,
    this.icon = MdyIcons.logout,
    this.busy = false,
  });

  final String title;
  final List<Widget> children;
  final MdyIcons icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height - mq.padding.top - mq.padding.bottom - MdySpace.s48;
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MdySpace.s24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: maxHeight > MdySpace.s120 ? maxHeight : MdySpace.s120,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(MdyRadius.r28),
                    boxShadow: [mdyShadow(const Color(0x2E141818), 16, 48)],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(MdySpace.s20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s16,
                      children: [
                        Center(
                          child: Container(
                            width: MdySpace.s56,
                            height: MdySpace.s56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: c.dangerSoft, shape: BoxShape.circle),
                            child: MdyIcon(icon, size: 26, color: c.danger),
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: MdyType.size(18, MdyType.w600).copyWith(color: c.ink),
                          ),
                        ),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clone `Toast`: viên thuốc tối ở đáy, icon check_circle, chữ trắng.
class MdyToast extends StatelessWidget {
  const MdyToast(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Semantics(
      liveRegion: true,
      child: FractionallySizedBox(
        widthFactor: .92,
        child: Align(
          child: Container(
            key: const Key('toast'),
            padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16, vertical: MdySpace.s12),
            decoration: BoxDecoration(color: c.toast, borderRadius: BorderRadius.circular(MdyRadius.r16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: MdySpace.s8,
              children: [
                MdyIcon(MdyIcons.checkCircle, size: 20, color: c.toastIcon),
                Flexible(child: Text(text, style: MdyType.alert.copyWith(color: c.onBrand))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Đặt 1 lần ở `MaterialApp.builder`: hiện toast của [mdyToastProvider] đè lên mọi màn.
class MdyToastHost extends ConsumerWidget {
  const MdyToastHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(mdyToastProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        child,
        if (text != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom > MdySpace.s24 ? bottom : MdySpace.s24,
            child: IgnorePointer(child: MdyToast(text)),
          ),
      ],
    );
  }
}

/// Sheet điều khiển bằng state của màn (RN `{open && <Sheet/>}`): đặt làm lớp trên cùng của 1 Stack.
/// Nội dung đổi theo state (busy, kết quả) mà không cần route riêng.
class MdyInlineSheet extends StatelessWidget {
  const MdyInlineSheet({super.key, required this.title, required this.onClose, required this.children, this.busy = false});
  final String title;
  final VoidCallback onClose;
  final List<Widget> children;
  final bool busy;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('inline-sheet-scrim'),
              onTap: busy ? null : onClose,
              child: ColoredBox(color: context.mdy.scrim),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
              child: MdySheet(title: title, busy: busy, children: children),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Hộp xác nhận điều khiển bằng state của màn (RN `{open && <ConfirmationDialog/>}`).
class MdyInlineDialog extends StatelessWidget {
  const MdyInlineDialog({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
    this.icon = MdyIcons.logout,
    this.busy = false,
  });
  final String title;
  final VoidCallback onClose;
  final List<Widget> children;
  final MdyIcons icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('inline-dialog-scrim'),
            onTap: busy ? null : onClose,
            child: ColoredBox(color: context.mdy.scrim),
          ),
        ),
        MdyConfirmationDialog(title: title, icon: icon, busy: busy, children: children),
      ],
    ),
  );
}
