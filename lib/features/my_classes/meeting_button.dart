import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/icon.dart';
import '../../core/ui/pressable.dart';

/// Nút vào Google Meet chuẩn học viên - `modules/my-classes/components/MeetingButton.tsx`.
class MeetingButton extends ConsumerWidget {
  const MeetingButton({
    super.key,
    required this.testId,
    required this.joining,
    required this.onPress,
  });

  final String testId;
  final bool joining;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = width <= 360 || textScale >= 1.3;

    final iconSize = compact ? 17.0 : 20.0;
    final iconBoxSize = compact ? 28.0 : 36.0;

    return Semantics(
      button: true,
      label: t('classDetail.join'),
      enabled: !joining,
      child: Pressable(
        onTap: joining ? null : onPress,
        child: Container(
          key: Key(testId),
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331D5B57), // shadow-forest/20
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(8, 8, compact ? 10 : 16, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: MindyIcon(
                  MindyIconName.video,
                  light: true,
                  size: iconSize,
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              Flexible(
                child: Text(
                  t(joining ? 'learning.refreshing' : 'classDetail.join'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
