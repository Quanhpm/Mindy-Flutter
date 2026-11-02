import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';

/// Clone `modules/auth/components/AccountPage.tsx` (khung chung của Hồ sơ và Cài đặt).
class StaffAccountPage extends ConsumerWidget {
  const StaffAccountPage({
    super.key,
    required this.page,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    this.busy = false,
  });

  /// `settings` | `profile` (dùng cho key test).
  final String page;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !busy,
      child: MdyScreen(
        key: Key('$page-screen'),
        app: true,
        flushBottom: true,
        children: [
          MdyBrandHeader(
            subpage: true,
            child: Row(
              spacing: MdySpace.s12,
              children: [
                Transform.translate(
                  offset: const Offset(-MdySpace.s10, 0),
                  child: Semantics(
                    button: true,
                    label: t('mdy.foundation.back'),
                    child: MdyPressed(
                      key: Key('$page-back-button'),
                      onTap: busy ? null : onBack,
                      builder: (context, pressed) => Container(
                        width: MdySpace.s44,
                        height: MdySpace.s44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pressed ? c.headerPressed : c.transparent,
                        ),
                        child: MdyIcon(MdyIcons.arrowBack, size: 22, color: c.onBrand),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: MdySpace.s2,
                    children: [
                      Text(
                        title,
                        textScaler: mdyMaxScale(context),
                        style: MdyType.size(18, MdyType.w600).copyWith(color: c.onBrand),
                      ),
                      Text(subtitle, style: MdyType.size(13).copyWith(color: c.onBrandMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MdyOverlap(
            by: MdySpace.s28,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(MdyRadius.r28)),
              child: Stack(
                children: [
                  const Positioned.fill(child: MdyGradient(variant: MdyGradientVariant.background, app: true)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      MdySpace.s16,
                      MdySpace.s20,
                      MdySpace.s16,
                      bottom > MdySpace.s32 ? bottom : MdySpace.s32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: MdySpace.s12,
                      children: children,
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

/// `accountStyles.group` + `groupLabel`: nhóm có nhãn chữ hoa nhỏ.
class StaffAccountGroup extends StatelessWidget {
  const StaffAccountGroup({super.key, required this.label, required this.children, this.top = true});
  final String label;
  final List<Widget> children;

  /// `pt-space-12` (nhóm ngôn ngữ đầu tiên của Cài đặt không có).
  final bool top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top ? MdySpace.s12 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MdySpace.s4),
          child: Text(
            label,
            style: MdyType.size(12, MdyType.w600).copyWith(
              color: context.mdy.tertiary,
              letterSpacing: MdyLetterSpacing.group,
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

/// `accountStyles.list`: Card sát lề, padding 6, không gap.
class StaffAccountList extends StatelessWidget {
  const StaffAccountList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MdyCard(
    margin: EdgeInsets.zero,
    padding: const EdgeInsets.all(MdySpace.s6),
    gap: 0,
    children: children,
  );
}
