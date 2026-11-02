import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Khối Hero gradient chuẩn cho màn học tập - `modules/my-classes/components/LearningHero.tsx`.
class LearningHero extends StatelessWidget {
  const LearningHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 36),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.forestDeep,
            AppColors.forest,
            AppColors.mint,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
