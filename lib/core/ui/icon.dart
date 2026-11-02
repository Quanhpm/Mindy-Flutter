import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Bộ icon nét (stroke) - path copy nguyên từ `components/common/Icon.tsx`.
enum MindyIconName {
  check, video, folder, folderOpen, camera, edit, monitor, award, checkCalendar, globe,
  help, document, bag, logout, back, eye, eyeOff, mail, lock, user, phone, plus, home,
  calendar, book, grid, bell, cart, image, arrow, filter, clock,
}

const _paths = <MindyIconName, String>{
  MindyIconName.check: 'M5 12l4 4L19 6',
  MindyIconName.video: 'M3 6h12v12H3zM15 10l6-4v12l-6-4z',
  MindyIconName.folder: 'M3 5h7l2 3h9v12H3z',
  MindyIconName.folderOpen: 'M3 8V5h7l2 3h9M3 10h19l-3 10H4z',
  MindyIconName.camera: 'M3 7h4l2-3h6l2 3h4v14H3zM16 13a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  MindyIconName.edit: 'M4 16 16 4l4 4L8 20H4zM13 7l4 4',
  MindyIconName.monitor: 'M3 4h18v13H3zM12 17v4M8 21h8',
  MindyIconName.award: 'M16 8a4 4 0 1 1-8 0 4 4 0 0 1 8 0M9 12l-1 9 4-2 4 2-1-9',
  MindyIconName.checkCalendar: 'M3 5h18v16H3zM7 3v4M17 3v4M3 10h18M8 15l3 3 5-5',
  MindyIconName.globe: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M3 12h18M12 3c5 5 5 13 0 18-5-5-5-13 0-18',
  MindyIconName.help: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M9 9a3 3 0 0 1 6 0c0 2-3 2-3 5M12 17h.01',
  MindyIconName.document: 'M5 3h10l4 4v14H5zM14 3v5h5M8 12h8M8 16h6',
  MindyIconName.bag: 'M5 6h14l-1 15H6zM9 6V4h6v2',
  MindyIconName.logout: 'M10 3H4v18h6M9 12h12M17 8l4 4-4 4',
  MindyIconName.filter: 'M4 8h9M17 8h3M4 16h3M11 16h9',
  MindyIconName.clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  MindyIconName.back: 'M15 18l-6-6 6-6',
  MindyIconName.eye: 'M2 12s3-7 10-7 10 7 10 7-3 7-10 7S2 12 2 12',
  MindyIconName.eyeOff:
      'M3 3l18 18M10 5c1-.3 2-.3 2-.3 7 0 10 7.3 10 7.3a18 18 0 01-4 4M6 6a18 18 0 00-4 6s3 7 10 7a12 12 0 005-1',
  MindyIconName.mail: 'M3 5h18v14H3zM3 6l9 7 9-7',
  MindyIconName.lock: 'M7 10V7a5 5 0 0110 0v3M5 10h14v11H5zM12 14v3',
  MindyIconName.user: 'M4 21v-2a8 8 0 0116 0v2M16 7a4 4 0 11-8 0 4 4 0 018 0',
  MindyIconName.phone: 'M6 3l4 4-2 3a15 15 0 006 6l3-2 4 4-2 3C10 22 2 14 3 5z',
  MindyIconName.plus: 'M12 5v14M5 12h14',
  MindyIconName.home: 'M3 11l9-8 9 8M5 10v11h5v-7h4v7h5V10',
  MindyIconName.calendar: 'M4 5h16v16H4zM8 3v4M16 3v4M4 10h16',
  MindyIconName.book: 'M12 5v16M3 3c4 0 6 1 9 2 3-1 5-2 9-2v16c-3 0-6 1-9 2-3-1-6-2-9-2z',
  MindyIconName.grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  MindyIconName.bell: 'M5 17h14l-2-4V9a5 5 0 00-10 0v4zM10 21h4',
  MindyIconName.cart: 'M2 3h3l3 13h11l3-10H6M9 21h.01M18 21h.01',
  MindyIconName.image: 'M3 3h18v18H3zM3 17l6-6 4 4 3-3 5 5',
  MindyIconName.arrow: 'M5 12h14M13 6l6 6-6 6',
};

const _extras = <MindyIconName, String>{
  MindyIconName.filter: '<circle cx="15" cy="8" r="2"/><circle cx="9" cy="16" r="2"/>',
  MindyIconName.eye: '<circle cx="12" cy="12" r="3"/>',
  MindyIconName.calendar: '<rect x="8" y="13" width="2" height="2"/>',
};

class MindyIcon extends StatelessWidget {
  const MindyIcon(this.name, {super.key, this.size = 22, this.color, this.light = false});

  final MindyIconName name;
  final double size;
  final Color? color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? (light ? AppColors.canvas : AppColors.muted);
    final hex = (effectiveColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final width = name == MindyIconName.arrow ? 2.4 : 2;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="#$hex" stroke-width="$width" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="${_paths[name]}"/>${_extras[name] ?? ''}</svg>';
    return ExcludeSemantics(child: SvgPicture.string(svg, width: size, height: size));
  }
}
