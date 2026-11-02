import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'button.dart';
import 'pressable.dart';

List<int?> pageNumbers(int current, int total) {
  final pages = <int>{1, total, current - 1, current, current + 1}.where((n) => n > 0 && n <= total).toList()..sort();
  final result = <int?>[];
  for (final n in pages) {
    if (result.isNotEmpty && n - result.last! > 1) result.add(null);
    result.add(n);
  }
  return result;
}

class PageNumbers extends StatelessWidget {
  const PageNumbers({
    super.key,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.label,
    required this.previous,
    required this.next,
  });
  final int current, total;
  final ValueChanged<int> onChanged;
  final String Function(int) label;
  final String previous, next;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          for (final n in pageNumbers(current, total))
            if (n == null)
              const SizedBox(width: 24, height: 44, child: Center(child: Text('…')))
            else
              Pressable(
                selected: n == current,
                semanticLabel: label(n),
                onTap: () => onChanged(n),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: n == current ? AppColors.forest : AppColors.soft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      color: n == current ? AppColors.canvas : AppColors.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
        ],
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        children: [
          TextLink(previous, onTap: current > 1 ? () => onChanged(current - 1) : null),
          TextLink(next, onTap: current < total ? () => onChanged(current + 1) : null),
        ],
      ),
    ],
  );
}
