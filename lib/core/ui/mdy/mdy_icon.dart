import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'mdy_icons.g.dart';
import 'mdy_theme.dart';

export 'mdy_icons.g.dart';

/// Clone `components/ui/icon.tsx`: SVG Material Symbols Rounded 300, mặc định màu `secondary`.
/// `filled` chỉ có tác dụng với light_mode/dark_mode/contrast (như RN).
class MdyIcon extends StatelessWidget {
  const MdyIcon(this.name, {super.key, this.size = 24, this.color, this.filled = false});

  final MdyIcons name;
  final double size;
  final Color? color;
  final bool filled;

  static final _cache = <String, String>{};

  static String svg(MdyIcons name, {bool filled = false}) {
    final path = filled ? (name.filledPath ?? name.path) : name.path;
    final key = '${name.name}:${filled && name.filledPath != null}';
    return _cache.putIfAbsent(
      key,
      () => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${name.viewBox}"><path d="$path"/></svg>',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.mdy.secondary;
    return ExcludeSemantics(
      child: SvgPicture.string(
        svg(name, filled: filled),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      ),
    );
  }
}
